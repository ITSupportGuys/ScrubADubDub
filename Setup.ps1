$error_log_dir = ($Env:ProgramData + "\IT Support Guys\Logs\") #full path to dir containing logs
$guids = @()

#clears dirs
Remove-Item .\DB\*
Remove-Item .\LOGS\*

(Get-ChildItem -Filter "????????-????-????-????-????????????.log" $error_log_dir) | ForEach-Object{
$guids += ( $_.ToString().Substring( (0) , ($_.ToString().Length -4) ))
}

$guids | Out-File .\CONFIG\jobs.config
