#backup checker script

#configurable settings
$permissable_errors = 6 #number of counts error has before alert

#important paths
$error_log_dir = ($Env:ProgramData + "\IT Support Guys\Logs\") #full path to dir containing logs
$alert_file_path = ($Env:SystemRoot + "\LTSvc\scripts\BackupScrubADub\BACKUP_FAILURE_ALERT.txt") #location of file LT looks for

$config_file_path = ".\CONFIG\jobs.config" #file containing logs to check for
$ignore_file_path = ".\CONFIG\ignore.config" #file containing errors to ignore

$success_tracking_path = ".\LOGS\SuccessCount.txt" #path of file that counts successes
$fail_tracking_path = ".\LOGS\FailCount.txt" #path of file that counts failures

###################################################################################################################################################
#Create any missing dirs & files
###################################################################################################################################################

#Create folders
if (!(Test-Path ".\CONFIG\")) { New-Item ".\CONFIG\" -Type Directory }
if (!(Test-Path ".\LOGS\")) { New-Item ".\LOGS\" -Type Directory }
if (!(Test-Path ".\DB\")) { New-Item ".\DB\" -Type Directory }

#Create config if missing
if (!(Test-Path ".\CONFIG\jobs.config")) { Invoke-Expression ".\UpdateJobs.ps1" | Out-Null }
if (!(Test-Path ".\CONFIG\ignore.config")) { "" | Out-File $ignore_file_path }

#Create success / fail tracking files if not present
if (!(Test-Path $success_tracking_path)){ "0" | Out-File $success_tracking_path }
if (!(Test-Path $fail_tracking_path)){ "0" | Out-File $fail_tracking_path }

###################################################################################################################################################
#Script vars
###################################################################################################################################################
$master_alert_log = ((Get-Date).ToString(‘F’) + "`r`n") #holds log to populate alert (if created)
$alert = $false #marked True to create alert file

Write-Host "**************************************************************************************************************************************"
Write-Host "*                                                          Backup Scrubadub                                                          *"
Write-Host "**************************************************************************************************************************************"

###################################################################################################################################################
#Loads success / fail tracking data
###################################################################################################################################################

$success_count = [convert]::ToInt32((Get-Content $success_tracking_path))
$fail_count = [convert]::ToInt32((Get-Content $fail_tracking_path))

Write-Host ("Current success count: " + $success_count)
Write-Host ("Current fail count: " + $fail_count)

###################################################################################################################################################
#Checks for configured jobs and if present loads data
###################################################################################################################################################

#loads list of files to monitor
$guids_to_monitor = Get-Content $config_file_path
Write-Host ("`r`n*** JOBS TO MONITOR: ***`r`n" + ($guids_to_monitor | Out-String))

if (($guids_to_monitor -eq $null) -or ($guids_to_monitor.ToString() -replace "\s","" -eq "")){
     $master_alert_log = ($master_alert_log + "No jobs are configured!`r`n")
    Write-Host "`r`n*** ERROR: NO JOBS CONFIGURED! ***`r`n"
    $alert = $true
}

#loads list of errors to ignore
$errors_to_ignore = Get-Content $ignore_file_path
Write-Host ("`r`n*** ERRORS PATTERNS TO IGNORE: ***`r`n" + ($errors_to_ignore | Out-String))

#main function
function process_log ($error_log_file, $guid){
    #saving paths
    $db_file_path = (".\DB\" + $guid + ".json")
    $countstatus_file_name = ($guid + "-countstatus.log")
    #function variables
    $new_errors = @() #olds new errors to process
    $error_occurrence = @{} #hash table of "error message : # occurances"
    $status_log = ((Get-Date).ToString(‘F’) + "`r`n" + "COUNT  :   ERROR" + "`r`n") #human readable status count
    $job_alert = $false #whether this job is alerting
    $job_alert_log = ""
    Write-Host "**************************************************************************************************************************************"
    Write-Host "*                                                        STARTING LOG PROCESS                                                        *"
    Write-Host "**************************************************************************************************************************************"

    Write-Host ("`r`n*** LOG TO ANALYZE: ***`r`n" + ($error_log_file))

    #loads JSON file as PSCustomObject, adds content to hash table 'error_occurrence' -- if not present creates blank file
    if (Test-Path ($db_file_path)){
    (ConvertFrom-Json -InputObject (Get-Content $db_file_path -Raw)).PSObject.Properties | ForEach-Object{ $error_occurrence.Add($_.Name, $_.Value) }
    }
    else { "{}" | Out-File $db_file_path }

    #check if line is an error and if so if it is to be ignored
    (Get-Content ($error_log_file)) | ForEach-Object{
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
            $job_alert = $true
            $script:alert = $true
            $job_alert_log = ($job_alert_log + $old_error + " count: " + $error_occurrence[$old_error] + "`r`n")
            }
    }

    #for each unseen error, add it to the hash map with one count
    $new_errors | ForEach-Object{
        if (!$error_occurrence.ContainsKey($_)) { $error_occurrence.Add($_, 1) }
    }

    #generate alert
    if ($job_alert){
        $script:master_alert_log = ($script:master_alert_log + $guid + " alerting!`r`n" + $job_alert_log)
    }
    
    #reviews status
    Write-Host "`r`n*** ONGOING ERROR REVIEW: ***`r`n"
    $error_occurrence.GetEnumerator() | ForEach-Object{
    $status_log = ($status_log + [string]$_.Value + "      :   " + $_.Key + "`r`n")
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
    if(Test-Path ($error_log_file.toString() + ".old2")) { Remove-Item ($error_log_file.toString() + ".old2") }

    #rename second oldest CBB log
    if(Test-Path ($error_log_file.toString() + ".old")) { Rename-Item ($error_log_file.toString() + ".old") ($error_log_file.toString() + ".old2") }

    #rename current CBB log
    if(Test-Path ($error_log_file)) { Rename-Item $error_log_file ($error_log_file.toString() + ".old") }
}

###################################################################################################################################################
#Checks for missing logs and processes if all ok
###################################################################################################################################################


Write-Host "**************************************************************************************************************************************"
Write-Host "*                                                Checking for missing logs!                                                          *"
Write-Host "**************************************************************************************************************************************"

#var to check that exactly one log processed
$logs_processed = 0

$guids_to_monitor | ForEach-Object{
    $logs_good = $true
    ###################################################################################################################################################
    #Checks that recently created log is present and processes if so
    ###################################################################################################################################################

    #if the log is present
    if (Test-Path ($error_log_dir + $_ + ".log")){
            $log_file = Get-Item ($error_log_dir + $_ + ".log") #get the log
            #check if the log is sufficiently recent to be current
            if($log_file.LastWriteTime -gt (Get-Date).AddMinutes(-10)){ 
                Write-Host "*** OKAY: " $_ " present and current! ***"
                process_log $log_file $_ #actually processes the log
                $logs_processed += 1
            }
            #check if the log is sufficiently recent to be correctly running
            elseif($log_file.LastWriteTime -gt (Get-Date).AddDays(-1)){ Write-Host "*** OKAY: " $_ " present and recent! ***"}
            else{
                $master_alert_log = ($master_alert_log + "Sufficiently recent log for " + $_ + "not found!`r`n")
                Write-Host "*** ERROR: " $logs_processed " SUFFICIENTLY RECENT LOG FOR " $_ " NOT FOUND! ***"
                $alert = $true
            }
    }
}

if ($logs_processed -lt 1) {
        $master_alert_log = ($master_alert_log + $logs_processed + " logs processed!  Sufficiently recent log not found!`r`n")
        Write-Host "*** ERROR: " $logs_processed " LOGS PROCESSED!  SUFFICIENTLY RECENT LOG NOT FOUND! ***"
        $alert = $true
    }
    elseif ($logs_processed -gt 1){
        $master_alert_log = ($master_alert_log + $logs_processed + " logs processed!  Too many sufficiently recent logs found!`r`n")
        Write-Host "*** ERROR: " $logs_processed " LOGS PROCESSED!  TOO MANY SUFFICIENTLY RECENT LOGS FOUND! ***"
        $alert = $true
    }

Write-Host "**************************************************************************************************************************************"
Write-Host "*                                                      Log Processing Done!                                                          *"
Write-Host "**************************************************************************************************************************************"

if($alert){
    Write-Host "WRITING ALERT:" $master_alert_log
    #write alert file for LT to retrieve
    $master_alert_log | Out-File $alert_file_path
    #increment fail count in file
    $fail_count + 1 | Out-File $fail_tracking_path
    }
else { $success_count + 1 | Out-File $success_tracking_path }

#END