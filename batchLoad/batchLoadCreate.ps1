# batchLoadCreate.ps1 
# Nathan Tallman, August 2018
# https://git.psu.edu/digipres/scripts/tree/master/conversions/CONTENTdm

# Setup the switches
[cmdletbinding()]
Param([switch]$ocr, [switch]$derivs, [switch]$deltif)

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
  $directories.$directory |Export-Csv -Delimiter "`t" -Path $directory\$directory.txt -NoTypeInformation
}
Write-Output "$(Get-Timestamp) Metadata has been broken up into the the CONTENTdm Compound Object Directory Structure." | Tee-Object -file $log

# Send the TIF files to ABBYY Recognition Server for OCR processing
if($ocr)
{
  $count_staged = 0
  $count_processed = 0
  $user = $env:USERNAME
  $abbyyStage = "O:\pcd\text\$user\$batch"
  $abbyyInput = "O:\pcd\text\input\"
  $abbyyOutput = "O:\pcd\text\output\"

  Write-Output "$(Get-Timestamp) Sending TIFs to ABBYY for conversion to TXT." | Tee-Object -file $log -Append
  Write-Output "$(Get-Timestamp) Starting to copy..." | Tee-Object -file $log -Append 
  if(!(Test-Path $abbyyStage)) {New-Item -ItemType Directory -Path $abbyyStage | Out-Null }
  robocopy . $abbyyStage *.tif* /S | Out-Null  
  Copy-Item -Path $abbyyStage -Destination $abbyyInput -Recurse -Force | Out-Null
  Start-Sleep 5
  Remove-Item -Path $abbyyStage -Recurse -Force | Out-Null
  Write-Output "$(Get-Timestamp) Copy finished, ABBYY starting..." | Tee-Object -file $log -Append
  
  DO {
    $count_staged = Get-ChildItem -Path $PSScriptRoot -Include *.tif* -Recurse -File -Force | Measure-Object | %{$_.Count}
    $count_processed = Get-ChildItem -Path "$abbyyOutput" -Include *.txt -Recurse -File -Force | Measure-Object | %{$_.Count}
    Write-Output "  TIF count = $count_staged; TXT count = $count_processed" | Tee-Object -file $log -Append
    Start-Sleep 30
  } Until ($count_staged -eq $count_processed)

   # Move the transcripts to the batch directory.
   ForEach ($dir in Get-ChildItem -Path "$abbyyOutput\$batch" -Recurse -Include scans) { Rename-Item $dir -NewName transcripts }
   Move-Item -Path "$abbyyOutput\$batch\*" -Destination $PSScriptRoot
   Start-Sleep 5
   Remove-Item -Path "$abbyyOutput\$batch\" | Out-Null
   Write-Output "$(Get-Timestamp) ABBYY is finished, transcripts are ready." | Tee-Object -file $log -Append
}

# Find the tif files and convert them to jp2.
if($derivs){
  Write-Output "$(Get-Timestamp) Starting TIF to JP2 conversion..." | Tee-Object -file $log -Append
  Get-ChildItem *.tif* -Recurse | ForEach { magick.exe convert -quiet ($_.FullName + "[0]") "$($_.FullName -Replace "tif", "jp2")" }
  Write-Output "$(Get-Timestamp) TIFs converted to JP2." | Tee-Object -file $log -Append
}

# Find the tif files and delete them.
if($deltif){
  Write-Output "$(Get-Timestamp) Deleting TIFs...." | Tee-Object -file $log -Append
  Get-ChildItem *.tif* -Recurse | ForEach { Remove-Item -Path $_.FullName }
  Write-Output "$(Get-Timestamp) TIFs deleted." | Tee-Object -file $log -Append
}