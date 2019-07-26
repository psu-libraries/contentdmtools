# batchLoadCreate.ps1
# Nathan Tallman, Created in August 2018, Updated in 26 July 2019
# https://git.psu.edu/digipres/contentdm/edit/master/batchLoad

# Setup the switches
[cmdletbinding()]
Param(
  [Parameter]
  [switch]$ocr,

  [Parameter]
  [switch]$pdf,

  [Parameter]
  [switch]$deltif,

  [Parameter(Mandatory)]
  [string]$path = $(Throw "Use -path to specify a path to the files for the batch.")  
)

# Variables
$tesseract = ($PSScriptRoot + "\util\tesseract\tesseract.exe")
$gs = ($PSScriptRoot + "\util\gs\bin\gswin64c.exe")
$batch = $PSScriptRoot | Split-Path -Leaf
$log = ($batch + "_batchLoadCreate_log.txt")
function Get-TimeStamp { return "[{0:yyyy-MM-dd} {0:HH:mm:ss}]" -f (Get-Date) }

# Read in the metadata data.
$metadata = Import-Csv -Path $path\metadata.csv

# Find the directories (objects) and export the metadata for each one.
$objects = $metadata | Group-Object -AsHashTable -AsString -Property Directory
$o=0
ForEach ($object in $objects.keys) {
  $objects.$object | Export-Csv -Delimiter "`t" -Path $path\$object\$object.txt -NoTypeInformation  | Tee-Object -file $log
  Write-Output "$(Get-Timestamp) Metadata has been broken up into the the CONTENTdm Compound Object Directory Structure." | Tee-Object -file $log
  
  # OCR and PDF
  # OCR language parameter?
  if (($ocr) -And ($pdf)) {
    Write-Output "$(Get-Timestamp) Tesseract OCR starting, creating TXT and PDF..." | Tee-Object -file $log -Append
    Get-ChildItem *.tif* -Recurse | ForEach-Object { ..\util\tesseract\tesseract.exe $_.FullName $(Join-Path $_.DirectoryName  $_.BaseName) txt pdf quiet} | Tee-Object -file $log
    # move TXT files to transcripts directory
    (Get-ChildItem *.pdf).Name > list.txt
    ..\util\gs\bin\gswin64c.exe -sDEVICE=pdfwrite -dQUIET -dBATCH -dSAFER -dNOPAUSE -dFastWebView -dCompatibilityLevel='1.5' -sOUTPUTFILE="$object.pdf" $(get-content list.txt)
    $files = $(get-content list.txt)
    ForEach ($file in $files) { Remove-Item $file }
    Remove-Item list.txt
    Write-Output "$(Get-Timestamp) ...Tesseract OCR complete." | Tee-Object -file $log -Append
  } 
  
  if ($ocr) {
    Write-Output "$(Get-Timestamp) Tesseract OCR starting, creating TXT..." | Tee-Object -file $log -Append
    Get-ChildItem *.tif* -Recurse | ForEach-Object { ..\util\tesseract\tesseract.exe $_.FullName $(Join-Path $_.DirectoryName  $_.BaseName) txt quiet} | Tee-Object -file $log
    # move TXT files to transcripts directory
    Write-Output "$(Get-Timestamp) ...Tesseract OCR complete." | Tee-Object -file $log -Append
  }

  if ($pdf) {
    Write-Output "$(Get-Timestamp) Tesseract OCR starting, creating  PDF..." | Tee-Object -file $log -Append
    Get-ChildItem *.tif* -Recurse | ForEach-Object { ..\util\tesseract\tesseract.exe $_.FullName $(Join-Path $_.DirectoryName  $_.BaseName) pdf quiet} | Tee-Object -file $log
    (Get-ChildItem *.pdf).Name > list.txt
    ..\util\gs\bin\gswin64c.exe -sDEVICE=pdfwrite -dQUIET -dBATCH -dSAFER -dNOPAUSE -dFastWebView -dCompatibilityLevel='1.5' -sOUTPUTFILE="$object.pdf" $(get-content list.txt)
    $files = $(get-content list.txt)
    ForEach ($file in $files) { Remove-Item $file }
    Remove-Item list.txt
    Write-Output "$(Get-Timestamp) ...Tesseract OCR complete." | Tee-Object -file $log -Append
  }

    # Find the tif files and convert them to jp2.
    # SWITCH TO GRAPHICSMAGIC AND DEAL WITH COLOR MGMT AND JP2 ENCODING
    Write-Output "$(Get-Timestamp) Starting TIF to JP2 conversion..." | Tee-Object -file $log -Append
    Get-ChildItem *.tif* -Recurse | ForEach-Object { magick.exe convert -quiet ($_.FullName + "[0]") "$($_.FullName -Replace "tif", "jp2")" } | Tee-Object -file $log
    Write-Output "$(Get-Timestamp) TIFs converted to JP2." | Tee-Object -file $log -Append


    # Find the tif files and delete them.
    if ($deltif) {
      Write-Output "$(Get-Timestamp) Deleting TIFs...." | Tee-Object -file $log -Append
      Get-ChildItem *.tif* -Recurse | ForEach-Object { Remove-Item -Path $_.FullName } | Tee-Object -file $log
      Write-Output "$(Get-Timestamp) TIFs deleted." | Tee-Object -file $log -Append
    }


  $o++
  }