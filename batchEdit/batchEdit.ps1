# Powershell script to process metadata changes in a single data table to a list of per-record field changes for CONTENTdm Catcher, via Pitcher. https://github.com/little9/pitcher
# Nathan Tallman, August 2018

# Read in the metadata changes with -csv path, pass the collection allias with -alias alias. 
param (
    [string]$csv = "metadata.csv",
    [Parameter(Mandatory=$true)][string]$alias = $( Read-Host "Input the collection alias, please." )
 )

# Setup timestamps and global variables
function Get-TimeStamp { return "[{0:yyyy-MM-dd} {0:HH:mm:ss}]" -f (Get-Date) }
$batch = $PSScriptRoot | Split-Path -Leaf
$log = ($batch + "_metadataBatchEdit_log.txt")

Write-Output "$(Get-Timestamp) Metadata windup starting by reading in the data table of edited metadata." | Tee-Object -Filepath $log

# Read in the metadata data.
$metadata = Import-Csv -Path "$csv"
$headers = ($metadata[0].psobject.Properties).Name

# add action column, assume all edits for now. add will add will create a null record, delete will delete a record.

# Write the headers
Write-Output "cdmnumber,field,value,collection,action" | Out-File -FilePath tmp.csv

# Find the changes and write out the row
ForEach ($record in $metadata) {
  Foreach ($header in $headers) {      
    Foreach ($data in $record.$header) {
      If ($data) {
        Write-Output ($record.cdmnumber + ","  + "$header"+ ',"'  + "$data"  +  '",' + "$alias" + "," + "edit")  | Out-File -FilePath tmp.csv -Append
      } 
    }
  }
}

# Break the CSV's apart by field for per-record processing.
ForEach ($header in $headers) {
 Import-Csv tmp.csv | Sort-Object * -Unique | Where {$_.field -eq "$header"} | Where {$_.field -ne "cdmnumber"} | Export-Csv ("metadata_edited_" + $header + ".csv") -NoTypeInformation
}

Remove-Item tmp.csv
Remove-Item metadata_edited_cdmnumber.csv

Write-Output "$(Get-Timestamp) Metadata changes have now been broken up by field, per record. Pitcher will now throw each individual csv of field/record changes to Catcher. You will need to confirm indexing of each csv before pitching the next one as Catcher will only make one field change per record at a a time." | Tee-Object -Filepath $log -Append

If(!(Test-Path logs)) {New-Item -ItemType Directory -Path logs | Out-Null }

Get-ChildItem -Filter metadata_edited_* | ForEach {
  pitcher --csv $_.FullName --settings settings.yml
  Read-Host -Prompt "Press any key and ENTER to continue when $_ been fully indexed or the items unlocked. Unless this was the last CSV, the next one will not pitch until $_ is unlocked or indexed. You can also press CTRL+C to quit."
}
Write-Output "" | Out-File -Filepath $log -Append
Write-Output "---------------------" | Out-File -Filepath $log -Append
Write-Output "---------------------" | Out-File -Filepath $log -Append
Write-Output "-Starting Pitcher Log-" | Out-File -Filepath $log -Append
Add-Content $log -Value (Get-Content "logs/response-*.txt")
Write-Output "---------------------" | Out-File -Filepath $log -Append
Write-Output "---------------------" | Out-File -Filepath $log -Append
Write-Output "-Ending Pitcher Log-" | Out-File -Filepath $log -Append
Write-Output "" | Out-File -Filepath $log -Append
Remove-Item logs -Recurse
Write-Output "$(Get-Timestamp) Batch metadata changes are complete!" | Tee-Object -Filepath $log -Append