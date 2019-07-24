# pdf-downsampler.ps1
# Written by Nathan Tallman, 2019-07-24
# Requires Ghostscript 9.27 installed in the default location

# Setup functions, variables, and directory
function Get-TimeStamp { return "[{0:yyyy-MM-dd} {0:HH:mm:ss}]" -f (Get-Date) }
$pdf = "$PSScriptRoot\pdf-downsampled"
$log = ($pdf+"\pdf-downsampled-log.txt")
if(!(Test-Path $PSScriptRoot\pdf-downsampled)) { New-Item -ItemType Directory -Path $PSScriptRoot\pdf-downsampled | Out-Null }

# Find the PDFs and downsample each one to 200 PPI using Ghostscript
Write-Output "$(Get-Timestamp) PDF downsampling starting." | Tee-Object -file $log
Get-ChildItem -Recurse *.pdf | ForEach-Object { 
    $objectPath = Split-Path $_.FullName -Parent
    $object = Split-Path $objectPath -Leaf
    Write-Output "    $(Get-TimeStamp) $object started..." | Tee-Object -file $log -Append
    if(!(Test-Path $pdf\$object)) { New-Item -ItemType Directory -Path $pdf\$object | Out-Null }
    & 'C:\Program Files\gs\gs9.27\bin\gswin64c.exe' -sDEVICE=pdfwrite -dQUIET -dSAFER -dBATCH -dNOPAUSE -dFastWebView -dCompatibilityLevel='1.5' -dDownsampleColorImages='true' -dColorImageDownsampleType=/Bicubic -dColorImageResolution='200' -dDownsampleGrayImages='true' -dGrayImageDownsampleType=/Bicubic -dGrayImageResolution='200' -dDownsampleMonoImages='true' -sOutputFile="$pdf\$object\$object.pdf" $_ *>> $log
    Write-Output "    $(Get-TimeStamp) ...complete." | Tee-Object -file $log -Append
}
Write-Output "$(Get-Timestamp) PDF downsampling complete." | Tee-Object -file $log -Append