# batchLoadCLIR_pdfDownsampler.ps1
# Written by Nathan Tallman, 2019-07-24
# Requires Ghostscript 9.27 installed in the default location

# Setup functions, variables, and directory
function Get-TimeStamp { return "[{0:yyyy-MM-dd} {0:HH:mm:ss}]" -f (Get-Date) }
$batch = $PSScriptRoot | Split-Path -Leaf
$pdf = "$PSScriptRoot\pdf-downsampled"
$log = ($batch + "_batchLoadCLIR_pdfDownsampler_log.txt")

Write-Output "$(Get-Timestamp) CLIR CONTENTdm PDF downsampling starting." | Tee-Object -file $log
Write-Output "-------------------------------------------------------------" | Tee-Object -file $log -Append
if(!(Test-Path $PSScriptRoot\pdf-downsampled)) { New-Item -ItemType Directory -Path $PSScriptRoot\pdf-downsampled | Out-Null }

# Find the PDFs and downsample each one to 200 PPI using Ghostscript
$beforeCount = (Get-ChildItem -Recurse pst*.pdf).Count
$i=0
Get-ChildItem -Recurse pst*.pdf | ForEach-Object { 
    $i++
    $objectPath = Split-Path $_.FullName -Parent
    $object = Split-Path $objectPath -Leaf
    Write-Output "    $(Get-TimeStamp) $object started, $i of $beforeCount..." | Tee-Object -file $log -Append
    if(!(Test-Path $pdf\$object)) { New-Item -ItemType Directory -Path $pdf\$object | Out-Null }
    & 'C:\Program Files\gs\gs9.27\bin\gswin64c.exe' -sDEVICE=pdfwrite -dQUIET -dSAFER -dBATCH -dNOPAUSE -dFastWebView -dCompatibilityLevel='1.5' -dDownsampleColorImages='true' -dColorImageDownsampleType=/Bicubic -dColorImageResolution='200' -dDownsampleGrayImages='true' -dGrayImageDownsampleType=/Bicubic -dGrayImageResolution='200' -dDownsampleMonoImages='true' -sOutputFile="$pdf\$object\$object.pdf" $_ *>> $log
    Write-Output "    $(Get-TimeStamp) ...complete." | Tee-Object -file $log -Append
}
Write-Output "$(Get-Timestamp) CLIR CONTENTdm PDF downsampling complete." | Tee-Object -file $log -Append
Write-Output "-------------------------------------------------------------" | Tee-Object -file $log -Append
$afterCount = (Get-ChildItem pst* -Directory -Path $pdf).Count
Write-Output "Number of objects processed:  $i" | Tee-Object -file $log -Append
Write-Output "Number of object directories: $afterCount" | Tee-Object -file $log -Append