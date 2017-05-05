###########################################################
# Setup Paths and Vars
###########################################################
$path = (${Env:ProgramFiles(x86)}+'\IT Support Guys\ITS Online Backup\cbb.exe') # Path to CBB
$jobsPath = (${Env:SystemRoot}+'\LTSvc\scripts\BackupScrubadub\CONFIG\jobs.config') # Path to jobs.config
$argRead = ('plan -l')

###########################################################
# Parse CBB Output for GUIDs
###########################################################
$process = New-Object System.Diagnostics.Process
$process.StartInfo.UseShellExecute = $false
$process.StartInfo.RedirectStandardOutput = $true
$process.StartInfo.FileName = $path
$process.StartInfo.Arguments = $argRead
$process.Start() > $null
$outputstream = $process.StandardOutput.ReadToEnd()
$guids = $outputstream | Select-String -Pattern "........-....-....-....-............" -AllMatches | ForEach-Object { $_.Matches.Value }

## Delete jobs config file if present
if (Test-Path $jobsPath){ Remove-Item $jobsPath }

###########################################################
# Loop for each GUID
###########################################################
foreach ($guid in $guids) {
	$argUpdate = ('editBackupPlan -id '+$guid+' -postAction '+$Env:windir+'\LTSvc\scripts\BackupScrubadub\BackupScrubadub.bat -paa yes')
		## 'editBackupPlan -id '+$guids+' 				## Binds the command to the current GUID in the group
		## -postAction '+$Env:windir+'\LTSvc\...'		## Tells CBB to add the post action oif the scrubadubdub batch file
		## -paa yes										## Tells CBB to run regardless of pass or fail on the job
	Start-Process -FilePath $path -ArgumentList $argUpdate
	
	## Generate jobs.config file
	$guid | Out-File -Append $jobsPath
}


###########################################################
# Set Logging High in CBB
###########################################################
$argCBB = ('option -l h')
Start-Process -FilePath $path -ArgumentList $argCBB