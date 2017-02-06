##############################################################################################
				   BACKUP SCRUBADUB!
##############################################################################################
Program logic:

Read CBB error logs, parses errors
If error is new -- add it to tracking DB
If error is in DB -- increment the occurence count for error
If error in DB is no longer occuring -- decrement the counter
If count for error in DB reaches 0 -- remove error from DB

Important files:

.\BackupScrubadub.ps1             -- Primary script
.\BackupScrubadub.bat             -- Batch file launcher for BackupScrubadub.ps1
.\ClearDBs.ps1                    -- Resets error tracking DBs
.\ClearDBs.bat                    -- Batch file launcher for ClearDBs.ps1
.\Setup.ps1                       -- Resets, configs monitoring for active logs
.\Setup.bat			  -- Batch file launcher for Setup.ps1

.\CONFIG\ignore.config            -- Patterns to ignore in error identifcation, one per line
.\DB\<GUID>.json                  -- JSON dictionary with errors mapped to occurence count
.\LOGS\<GUID>-countstatus.log     -- Logs past errors with counts
