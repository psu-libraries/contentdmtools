# batchReOCR.ps1 
# Nathan Tallman, created in October 2018, re-written 31 July 2019.
# https://github.com/psu-libraries/contentdmtools

# Parameters
param(
  [Parameter(Mandatory)]
  [string]
  $alias  = $(Throw "Use -alias to specify the alias for the collection."),

  [Parameter(Mandatory)]
  [string]
  $fulltext  = $(Throw "Use -fulltext to specify the nickname of the field used to save full-text transcripts."),

  [Parameter(Mandatory)]
  [string]
  $public  = $(Throw "Use -public to specify the URL for the CONTENTdm Public GUI. Ex: https://cdm1234.contentdm.oclc.org"),

  [Parameter(Mandatory)]
  [string]
  $server  = $(Throw "Use -server to specify the URL for the CONTENTdm Administrative GUI. Ex: https://server1234.contentdm.oclc.org")
)

# Variables
$gm = $(Resolve-Path "util\gm\gm.exe")
$tesseract = $(Resolve-Path "util\tesseract\tesseract.exe")
$pwd = $(Get-Location).Path
$log = ($PSScriptRoot + "\logs\batchReOCR_" + $alias + "_log_" + $(Get-Date -Format yyyyMMddTHHmmssffff) + ".txt")
$csv = @()

# Functions
function Get-TimeStamp { return "[{0:yyyy-MM-dd} {0:HH:mm:ss}]" -f (Get-Date) }
function Convert-OCR($ocrText) { 
  (Get-Content $ocrText) | ForEach-Object {
      $_ -replace '[^a-zA-Z0-9_.,!?$%#@/\s]' `
         -replace '[\u009D]' `
         -replace '[\u000C]'
    } | Set-Content $ocrText 
}

# Get the CONTENTdm records for the collection
$hits = Invoke-RestMethod "$server/dmwebservices/index.php?q=dmQuery/$alias/0/dmrecord!find/nosort/1024/1/0/0/0/0/1/0/json"
$records = $hits.records

Write-Output "----------------------------------------------" | Tee-Object -file $log
Write-Output "$(Get-Timestamp) CONTENTdm Tools Batch Re-OCR Starting." | Tee-Object -file $log -Append
Write-Output "Collection Alias: $alias"  | Tee-Object -file $log -Append
Write-Output "Collection Items: $($records.count)"  | Tee-Object -file $log -Append
Write-Output "----------------------------------------------" | Tee-Object -file $log -Append

# Download the JP2 for each item in the collection (named for the record number, not original filename) and run Tesseract OCR
if (!(Test-Path tmp)) { New-Item -ItemType Directory -Path tmp | Out-Null }
Set-Location tmp | Tee-Object -file $log -Append
$i = 0
$noFiles = 0
$notImage = 0
foreach ($record in $records) {
  $i++
  Write-Output ($(Get-Timestamp) + " Starting item "  + $($record.dmrecord) + " (" + $i + " of " + $records.count + " items)...") | Tee-Object -file $log -Append
  if ($null -eq $record.find) {
    Write-Output "        No file for item $($record.dmrecord)." | Tee-Object -file $log -Append
    $noFiles++
  }
  else {
    $imageInfo = Invoke-RestMethod ($server + "/dmwebservices/index.php?q=dmGetImageInfo/" + $alias + "/" + $record.pointer + "/json")
    $filename = $imageInfo.filename
    $fileExtension = $filename.substring($filename.length -4,4)
    if ($fileExtension -match "jp2") {
      $imageFile = ($record.dmrecord + ".jpg")
      Write-Output "        Downloading $imageFile." | Tee-Object -file $log -Append
      Invoke-RestMethod ($public + "/utils/ajaxhelper/?CISOROOT=" + $alias + "&CISOPTR=" + $record.pointer + "&action=2&DMSCALE=100&DMWIDTH=" + $imageInfo.width + "&DMHEIGHT=" + $imageInfo.height + "&DMX=0&DMY=0") -OutFile $imageFile | Tee-Object -file $log -Append
      Write-Output "        Optimizing image for OCR." | Tee-Object -file $log -Append
      Invoke-Expression ("$gm mogrify -format tif -colorspace gray $imageFile") 2>&1 | Tee-Object -file $log -Append
      $imageFile = ($record.dmrecord + ".tif")
      Write-Output "        Running Tesseract OCR on the image." | Tee-Object -file $log -Append
      Invoke-Expression ("$tesseract $imageFile " + $record.dmrecord + " txt quiet") 2>&1  | Tee-Object -file $log -Append
      $imageTxt = ($record.dmrecord + ".txt")
      Write-Output "        Sanitizing OCR text for CONTENTdm." | Tee-Object -file $log -Append
      Convert-OCR -ocrText $imageTxt
      $value = (get-content $imageTxt) | Where-Object {$_.Trim(" `t")}
      Write-Output "        Add transcript to data file for updating collection." | Tee-Object -file $log -Append
      $itemDetails = New-Object -TypeName PSObject
      $itemDetails | Add-Member -MemberType NoteProperty -Name dmrecord -Value $record.dmrecord
      $itemDetails | Add-Member -MemberType NoteProperty -Name $fulltext -Value $("$value")
      $csv += $itemDetails
      $csv | Export-CSV ocr.csv -NoTypeInformation
    } else {
      $notImage++
      Write-Output "        No image file for item $($record.dmrecord)." | Tee-Object -file $log -Append
    }
  }
  Write-Output "$(Get-Timestamp) Completed item $($record.dmrecord)." | Tee-Object -file $log -Append
}

Set-Location $pwd

# Send the new OCR to CONTENTdm
Write-Output "$(Get-Timestamp) Sending new transcripts to CONTENTdm using batchEdit.ps1, which will also generate its own log. Errors will not appear in this log..." | Tee-Object -file $log -Append
Invoke-Expression ".\batchEdit.ps1 -csv tmp\ocr.csv -alias $alias" 2>&1  | Tee-Object -file $log -Append
Write-Output "$(Get-Timestamp) Transcripts sent, don't forget to re-index the collection in the Administrative GUI." | Tee-Object -file $log -Append

# Cleanup the tmp files
Write-Output "$(Get-Timestamp) Deleting temporary files created throughout this process..." | Tee-Object -file $log -Append
$tifCount = (Get-ChildItem *.txt -Recurse -Path tmp).Count
Remove-Item tmp -Recurse -Force | Tee-Object -file $log -Append

Write-Output "----------------------------------------------" | Tee-Object -file $log -Append
Write-Output "$(Get-Timestamp) CONTENTdm Tools Batch Re-OCR Complete." | Tee-Object -file $log -Append
Write-Output "Collection Alias: $alias"  | Tee-Object -file $log -Append
Write-Output "Batch Log: $log" | Tee-Object -file $log -Append
Write-Output "Number of items in collection:  $($records.count)" | Tee-Object -file $log -Append
Write-Output "Number of items in re-OCR'ed:   $tifCount" | Tee-Object -file $log -Append
Write-Output "Number of items without files:  $noFiles" | Tee-Object -file $log -Append
Write-Output "Number of items without images: $notImage" | Tee-Object -file $log -Append
Write-Output "---------------------------------------------" | Tee-Object -file $log -Append