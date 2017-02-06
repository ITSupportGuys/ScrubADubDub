$error_log_dir = ($Env:ProgramData + "\IT Support Guys\Logs\") #full path to dir containing logs
$guids = @()

(Get-ChildItem -Filter "????????-????-????-????-????????????.log" $error_log_dir) | ForEach-Object{
	$guids += ( $_.ToString().Substring( (0) , ($_.ToString().Length -4) ))
}

foreach ($guids in $guids) {
	#$guids = '2ddacb3c-f081-4d95-8279-3f8a323440ae' # Overwrite for testing a specific GUID
	$path = (${Env:ProgramFiles(x86)}+'\IT Support Guys\ITS Online Backup\cbb.exe') # Path to CBB
	$arg = ('editBackupPlan -id '+$guids+' -postAction '+$Env:windir+'\LTSvc\scripts\BackupScrubadub\BackupScrubadub.bat -paa yes')
		# 'editBackupPlan -id '+$guids+' 			## Binds the command to the current GUID in the group
		#-postAction '+$Env:windir+'\LTSvc\...'		## Tells CBB to add the post action oif the scrubadubdub batch file
		#-paa yes									## Tells CBB to run regardless of pass or fail on the job
	Start-Process -FilePath $path -ArgumentList $arg
}