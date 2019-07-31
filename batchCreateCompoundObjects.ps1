# batchCreateCompoundObjects.ps1
# Nathan Tallman, Created in August 2018, Updated in 30 July 2019
# https://git.psu.edu/digipres/contentdm/blob/master/batchCreateCompoundOjects.ps1

# DOCUMENT INCLUDED UTILITIES - VERIONS, and LICENSES

# Setup the switches
[cmdletbinding()]
Param(
    [Parameter()]
    [string]$metadata = "metadata.csv",    

    [Parameter()]
    [ValidateSet('both','text','pdf')]
    [string]$ocr = 'both',

    [Parameter()]
    [ValidateSet('keep','discard')]
    [string]$originals = 'keep',

    [Parameter(Mandatory)]
    [string]$path = $(Throw "Use -path to specify a path to the files for the batch.")  
)

# Variables
$tesseract = $(Resolve-Path "util\tesseract\tesseract.exe")
$gs = $(Resolve-Path "util\gs\bin\gswin64c.exe")
$gm = $(Resolve-Path "util\gm\gm.exe")
$adobe = $(Resolve-Path "util\icc\sRGB_v4.icc")
$path = $(Resolve-Path "$path")
$batch = $path | Split-Path -Leaf
$log = ($path + "\" + $batch + "_batchLoadCreate_log.txt")
$pwd = $(Get-Location).Path
$dirCount = (Get-ChildItem pst* -Directory -Path $path).Count

# Functions
function Get-TimeStamp { return "[{0:yyyy-MM-dd} {0:HH:mm:ss}]" -f (Get-Date) }
function Convert-OCR($ocrText) {
    (Get-Content $ocrText) | 
    ForEach-Object {
        $_ -replace '</', '' `
           -replace '/>', ''
    } | Set-Content $ocrText
}

Write-Output "----------------------------------------------" 2>&1  | Tee-Object -file $log
Write-Output "$(Get-Timestamp) CONTENTdm Tools Batch Create Compound Objects Starting." 2>&1  | Tee-Object -file $log -Append
Write-Output "Batch Location: $path"
Write-Output "Number of directories in batch: $dirCount" 2>&1  | Tee-Object -file $log -Append
Write-Output "----------------------------------------------" 2>&1  | Tee-Object -file $log -Append

# Read in the metadata
Set-Location $path 2>&1  | Tee-Object -file $log  -Append
$csv = Import-Csv -Path $path\$metadata
$objects = $csv | Group-Object -AsHashTable -AsString -Property Directory
$o = 0
ForEach ($object in $objects.keys) {
    # Export object-level meatadata for each object and begin processing
    $o++
    Write-Output "$(Get-Timestamp) Starting $object ($o of $($objects.Count) objects)." 2>&1  | Tee-Object -file $log -Append
    if (!(Test-Path $path\$object)) { New-Item -ItemType Directory -Path $path\$object | Out-Null }
    $objects.$object | Select-Object * -ExcludeProperty Directory | Export-Csv -Delimiter "`t" -Path $path\$object\$object.txt -NoTypeInformation
    Write-Output "        Object metadata for has been broken up into the the Directory Structure." | Tee-Object -file $log -Append
    Set-Location $path\$object 2>&1  | Tee-Object -file $log -Append
    $tiffs = (Get-ChildItem *.tif* -Recurse).Count
    # Find the TIF files, convert them to JP2, and move them to a scans subdirectory within the object.

    if (!(Test-Path scans)) { New-Item -ItemType Directory -Path scans | Out-Null }
    $i = 0
    Write-Output "        TIF to JP2 conversion starting..." 2>&1  | Tee-Object -file $log -Append
    Get-ChildItem *.tif* -Recurse | ForEach-Object {
        $i++
        Write-Output "        Converting $($_.Basename) ($i of $tiffs)." 2>&1  | Tee-Object -file $log -Append
        Invoke-Expression "$gm convert $($_.Name) source.icc" 2>&1  | Tee-Object -file $log -Append
        Invoke-Expression "$gm convert $($_.Name) -profile source.icc -intent Absolute -flatten -quality 85 -define jp2:prg=rlcp -define jp2:numrlvls=7 -define jp2:tilewidth=1024 -define jp2:tileheight=1024 -profile $adobe scans\$($_.BaseName).jp2" 2>&1  | Tee-Object -file $log -Append
        Remove-Item source.icc 2>&1  | Tee-Object -file $log -Append
    } 
    $jp2s = (Get-ChildItem *.jp2 -Recurse -Path scans).Count
    Write-Output "        $object TIF conversion complete: $tiffs TIFs and $jp2s JP2s. $(Get-Timestamp)" 2>&1  | Tee-Object -file $log -Append

    # Append item metadata to metadata.txt
    $f = 1
    Get-ChildItem *.jp2 -Recurse -Path scans | ForEach-Object {
        $objcsv = Import-Csv -Delimiter "`t" -Path $path\$object\$object.txt
        $row = @()
        $row += ('"Item ' + $f + ' of ' + $jp2s + '"')
        foreach ($field in ($objcsv | Select-Object * -ExcludeProperty Title,"File Name" | get-member -type NoteProperty)) { $row += ('""') }
        $row += ("$_") 
        $item = $row -join "`t"
        Write-Output $item | Out-File $path\$object\$object.txt -Append -Encoding UTF8
        $f++
    }
    Write-Output "        Item metadata has been added to $object.txt." 2>&1  | Tee-Object -file $log -Append

    # OCR, TXT and PDF
    $i = 0
    if ($ocr -match "both") {
        Write-Output "        OCR (PDF and TXT conversion) starting..." 2>&1  | Tee-Object -file $log -Append
        if (!(Test-Path transcripts)) { New-Item -ItemType Directory -Path transcripts | Out-Null }
        Get-ChildItem *.tif* -Recurse | ForEach-Object {
            $i++ 
            Write-Output "        Converting $($_.Basename) ($i of $tiffs)." 2>&1  | Tee-Object -file $log -Append
            Invoke-Expression "$tesseract $($_.FullName) transcripts\$($_.BaseName) txt pdf quiet" 2>&1  | Tee-Object -file $log -Append
        }
        Set-Location transcripts 2>&1  | Tee-Object -file $log -Append
        (Get-ChildItem *.pdf).Name > list.txt
        Invoke-Expression "$gs -sDEVICE=pdfwrite -dQUIET -dBATCH -dSAFER -dNOPAUSE -dFastWebView -dCompatibilityLevel='1.5' -dDownsampleColorImages='true' -dColorImageDownsampleType=/Bicubic -dColorImageResolution='200' -dDownsampleGrayImages='true' -dGrayImageDownsampleType=/Bicubic -dGrayImageResolution='200' -dDownsampleMonoImages='true' -sOUTPUTFILE='..\$object.pdf' $(get-content list.txt)" *>> $null
        $files = $(get-content list.txt)
        ForEach ($file in $files) { Remove-Item $file 2>&1  | Tee-Object -file $log -Append }
        Remove-Item list.txt 2>&1  | Tee-Object -file $log -Append
        Set-Location $path\$object 2>&1  | Tee-Object -file $log -Append
        Get-ChildItem *.txt -Recurse -Path transcripts | ForEach-Object {
            Convert-OCR -ocrText $_.FullName  2>&1  | Tee-Object -file $log -Append
        }
        Write-Output "        TXT transcripts have been sanitized for CONTENTdm." 2>&1  | Tee-Object -file $log -Append
        $txts = (Get-ChildItem *.txt -Recurse -Path transcripts).Count
        $pdfs = (Get-ChildItem *.pdf -Recurse).Count
        Write-Output "        $object OCR and PDF conversion complete: $tiffs TIFs, $txts TXTs, and $pdfs PDF. $(Get-Timestamp)" 2>&1  | Tee-Object -file $log -Append
    } elseif ($ocr -match "text") {
        Write-Output "        OCR (TXT conversion) starting..." 2>&1  | Tee-Object -file $log -Append
        if (!(Test-Path transcripts)) { New-Item -ItemType Directory -Path transcripts | Out-Null }
        Get-ChildItem *.tif* -Recurse | ForEach-Object {
            $i++
            Write-Output "        Converting $($_.Basename) ($i of $tiffs)." 2>&1  | Tee-Object -file $log -Append
            Invoke-Expression "$tesseract $($_.FullName) transcripts\$($_.BaseName) txt quiet" 2>&1  | Tee-Object -file $log -Append
        }
        Get-ChildItem *.txt -Recurse -Path transcripts | ForEach-Object {
            Convert-OCR -ocrText $_.FullName  2>&1  | Tee-Object -file $log -Append
        }
        Write-Output "        TXT transcripts have been sanitized for CONTENTdm." 2>&1  | Tee-Object -file $log -Append
        $txts = (Get-ChildItem *.txt -Recurse -Path transcripts).Count
        Write-Output "        $object OCR complete: $tiffs TIFs and $txts TXTs. $(Get-Timestamp)" 2>&1  | Tee-Object -file $log -Append
    } elseif ($ocr -match "pdf") {
        Write-Output "        OCR (PDF conversion) starting..." 2>&1  | Tee-Object -file $log -Append
        Get-ChildItem *.tif* -Recurse | ForEach-Object {
            $i++
            Write-Output "        Converting $($_.Basename) ($i of $tiffs)." 2>&1  | Tee-Object -file $log -Append
            Invoke-Expression "$tesseract $($_.FullName) $($_.BaseName) pdf quiet" 2>&1  | Tee-Object -file $log -Append
        }
        (Get-ChildItem *.pdf).Name > list.txt
        Invoke-Expression "$gs -sDEVICE=pdfwrite -dQUIET -dBATCH -dSAFER -dNOPAUSE -dFastWebView -dCompatibilityLevel='1.5' -dDownsampleColorImages='true' -dColorImageDownsampleType=/Bicubic -dColorImageResolution='200' -dDownsampleGrayImages='true' -dGrayImageDownsampleType=/Bicubic -dGrayImageResolution='200' -dDownsampleMonoImages='true' -sOUTPUTFILE='$object.pdf' $(get-content list.txt)" *>> $null
        $files = $(get-content list.txt)
        ForEach ($file in $files) { Remove-Item $file 2>&1  | Tee-Object -file $log -Append }
        Remove-Item list.txt 2>&1  | Tee-Object -file $log -Append
        $pdfs = (Get-ChildItem *.pdf -Recurse -Path object).Count
        Write-Output "        $object PDF conversion complete: $tiffs TIFs and $pdfs PDF. $(Get-Timestamp)" 2>&1  | Tee-Object -file $log -Append
    }

    # Process the originals
    if ($originals -match "keep") {
        if (!(Test-Path originals)) { New-Item -ItemType Directory -Path originals | Out-Null }
        Get-ChildItem *.tif* -Recurse | ForEach-Object { Move-Item $_.FullName -Destination originals 2>&1  | Tee-Object -file $log -Append }
        Write-Output "        Originals retained." 2>&1  | Tee-Object -file $log -Append
    } elseif ($originals -match "discard") {
        Get-ChildItem *.tif* -Recurse | ForEach-Object { Remove-Item $_.FullName 2>&1  | Tee-Object -file $log -Append }
        Write-Output "        Originals discarded." 2>&1  | Tee-Object -file $log -Append
    }

    Write-Output "$(Get-TimeStamp) Completed $object."
}

# Return to the starting directory
Set-Location "$pwd"
Write-Output "----------------------------------------------" 2>&1  | Tee-Object -file $log -Append
Write-Output "$(Get-Timestamp) CONTENTdm Tools Batch Create Compound Objects Complete." 2>&1  | Tee-Object -file $log -Append
Write-Output "Batch Location: $path"
Write-Output "Batch Log:      $log" 2>&1  | Tee-Object -file $log -Append
Write-Output "Number of objects metadata.csv:   $($objects.Count)" 2>&1  | Tee-Object -file $log -Append
Write-Output "Number of directories in batch:   $dirCount" 2>&1  | Tee-Object -file $log -Append
Write-Output "Number of directories processed:  $o" 2>&1  | Tee-Object -file $log -Append
Write-Output "---------------------------------------------" 2>&1  | Tee-Object -file $log -Append