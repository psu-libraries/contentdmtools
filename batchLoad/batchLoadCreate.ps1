# batchLoadCreate.ps1 
# Nathan Tallman, Created in August 2018, Updated in November 2018
# https://git.psu.edu/digipres/contentdm/edit/master/batchLoad

# Setup the switches
[cmdletbinding()]
Param([switch]$abbyy, [switch]$im, [switch]$deltif)

# Setup timestamps and global variables
function Get-TimeStamp { return "[{0:yyyy-MM-dd} {0:HH:mm:ss}]" -f (Get-Date) }
$batch = $PSScriptRoot | Split-Path -Leaf
$log = ($batch + "_cdmPrep_log.txt")

# Read in the metadata data.
$metadata = Import-Csv -Delimiter "`t" -Path metadata.txt

# Find the directories (objects) and export the metadata for each one.
$directories = $metadata | Group-Object -AsHashTable -AsString -Property Directory
ForEach ($directory in $directories.keys)
{
  $directories.$directory |Export-Csv -Delimiter "`t" -Path $directory\$directory.txt -NoTypeInformation  | Tee-Object -file $log
}
Write-Output "$(Get-Timestamp) Metadata has been broken up into the the CONTENTdm Compound Object Directory Structure." | Tee-Object -file $log

# Send the TIF files to ABBYY Recognition Server for OCR processing
if($abbyy)
{
  $count_staged = 0
  $count_processed = 0
  $user = $env:USERNAME
  $abbyyStage = "O:\pcd\contentdm_withText\$user\$batch"
  $abbyyInput = "O:\pcd\contentdm_withText\input\"
  $abbyyOutput = "O:\pcd\contentdm_withText\output\$batch"

  Write-Output "$(Get-Timestamp) Sending TIFs to ABBYY for conversion." | Tee-Object -file $log -Append
  Write-Output "$(Get-Timestamp) Starting to copy..." | Tee-Object -file $log -Append 
  if(!(Test-Path $abbyyStage)) {New-Item -ItemType Directory -Path $abbyyStage | Out-Null }
  robocopy . $abbyyStage *.tif* /S | Out-Null  
  Copy-Item -Path $abbyyStage -Destination $abbyyInput -Recurse -Force | Out-Null
  Start-Sleep 30
  Remove-Item -Path $abbyyStage -Recurse -Force | Out-Null
  Write-Output "$(Get-Timestamp) Copy finished, ABBYY starting..." | Tee-Object -file $log -Append
  
  DO {
    $count_staged = Get-ChildItem -Path $PSScriptRoot -Include *.tif* -Recurse -File -Force | Measure-Object | %{$_.Count}
    $count_txt = Get-ChildItem -Path "$abbyyOutput" -Include *.txt -Recurse -File -Force | Measure-Object | %{$_.Count}
    $count_jp2 = Get-ChildItem -Path "$abbyyOutput" -Include *.jp2 -Recurse -File -Force | Measure-Object | %{$_.Count}
    Write-Output "  TIF count = $count_staged; TXT count = $count_txt; JP2 count = $count_jp2" | Tee-Object -file $log -Append
    Start-Sleep 30
  } Until (($count_staged -eq $count_txt) -and ($count_staged -eq $count_jp2))

   # Move the transcripts and jpeg2000s to the batch directory.
   Move-Item -Path "$abbyyOutput\*" -Destination $PSScriptRoot  | Tee-Object -file $log
   Start-Sleep 30
   Remove-Item -Path "$abbyyOutput" | Out-Null
   Write-Output "$(Get-Timestamp) ABBYY is finished, transcripts and jpeg2000s are ready." | Tee-Object -file $log -Append
}

# Find the tif files and convert them to jp2.
if($im){
  Write-Output "$(Get-Timestamp) Starting TIF to JP2 conversion..." | Tee-Object -file $log -Append
  Get-ChildItem *.tif* -Recurse | ForEach { magick.exe convert -quiet ($_.FullName + "[0]") "$($_.FullName -Replace "tif", "jp2")" }  | Tee-Object -file $log
  Write-Output "$(Get-Timestamp) TIFs converted to JP2." | Tee-Object -file $log -Append
}

# Find the tif files and delete them.
if($deltif){
  Write-Output "$(Get-Timestamp) Deleting TIFs...." | Tee-Object -file $log -Append
  Get-ChildItem *.tif* -Recurse | ForEach { Remove-Item -Path $_.FullName }  | Tee-Object -file $log
  Write-Output "$(Get-Timestamp) TIFs deleted." | Tee-Object -file $log -Append
}