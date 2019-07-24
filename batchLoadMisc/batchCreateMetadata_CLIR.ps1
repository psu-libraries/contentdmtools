# batchCreateMetadata_CLIR.ps1 
# Nathan Tallman, Created in 2019-0724
# this is fragile, only works for this collection as of this date, will break if the number of fields change. This could probably be refactored to read number of fields and generate stuff as needed?

# Setup timestamps and global variables
function Get-TimeStamp { return "[{0:yyyy-MM-dd} {0:HH:mm:ss}]" -f (Get-Date) }
$batch = $PSScriptRoot | Split-Path -Leaf
$log = ($batch + "_cdmPrep_log.txt")
Write-Output "$(Get-Timestamp) CLIR CONTENTdm metadata prcoessing starting." | Tee-Object -file $log

# Read in the metadata and setup array for each object
$metadata = Import-Csv -Path metadata.csv
$objects = $metadata | Group-Object -AsHashTable -AsString -Property Directory

# For every object, do this
ForEach ($object in $objects.keys)
{
  # Create tab-d object metadata txt file
  Write-Output "Starting to process metadata for $object." | Tee-Object -file $log -Append
  if(!(Test-Path $object\$object)) { New-Item -ItemType Directory -Path $object\$object | Out-Null }
  $objects.$object | Select-Object Title,"Alternative Title",Creator,Recipient,"Date Created",Genre,"Physical Description",Subject,Location,"Time Period",Notes,Language,Identifier,"Box and Folder",Collection,Series,Repository,"Finding Aid","Rights Statement","Resource Type",Cataloger,"Date Cataloged","File Name" -ExcludeProperty Level,Directory | Export-Csv -Delimiter "`t" -Path $object\$object\$object.txt -NoTypeInformation | Tee-Object -file $log -Append
  Write-Output "    $(Get-Timestamp) Object metadata for has been broken up into the the Directory Structure." | Tee-Object -file $log -Append


  # Append item metadata to tab-d
  $i=1
  Get-ChildItem *.jp2 -Path $object | ForEach-Object {
    $row = "{0}`t{1}`t{2}`t{3}`t{4}`t{5}`t{6}`t{7}`t{8}`t{9}`t{10}`t{11}`t{12}`t{13}`t{14}`t{15}`t{16}`t{17}`t{18}`t{19}`t{20}`t{21}`t{22}" -f """Page $i""", """""", """""", """""", """""", """""", """""", """""", """""", """""", """""", """""", """""" ,"""""", """""", """""", """""", """""", """""", """""", """""", """""", $_
    [array]$item = $row
    $item | Out-File $object\$object\$object.txt -Append -Encoding UTF8
    $i++
  }
  Write-Output "    $(Get-Timestamp) Page item metadata for has been added." | Tee-Object -file $log -Append
  
  # Move the tab-d metadata txt file to staging directory
  if(!(Test-Path $PSScriptRoot\metadata)) { New-Item -ItemType Directory -Path $PSScriptRoot\metadata | Out-Null }
  Move-Item $object\$object -Destination $PSScriptRoot\metadata  | Tee-Object -file $log -Append
  Write-Output "    $(Get-Timestamp) Metadata for compound object is processed." | Tee-Object -file $log -Append
}
Write-Output "$(Get-Timestamp) CLIR CONTENTdm metadata processing complete." | Tee-Object -file $log -Append