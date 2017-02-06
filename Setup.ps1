$alert_file_path = ($Env:SystemRoot + "\LTSvc\scripts\BACKUP_FAILURE_ALERT.txt") #location of file LT looks for
$error_log_dir = ($Env:ProgramData + "\IT Support Guys\Logs\") #full path to dir containing logs
$guids = @()

#if jobs are already configured exit script
if (Test-Path .\CONFIG\jobs.config) {
    Write-Host "Jobs already configured, exiting!"
    exit 
}

#else clear database and log directories|
Write-Host "Writing jobs.config!"

#clears dirs
Remove-Item .\DB\*
Remove-Item .\LOGS\*

(Get-ChildItem -Filter "????????-????-????-????-????????????.log" $error_log_dir) | ForEach-Object{
$guids += ( $_.ToString().Substring( (0) , ($_.ToString().Length -4) ))
}


if ($guids.Count -gt 0){
    #if jobs were found write file
    $guids | Out-File .\CONFIG\jobs.config
}
else {
    #alert setup failed
    "Job setup failed -- no logs found!" > $alert_file_path
}
