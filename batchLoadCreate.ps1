# batchLoadCreate.ps1
# Nathan Tallman, Created in August 2018, Updated in 26 July 2019
# https://git.psu.edu/digipres/contentdm/edit/master/batchLoad

# DOCUMENT INCLUDED UTILITIES - VERIONS, and LICENSES
# Will GM work if they haven't installed manually? Jasper?
## add in item metadata bit? Do this AFTER the first foreach loop!
# OCR language parameter?
# Hierarchal compound objects?
# non-compound objects? (plain items?)

# Setup the switches
[cmdletbinding()]
Param(
    [switch]$jp2, 
    [switch]$ocrpdf,
    [switch]$ocr,
    [switch]$pdf,
    [switch]$deltif,
    [Parameter(Mandatory)]
    [string]$path = $(Throw "Use -path to specify a path to the files for the batch.")  
)

# Variables
$tesseract = $(Resolve-Path "util\tesseract\tesseract.exe")
$gs = $(Resolve-Path "util\gs\bin\gswin64c.exe")
$gm = $(Resolve-Path "util\gm\gm.exe")
$adobe = $(Resolve-Path "util\icc\sRGB_v4.icc")
$path = $(Resolve-Path $path)
$batch = $path | Split-Path -Leaf
$log = ($path + "\" + $batch + "_batchLoadCreate_log.txt")
$pwd = $(Get-Location).Path
function Get-TimeStamp { return "[{0:yyyy-MM-dd} {0:HH:mm:ss}]" -f (Get-Date) }

Write-Output "----------------------------------------------" | Tee-Object -file $log -Append
Write-Output "$(Get-Timestamp) CONTENTdm Compound Object Batch Starting." | Tee-Object -file $log -Append
Write-Output "Batch Name: $batch" | Tee-Object -file $log -Append
Write-Output "----------------------------------------------" | Tee-Object -file $log -Append

# Read in the metadata
Set-Location "$path" | Tee-Object -file $log  -Append
$metadata = Import-Csv -Path $path\metadata.csv
$objects = $metadata | Group-Object -AsHashTable -AsString -Property Directory
$o = 0
ForEach ($object in $objects.keys) {
    # Export object-level meatadata for each object and begin processing
    $o++
    Write-Output "$(Get-Timestamp) Starting $object ($o of $($objects.Count) objects)." | Tee-Object -file $log -Append
    if (!(Test-Path $path\$object)) { New-Item -ItemType Directory -Path $path\$object | Out-Null }
    $objects.$object | Export-Csv -Delimiter "`t" -Path $path\$object\$object.txt -NoTypeInformation
    Set-Location "$path\$object" | Tee-Object -file $log -Append
    $tiffs = (Get-ChildItem *.tif* -Recurse).Count
    # Find the TIF files, convert them to JP2, and move them to a scans subdirectory within the object.
    if ($jp2) {
        if (!(Test-Path scans)) { New-Item -ItemType Directory -Path scans | Out-Null }
        $i = 0
        Get-ChildItem *.tif* -Recurse | ForEach-Object {
            $i++
            Write-Output "    Converting $($_.Basename) ($i of $tiffs)" | Tee-Object -file $log -Append
            Invoke-Expression "$gm convert $($_.Name) source.icc" | Tee-Object -file $log
            Invoke-Expression "$gm convert $($_.Name) -profile source.icc -intent Absolute -flatten -quality 85 -define jp2:prg=rlcp -define jp2:numrlvls=7 -define jp2:tilewidth=1024 -define jp2:tileheight=1024 -profile $adobe scans\$($_.BaseName).jp2" | Tee-Object -file $log
            Remove-Item source.icc | Tee-Object -file $log
        } 
        $jp2s = (Get-ChildItem *.jp2 -Recurse -Path scans).Count
        Write-Output "    $object JP2 conversion complete: $tiffs TIFs and $jp2s JP2s. $(Get-Timestamp)" | Tee-Object -file $log -Append
    }

    # OCR and PDF
    if (($ocrpdf)) { 
        Write-Output "    OCR and PDF starting..." | Tee-Object -file $log -Append
        if (!(Test-Path transcripts)) { New-Item -ItemType Directory -Path transcripts | Out-Null }
        Get-ChildItem *.tif* -Recurse | ForEach-Object {
            Invoke-Expression "$tesseract $($_.FullName) transcripts\$($_.BaseName) txt pdf quiet" | Tee-Object -file $log -Append
        } | Tee-Object -file $log -Append
        Set-Location transcripts | Tee-Object -file $log -Append
        (Get-ChildItem *.pdf).Name > list.txt
        Invoke-Expression "$gs -sDEVICE=pdfwrite -dQUIET -dBATCH -dSAFER -dNOPAUSE -dFastWebView -dCompatibilityLevel='1.5' -dDownsampleColorImages='true' -dColorImageDownsampleType=/Bicubic -dColorImageResolution='200' -dDownsampleGrayImages='true' -dGrayImageDownsampleType=/Bicubic -dGrayImageResolution='200' -dDownsampleMonoImages='true' -sOUTPUTFILE='..\$object.pdf' $(get-content list.txt)" *>> Out-Null
        $files = $(get-content list.txt)
        ForEach ($file in $files) { Remove-Item $file | Tee-Object -file $log -Append }
        Remove-Item list.txt | Tee-Object -file $log -Append
        Set-Location "$path\$object" | Tee-Object -file $log -Append
        $txts = (Get-ChildItem *.txt -Recurse -Path transcripts).Count
        $pdfs = (Get-ChildItem *.pdf -Recurse).Count
        Write-Output "    $object OCR and PDF conversion complete: $tiffs TIFs, $txts TXTs, and $pdfs PDF. $(Get-Timestamp)" | Tee-Object -file $log -Append
    } 

    if ($ocr) {
        Write-Output "    OCR starting..." | Tee-Object -file $log -Append
        if (!(Test-Path transcripts)) { New-Item -ItemType Directory -Path transcripts | Out-Null }
        Get-ChildItem *.tif* -Recurse | ForEach-Object {
            Invoke-Expression "$tesseract $($_.FullName) transcripts\$($_.BaseName) txt quiet" | Tee-Object -file $log -Append
        } | Tee-Object -file $log -Append
        $txts = (Get-ChildItem *.txt -Recurse -Path transcripts).Count
        Write-Output "    $object OCR complete: $tiffs TIFs and $txts TXTs. $(Get-Timestamp)" | Tee-Object -file $log -Append
    }

    if ($pdf) {
        Write-Output "    PDF conversion starting" | Tee-Object -file $log -Append
        Get-ChildItem *.tif* -Recurse | ForEach-Object {
            Invoke-Expression "$tesseract $($_.FullName) $($_.BaseName) pdf quiet" | Tee-Object -file $log -Append
        } | Tee-Object -file $log -Append
        (Get-ChildItem *.pdf).Name > list.txt
        Invoke-Expression "$gs -sDEVICE=pdfwrite -dQUIET -dBATCH -dSAFER -dNOPAUSE -dFastWebView -dCompatibilityLevel='1.5' -dDownsampleColorImages='true' -dColorImageDownsampleType=/Bicubic -dColorImageResolution='200' -dDownsampleGrayImages='true' -dGrayImageDownsampleType=/Bicubic -dGrayImageResolution='200' -dDownsampleMonoImages='true' -sOUTPUTFILE="$object.pdf" $(get-content list.txt)" *>> $log
        $files = $(get-content list.txt)
        ForEach ($file in $files) { Remove-Item $file | Tee-Object -file $log -Append }
        Remove-Item list.txt | Tee-Object -file $log -Append
        $pdfs = (Get-ChildItem *.pdf -Recurse -Path object).Count
        Write-Output "    $object PDF conversion complete: $tiffs TIFs and $pdfs PDF. $(Get-Timestamp)" | Tee-Object -file $log -Append
    }

    # Find the tif files and delete them.
    if ($deltif) {
        Get-ChildItem *.tif* -Recurse | ForEach-Object { Remove-Item -Path $_.FullName | Tee-Object -file $log -Append }
        Write-Output "    TIFs deleted." | Tee-Object -file $log -Append
    }

    Write-Output "$(Get-TimeStamp) Completed $object.)"
}

# Return to the starting directory
Set-Location "$pwd"
Write-Output "----------------------------------------------" | Tee-Object -file $log -Append
$objectCount = (Get-ChildItem pst* -Directory -Path $path).Count
Write-Output "$(Get-Timestamp) CONTENTdm Compound Object Batch Complete." | Tee-Object -file $log -Append
Write-Output "Batch Name: $batch" | Tee-Object -file $log -Append
Write-Output "Batch Location: $path"
Write-Output "Log File: $log" | Tee-Object -file $log -Append
Write-Output "Number of objects metadata.csv: $($objects.Count)" | Tee-Object -file $log -Append
Write-Output "Number of directories in batch: $objectCount" | Tee-Object -file $log -Append
Write-Output "Number of directories batched:  $o" | Tee-Object -file $log -Append
Write-Output "---------------------------------------------" | Tee-Object -file $log -Append