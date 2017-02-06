#backup checker script

#configurable settings
$permissable_errors = 3 #number of counts error has before alert
$error_log_dir = ($Env:ProgramData + "\IT Support Guys\Logs\") #full path to dir containing logs
$alert_file_path = ($Env:SystemRoot + "\LTSvc\scripts\BACKUP_FAILURE_ALERT.txt") #location of file LT looks for


#script vars
$master_alert_log = ((Get-Date).ToString(‘F’) + "`r`n`r`n") #holds log to populate alert (if created)
$alert = $false #marked True to create alert file
$logs_good = $true

Write-Host "**************************************************************************************************************************************"
Write-Host "*                                                          Backup Scrubadub                                                          *"
Write-Host "**************************************************************************************************************************************"

#loads list of files to monitor
$guids_to_monitor = Get-Content .\CONFIG\jobs.config
Write-Host ("`n*** JOBS TO MONITOR: ***`n" + ($guids_to_monitor | Out-String))

#loads list of errors to ignore
$errors_to_ignore = Get-Content .\CONFIG\ignore.config
Write-Host ("`n*** ERRORS PATTERNS TO IGNORE: ***`n" + ($errors_to_ignore | Out-String))

###################################################################################################################################################
#Catches log files
###################################################################################################################################################

#matches and returns list of valid looking log files
$valid_logs = Get-ChildItem -Filter "????????-????-????-????-????????????.log" $error_log_dir

###################################################################################################################################################
#Checks for missing logs
###################################################################################################################################################

#checks for current / recent logs for evident of script activity
$guids_to_monitor | ForEach-Object{
    #if primary log is present
    if (Test-Path ($error_log_dir + $_ + ".log")){
        #check last write time is greater than a day ago, if so mark okay
        if((Get-Item ($error_log_dir + $_ + ".log")).LastWriteTime -lt (Get-Date).AddDays(-1)){ $logs_good = $false }
    }
    #else check if older log present
    elseif(Test-Path ($error_log_dir + $_ + ".log.old")){
        #check last write time is greater than a day ago, if so mark bad
        if((Get-Item ($error_log_dir + $_ + ".log.old")).LastWriteTime -lt (Get-Date).AddDays(-1)){ $logs_good = $false }
    }
    #else neither log exists, mark bad
    else{ $logs_good = $false }
}

#if logs are bad
if (!$logs_good){
    ($status_log + "Log(s) missing or outdated!") | Out-File $alert_file_path
    Write-Host "*** ERROR: LOG(S) MISSING OR OUTDATED! ***"
    exit
}

function process_log ($error_log_file){
    #isolates GUID string from log file
    $guid = $error_log_file.ToString().Substring( (0) , ($error_log_file.ToString().Length -4) )
    #saving paths
    $db_file_path = (".\DB\" + $guid + ".json")
    $countstatus_file_name = ($guid + "-countstatus.log")
    #function variables
    $new_errors = @() #olds new errors to process
    $error_occurrence = @{} #hash table of "error message : # occurances"
    $status_log = ((Get-Date).ToString(‘F’) + "`r`n`r`n" + "COUNT  :   ERROR" + "`r`n`r`n") #human readable status count
    $alert_log = ""
    Write-Host "**************************************************************************************************************************************"
    Write-Host "*                                                        STARTING LOG PROCESS                                                        *"
    Write-Host "**************************************************************************************************************************************"

    Write-Host ("`n*** LOG TO ANALYZE: ***`n" + ($error_log_dir + $error_log_file))

    #loads JSON file as PSCustomObject, adds content to hash table 'error_occurrence' -- if not present creates blank file
    if (Test-Path ($db_file_path)){
    (ConvertFrom-Json -InputObject (Get-Content $db_file_path -Raw)).PSObject.Properties | ForEach-Object{ $error_occurrence.Add($_.Name, $_.Value) }
    }
    else { "{}" | Out-File $db_file_path }

    #check if line is an error and if so if it is to be ignored
    (Get-Content ($error_log_dir + $error_log_file)) | ForEach-Object{
        #if line is long enough to begin parsing
        if (($_.Length - 1) -ge 38){
            #check part of line with error indication
            if ($_.Substring(33,5).Contains("ERR")){
                $new_error = $_.Substring(24)
                #check if any element of errors_to_ignore is substring of new_error
                #Write-Host ("*** Checking to ignore: ***" + $new_error)
                $ignore = $false
                #for each error to ignore
                    $errors_to_ignore | ForEach-Object{
                    #check if it is a substring of the new error read and if so set to ignore it
                    if ($new_error.Contains($_)){
                        #Write-Host "*** IGNORE ERROR! ***"
                        $ignore = $true
                    }
                }
                #if we are not to ignore it, append it to our error DB
                if (!$ignore){
                    #Write-Host ("*** DO NOT IGNORE! New Error! : " + $new_error + " ***")
                    $new_errors += $new_error
                }
            }
        }       
    }

    #for each old error, check if any new present and remove, decrement, or increment count in hash table
    foreach($old_error in $($error_occurrence.Keys)){
        #if the new errors does not have the old error still occurring
        if (!$new_errors.Contains($old_error)){
            #remove error from hashmap if count <= 1
            if ($error_occurrence[$old_error] -le 2) { $error_occurrence.Remove($old_error) }
            else { $error_occurrence[$old_error] -= 2 }
        }
        #if the old error is in the new errors again increment
        else { $error_occurrence[$old_error] += 1 }

        #after operations check if counts are permissable
        if ($error_occurrence[$old_error] -gt $permissable_errors){
            $script:alert = $true
            $alert_log = ($alert_log + $old_error + " count: " + $error_occurrence[$old_error] + "`r`n`r`n")
            }
    }

    #for each unseen error, add it to the hash map with one count
    $new_errors | ForEach-Object{
        if (!$error_occurrence.ContainsKey($_)) { $error_occurrence.Add($_, 1) }
    }

    #generate alert
    if ($alert){
        $script:master_alert_log = ($script:master_alert_log + $guid + " alerting!`r`n" + $alert_log)
    }

    #reviews status
    "`n*** ONGOING ERROR REVIEW: ***`n"
    $error_occurrence.GetEnumerator() | ForEach-Object{
    $status_log = ($status_log + [string]$_.Value + "      :   " + $_.Key + "`r`n`r`n")
    }

    #delete oldest count status log
    if(Test-Path (".\LOGS\" + $countstatus_file_name + ".old2")) { Remove-Item (".\LOGS\" + $countstatus_file_name + ".old2") }

    #rename second oldest CBB log
    if(Test-Path (".\LOGS\" + $countstatus_file_name + ".old")) { Rename-Item (".\LOGS\" + $countstatus_file_name + ".old") ($countstatus_file_name + ".old2") }

    #rename most recent CBB log
    if(Test-Path (".\LOGS\" + $countstatus_file_name)) { Rename-Item (".\LOGS\" + $countstatus_file_name) ($countstatus_file_name + ".old") }

    #write new count status log
    Write-Host $status_log

    #export status log
    $status_log | Out-File (".\LOGS\" + $countstatus_file_name)

    #save error_occurrences for next use
    $error_occurrence | ConvertTo-Json | Out-File $db_file_path

    #delete oldest CBB log
    if(Test-Path ($error_log_dir + $error_log_file + ".old2")) { Remove-Item ($error_log_dir + $error_log_file + ".old2") }

    #rename second oldest CBB log
    if(Test-Path ($error_log_dir + $error_log_file + ".old")) { Rename-Item ($error_log_dir + $error_log_file + ".old") ($error_log_dir + $error_log_file + ".old2") }

    #rename current CBB log
    if(Test-Path ($error_log_dir + $error_log_file)) { Rename-Item ($error_log_dir + $error_log_file) ($error_log_dir + $error_log_file + ".old") }
}
##############################################################################################
#END OF THE VERY LONG FUNCTION!
##############################################################################################

##############################################################################################
#Processes log files
##############################################################################################

$valid_logs | ForEach-Object{
    #if the log being worked on has been recently edited (by CBB) it is the active log
    if($_.LastWriteTime -gt (Get-Date).AddMinutes(-3)){ process_log $_ }
    #otherwise log belongs to another job, skip
}

if($alert){ $master_alert_log | Out-File $alert_file_path }
