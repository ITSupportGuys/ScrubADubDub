###########################################################
# Setup Paths and Vars
###########################################################
$path = (${Env:ProgramFiles(x86)}+'\IT Support Guys\ITS Online Backup\cbb.exe') # Path to CBB
$argRead = ('plan -l')


###########################################################
# Parse CBB Output for GUIDs
###########################################################
$process = New-Object System.Diagnostics.Process
$process.StartInfo.UseShellExecute = $false
$process.StartInfo.RedirectStandardOutput = $true
$process.StartInfo.FileName = $path
$process.StartInfo.Arguments = $argRead
$process.Start()
$outputStream = $process.StandardOutput.ReadToEnd() | select-string -pattern "........-....-....-....-............" -AllMatches

## Enable to output GUIDS
#foreach($var in $outputStream.Matches){
#    Write-Host $var
#}


###########################################################
# Loop foreach GUID
###########################################################
foreach ($guids in $outputStream.Matches) {
	#$guids = '2ddacb3c-f081-4d95-8279-3f8a323440ae' 	## Overwrite for testing a specific GUID
	$argUpdate = ('editBackupPlan -id '+$guids+' -postAction '+$Env:windir+'\LTSvc\scripts\BackupScrubadub\BackupScrubadub.bat -paa yes')
		## 'editBackupPlan -id '+$guids+' 				## Binds the command to the current GUID in the group
		## -postAction '+$Env:windir+'\LTSvc\...'		## Tells CBB to add the post action oif the scrubadubdub batch file
		## -paa yes										## Tells CBB to run regardless of pass or fail on the job
	Start-Process -FilePath $path -ArgumentList $argUpdate
	
	
	## Generate jobs.config file
	if ($guids.Count -gt 0){
		#if jobs were found write file
		$jobsPath = (${Env:SystemRoot}+'\LTSvc\scripts\BackupScrubadub\CONFIG\jobs.config')
		$guids | Out-File $jobsPath
	}
	else {
		#alert setup failed
		"Job setup failed -- no logs found!" > $alert_file_path
	}
}


###########################################################
# Set Logging High in CBB
###########################################################
$argCBB = ('option -l h')
Start-Process -FilePath $path -ArgumentList $argCBB