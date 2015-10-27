###
Set-ExecutionPolicy -ExecutionPolicy Bypass -Force
$sw = [Diagnostics.Stopwatch]::StartNew()


###
$smtphost          = "<SMTP_HOST>"
$rcpt              = "<TO>"
$ccpt              = "<COPY>"
$backupPath        = "<MSSQL_BAK_FOLDER>"
$remoteBackupPath  = "<CIFS_SHARE_TO_STORE_BACKUPS>"
$scriptPath        = "<SCRIPT_FOLDER>"
$7z                = "C:\Program Files\7-Zip\7z.exe"
$username          = [Environment]::UserName
$hostname          = $env:COMPUTERNAME
$sender            = "$hostname <$hostname@<DOMAIN_NAME>>"
$date              = "$((get-date).tostring("ddMMyyyy-HHmm"))"
$scriptFile        = "$date"+"$username.sql"
$scriptFileLog     = "$date"+"-$username.sql.txt"
$scriptName        = $MyInvocation.MyCommand.Name

Out-File $scriptPath$scriptFileLog -Encoding Default


###
"[+----------][$date] Prepare functions`n" >> $scriptPath$scriptFileLog

function emailMe($subject, $body) {
    send-mailmessage -smtpServer $smtphost -to $rcpt <#-Cc $ccpt#> -from $sender -subject $subject -Body $body <#-BodyAsHtml#> -Attachments $scriptPath$scriptFileLog
}


###
"[+++--------][$date] Starting zip file proccess`n" >> $scriptPath$scriptFileLog

& $7z "a" -t7z -mx1 C:\$date.7z $backupPath\*.bak >> $scriptPath$scriptFileLog
& $7z "t" C:\$date.7z >> $scriptPath$scriptFileLog
if(!($?)) {
    emailMe "Warning! $hostname." "$scriptName aborted! Can't compress BAK files"
    exit
}


###
"[+++++------][$date] Copy items`n" >> $scriptPath$scriptFileLog

Copy-Item -Path C:\$date.7z -Confirm:$false -Destination $remoteBackupPath -Force -Recurse -ErrorAction Stop
if(!($?)) {
    emailMe "Warning! $hostname." "$scriptName aborted! Can't copy files"
    exit
}

$colItems = (Get-ChildItem $remoteBackupPath\$date.7z | Measure-Object -property length -sum)
$fileSize = "{0:N2}" -f ($colItems.sum / 1MB) + " MB"
$fileSize >> $scriptPath$scriptFileLog

$sw.Stop()
$elapsedTime = $sw.Elapsed.Minutes
$elapsedTime >> $scriptPath$scriptFileLog


###
"[++++++++---][$date] Removing items`n" >> $scriptPath$scriptFileLog

Remove-Item C:\$date.7z -Confirm:$false -Force -ErrorAction Stop >> $scriptPath$scriptFileLog
Remove-Item $backupPath\*.bak -Recurse -Force -Confirm:$false -ErrorAction Stop >> $scriptPath$scriptFileLog


###
"[+++++++++++][$date] Sending email`n" >> $scriptPath$scriptFileLog

#$logContent = Get-Content -Path $scriptPath$scriptFileLog -Force -Raw
emailMe "Backup compresion operation." "Hello DBA.`n Script $scriptName execution complite, result atached.`n Created archive size is $fileSize`n Elapsed time is $elapsedTime minutes `n`n`n---`n Your faithful employe"


###
<#
#$body = Get-Content -Path $scriptPath$scriptFileLog -Force
#send-mailmessage -smtpServer $smtphost -to $rcpt -Cc $ccpt -from $sender -subject "Backup compresion operation." -Body "Hello DBA.`n $body`n`n`n Created archive size is $fileSize`n Elapsed time is $elapsedTime minutes `n username $usernmae  `n---`n Your faithful employe"
#>