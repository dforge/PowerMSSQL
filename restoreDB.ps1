##############################################
#
# DO NOT USE THAT SCRIPT IF YOU NOT SURE
#
##############################################

# Setting up timer and importing SQLPS module.
###
$sw = [Diagnostics.Stopwatch]::StartNew()
Import-Module “sqlps” -DisableNameChecking

# Common settings
###
$smtp              =  "<SMTP_HOST>"
$rcpt              =  "<TO_MAILBOX>"
$ccpt              =  "<COPY_MAILBOX>"
$backupPath        =  "<BACKUP_FOLDER>"
$remoteBackupPath  =  "<REMOTE_BACKUP_FOLDER>"
$scriptPath        =  "<SCRIPT_PATH>"
$7z                =  "C:\Program Files\7-Zip\7z.exe"
$hostname          =  $env:COMPUTERNAME
$sender            =  "$hostname <$hostname@rttv.ru>"
$date              =  "$((get-date).tostring("yyyyMMdd-HHmm"))"
$logFile           =  "$date"+"$username.sql.log"

# Setting up databases
###
$sourceDB          =  "<RESTORE_FROM_DB>"
$targetDB          =  "<RESTORE_TO_DB>"
$hostDB            =  "<DB_HOST>"

# This is not good, must be fixed!
###
$sourceDBFIx       =  $sourceDB + "_log"
$targetDBFix       =  $targetDB + "_log"

Write-Host "[+----------][$date] Starting backup [$sourceDB] to [$backupPath$sourceDB$date.bak]"

Backup-SqlDatabase -ServerInstance $hostname -Database $sourceDB -Checksum -BackupFile $backupPath$sourceDB$date.bak -BackupAction Database -EA SilentlyContinue
if(!($?)) {
    echo "[$date] Abort!  Abort! Restore db [$sourceDB] failed!"
    exit
}

Write-Host "[++---------][$date] Starting backup [$targetDB] to [ $backupPath$targetDB$date.bak]"

Backup-SqlDatabase -ServerInstance $hostname -Database $targetDB -Checksum -BackupFile $backupPath$targetDB$date.bak -BackupAction Database -EA SilentlyContinue
if(!($?)) {
    echo "[$date] Abort! Restore db [$targetDB] failed!"
    exit
}

Write-Host "[+++--------][$date] Define mdf and ldf files on [$targetDB]"

$targetMDF = Invoke-Sqlcmd -Query "sp_helpdb '$targetDB'" -ServerInstance $hostname -Database $targetDB | ? {$_.name -eq $targetDB} | ft filename -HideTableHeader | Out-String
$targetLDF = Invoke-Sqlcmd -Query "sp_helpdb '$targetDB'" -ServerInstance $hostname -Database $targetDB | ? {$_.name -eq $targetDB+"_"+"log"} | ft filename -HideTableHeader | Out-String
$targetMDF = $targetMDF.Trim()
$targetLDF = $targetLDF.Trim()


Write-Host "[++++-------][$date] Prepare query."

$query=@"
USE [master]
ALTER DATABASE [$targetDB]
	SET SINGLE_USER
	WITH ROLLBACK IMMEDIATE;
GO
ALTER DATABASE [$targetDB]
	SET MULTI_USER;
GO

USE [master]
RESTORE DATABASE [$targetDB] FROM  DISK = N'$backupPath\$sourceDB$date.bak' WITH  FILE = 1,
	MOVE N'$sourceDB' TO N'$targetMDF',
	MOVE N'$sourceDBFIx' TO N'$targetLDF',
	NOUNLOAD,  REPLACE,  STATS = 10
GO

USE [master]
GO
ALTER DATABASE [to]
	MODIFY FILE  ( NAME = '$sourceDB', NEWNAME = '$targetDB')
GO
ALTER DATABASE [to]
	MODIFY FILE  ( NAME = '$sourceDBFIx', NEWNAME = '$targetDBFix')
GO

USE [master]
    DBCC CHECKDB(N'$targetDB') WITH NO_INFOMSGS
GO
"@

Write-Host "[+++++++----][$date] Run query with sqlcmd."

$queryResult = sqlcmd -Q $query -S $hostname | Out-String
if(!($?)) {
    echo "[$date] Abort! Restore db [$targetDB] failed!"
    exit
}

$sw.Stop()
$elapsedTime = "Elapsed time in "+$sw.Elapsed.Minutes + " minutes " + $sw.Elapsed.Seconds + " seconds"

Write-Host "[+++++++++++][$date] Restore [$sourceDB] to [$targetDB] has succesfuly complited. $elapsedTime"


###
# Temporary items
<#
#Invoke-Sqlcmd -Query $query -ServerInstance $hostname -Verbose 
#>