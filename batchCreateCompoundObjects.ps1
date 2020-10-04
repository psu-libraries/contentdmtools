# batchCreate.ps1
<#
    .SYNOPSIS
    Parallel process a batch of directories containing TIF images (one directory per object) and a metadata CSV describing each object, into Directory Structure, Document Type, Items and Compound-Objects for CONTENTdm.
    .DESCRIPTION
    Process metadata CSV into tab-d item and compound-object metadata files in directory structure. Complete series of actions for every object: Convert TIFs to JP2, organize existing JP2s or skip JP2 step. Convert TIF to TXT, PDF, or TXT and PDF; alternatively, extract text from an existing PDF; optimimize TXT and PDF outputs. Append item-level metadata tab-d item or compound-object metadata file. Organize or discard TIF files.
    .PARAMETER path
    The filepath to the root directory for a batch of objects.
    .PARAMETER metadata
    The filename of a CSV of metadata for the batch. Must be available at the path parameter filepath. (DEFAULT VALUE: metadata.csv)
    .PARAMETER jp2
    Options for JP2 derivatives: true, false, or skip. True) Generate JP2 images using GraphicsMagick and save them in a scans subdirectory, False) Organize existing JP2 images into a scans subdirectory, Skip) Do nothing. (DEFAULT VALUE: true)
    .PARAMETER ocr
    Options for OCR derivatives: text, pdf, both, extract, skip. Text) 1 TXT file for each TIF file, saved in a transcripts directory, PDF) 1 PDF for the object, saved in the object directory, Both) TXT transcripts and object PDF, Extract) Extract text from existing searchable PDF in the object directory using pdftk (no OCR engine), Skip) Do nothing. (DEFAULT VALUE: both)
    .PARAMETER ocrengine
    Options for OCR engine: ABBYY and tesseract. ABBYY) Penn State licensed commercial software, Tesseract) Open-source OCR software. (DEFAULT VALUE: ABBYY)
    .PARAMETER originals
    Optins for handling of original TIFs: keep, discard, skip. Keep) Keep the TIFs and move them into an originals subdirectory, Discard) Delete the original TIFs, Skip) Do nothing, leave the TIFs where they are.
    .PARAMETER throttle
    Integer for the number of CPU processes when copying TIFs to the ABBYY server. (DEFAULT VALUE: 6)
    .EXAMPLE
    .\batchCreate.ps1 -path E:\pstsc_01822\2018-02\ -jp2 no -ocr extract -ocrengine tesseract -originals discard -throttle 6
    .INPUTS
    System.String
    System.Integer
    .NOTES
    Required fields and controlled vocabularies must be disabled in the Admin UI or CONTENTdm Cathcer will fail.
    .LINK
    https://github.com/psu-libraries/contentdmtools/blob/community/docs/batchCreateCompoundObjects.md
#>

# Parameters
[cmdletbinding()]
Param(
    [Parameter(Mandatory)]
    [string]
    $path = $(Throw "Use -path to specify a path to the files for the batch."),

    [Parameter()]
    [string]
    $metadata = "metadata.csv",

    [Parameter()]
    [ValidateSet('true', 'false', 'skip')]
    [string]
    $jp2 = 'true',

    [Parameter()]
    [ValidateSet('both', 'text', 'pdf', 'extract', 'skip')]
    [string]
    $ocr = 'both',

    [Parameter()]
    [string]
    [ValidateSet('ABBYY', 'tesseract')]
    $ocrengine = 'tesseract',

    [Parameter()]
    [ValidateSet('keep', 'discard', 'skip')]
    [string]
    $originals,

    [Parameter()]
    [int16]
    $throttle = 4
)

# Variables
$scriptpath = $MyInvocation.MyCommand.Path
$cdmt_root = Split-Path $scriptpath
$path = $(Resolve-Path "$path")
$batch = $path | Split-Path -Leaf
if (!(Test-Path $cdmt_root\logs)) { New-Item -ItemType Directory -Path $cdmt_root\logs | Out-Null }
$log_batchCreate = ($cdmt_root + "\logs\batchCreate_" + $batch + "_log_" + $(Get-Date -Format yyyy-MM-ddTHH-mm-ss-ffff) + ".txt")
$cdmt_rootCount = (Get-ChildItem pst* -Directory -Path $path).Count


# Standard Variables
$tesseract = "$cdmt_root\tesseract\tesseract.exe"
$gs = "$cdmt_root\gs\bin\gswin64c.exe"
$gm = "$cdmt_root\gm\gm.exe"
$adobe = "$cdmt_root\icc\sRGB_v4.icc"
$pdf2text = "$cdmt_root\xpdf\pdftotext.exe"

# Import Library
. $cdmt_root\util\lib.ps1

$start = Get-Date
Write-Output "----------------------------------------------" | Tee-Object -file $log_batchCreate
Write-Output "$(. Get-TimeStamp) CONTENTdm Tools Batch Create Starting." | Tee-Object -file $log_batchCreate -Append
Write-Output "Number of directories in batch: $cdmt_rootCount" | Tee-Object -file $log_batchCreate -Append
Write-Output "Staging Path:       $path" | Tee-Object -file $log_batchCreate -Append
Write-Output "Metadata CSV:       $metadata" | Tee-Object -file $log_batchCreate -Append
Write-Output "JP2 Processing:     $jp2" | Tee-Object -file $log_batchCreate -Append
Write-Output "OCR Processing:     $ocr" | Tee-Object -file $log_batchCreate -Append
Write-Output "OCR Engine:         $ocrengine" | Tee-Object -file $log_batchCreate -Append
Write-Output "Originals Handling: $originals" | Tee-Object -file $log_batchCreate -Append
Write-Output "Throttle:           $throttle" | Tee-Object -file $log_batchCreate -Append
Write-Output ("Executed Command:   " + $MyInvocation.Line) | Tee-Object -FilePath $log_batchCreate -Append
Write-Output "----------------------------------------------" | Tee-Object -file $log_batchCreate -Append

# Read in the metadata, trim whitespaces, and export object-level meatadata for each object into directory structure.
Write-Output "Batch metadata will be split into tab-d item and compound-object metadata files, in directory structure." | Tee-Object -file $log_batchCreate -Append
. Split-Object-Metadata -path $path -metadata $metadata | Tee-Object -file $log_batchCreate -Append

Write-Verbose "$(. Get-TimeStamp) Setting up object loop, reading list of objects from metadata csv."
$o = 0
$items = @()
$objects = @()

ForEach ($record in $csv) {
    # Keep track of record type for sorting, if necessary
    if ($csv.Level) {
        if ($record.Level -eq "Item") {
            $items += $record.Directory
        }
        if ($record.Level -eq "Object") {
            $objects += $record.Directory
        }
    }
}

ForEach ($object in $objects) {
    #$object = "$($object.Directory)"
    $o++
    $percent = ($o / $objects.Count) * 100
    Write-Progress -Activity "Batch Create" -Status "Processing objects in $metadata"  -CurrentOperation "Processing $object, $o of $($objects.Count)" -PercentComplete $percent
    Write-Output "$(. Get-TimeStamp) Starting $object ($o of $($objects.Count) resources)." | Tee-Object -file $log_batchCreate -Append

    Write-Verbose "$(. Get-TimeStamp) [$object] Check for the presence of redacted TIF files and separate according to value of originals parameter."
    $redacted = & Find-Redacted-Filesets -path $path\$object

    if ($null -ne $redacted.redacted) {
        Write-Verbose "Redacted Files:"
        Write-Verbose $redacted.redacted
        if ($originals -eq "discard") {
            $redacted.unredacted | ForEach-Object {
                Remove-Item $path\$object\$_ 2>&1 | Tee-Object -file $log_batchCreate -Append
            }
        }
        elseif ($originals -eq "keep") {
            if (!(Test-Path $path\$object\originals)) { New-Item -ItemType Directory -Path $path\$object\originals | Out-Null }
            $redacted.unredacted | ForEach-Object {
                Move-Item $path\$object\$_ -Destination $path\$object\originals 2>&1 | Tee-Object -file $log_batchCreate -Append
            }
        }
        elseif ($originals -eq "skip") {
            if (!(Test-Path $path\$object\unredacted)) { New-Item -ItemType Directory -Path $path\$object\unredacted | Out-Null }
            $redacted.unredacted | ForEach-Object {
                Move-Item $path\$object\$_ -Destination $path\$object\unredacted 2>&1 | Tee-Object -file $log_batchCreate -Append
            }
        }
    }

    $tiffs = (Get-ChildItem *.tif* -Path $path\$object).Count

    if ($jp2 -eq "true") {
        Write-Verbose "$(. Get-TimeStamp) [$object] Finding TIF files, converting them to JP2. Item JP2s are saved in the items directory, object JP2s are saved in a scans object subdirectory. TIFs larger than 8000 pixels will be reduced in size before conversion."

        # Find and reduce TIFs with edges over 8000 pixels.
        Get-ChildItem -Path $path\$object -Filter "*.tif*" | ForEach-Object -Parallel {
            $image = New-Object -ComObject Wia.ImageFile
            $image.LoadFile($_.FullName)
            If (($image.Width -gt 8000) -or ($image.Height -gt 8000)) {
                Write-Verbose "Reducing $_"
                $name = $_.BaseName
                $reduced = ($name + "_reduced" + $_.Extension)
                $original = $_.FullName
                Invoke-Expression "$using:gm convert -resize 8000x8000> $original $using:path\$using:object\$reduced"
                if (!(Test-Path $using:path\$using:object\originals)) { New-Item -ItemType Directory -Path $using:path\$using:object\originals | Out-Null }
                Move-Item -Path $_.Fullname -Destination $using:path\$using:object\originals\
                Rename-Item -Path $using:path\$using:object\$reduced -NewName $_
            }
        }

        Write-Output "        JP2 conversion starting: $tiffs TIF." | Tee-Object -file $log_batchCreate -Append
        if (!(Test-Path $path\$object\scans)) { New-Item -ItemType Directory -Path $path\$object\scans | Out-Null }
        & Convert-to-JP2 -path $path -object $object -items $items -throttle $throttle -log $log_batchCreate -gm $gm -adobe $adobe
        $jp2s = (Get-ChildItem *.jp2 -Path $path\$object\scans  -Recurse).Count
        if ($record.Level -eq "Item") {
            Write-Output "        JP2 conversion complete. $(. Get-TimeStamp)" | Tee-Object -file $log_batchCreate -Append
        }
        else {
            Write-Output "        JP2 conversion complete: $tiffs TIF and $jp2s JP2. $(. Get-TimeStamp)" | Tee-Object -file $log_batchCreate -Append
        }
    }
    elseif ($jp2 -eq "false") {
        if ($record.Level -eq "Item") {
            Write-Verbose "$(. Get-TimeStamp) [$object] Finding existing JP2s and moving them to items directory"
            if (!(Test-Path $path\items)) { New-Item -ItemType Directory -Path $path\items | Out-Null }
            Get-ChildItem -Path $path\$object *.jp2 -Recurse | ForEach-Object {
                Move-Item $_.FullName $path\items -Force | Tee-Object -file $log_batchCreate -Append
            }
            Write-Output "        JP2 files have been moved to items directory." | Tee-Object -file $log_batchCreate -Append
        }
        else {
            Write-Verbose "$(. Get-TimeStamp) [$object] Finding existing JP2s and moving them to a scans subdirectory"
            if (!(Test-Path $path\$object\scans)) { New-Item -ItemType Directory -Path $path\$object\scans | Out-Null }
            Get-ChildItem -Path $path\$object *.jp2 -Recurse | ForEach-Object {
                Move-Item $_.FullName $path\$object\scans -Force | Tee-Object -file $log_batchCreate -Append
            }
            $jp2s = (Get-ChildItem *.jp2 -Path $path\$object\scans  -Recurse).Count
            Write-Output "        JP2 files ($jp2s) have been moved to a scans subdirectory." | Tee-Object -file $log_batchCreate -Append
        }
    }
    elseif ($jp2 -eq "skip") {
        Write-Verbose "$(. Get-TimeStamp) [$object] JP2 processing set to skip."
    }

    <#     # Append item metadata to metadata.txt
    if ($record.Level -eq "Item") {
        Write-Verbose "$(. Get-TimeStamp) [$object] Update tab-d item metadata file with JP2 file name of each item."
        Write-Output "        Deriving item file names and adding to tab-d item metadata file." | Tee-Object -file $log_batchCreate -Append
        $recordDir = $record.Directory
        if ($record -eq $csv[0]) {
            $itemdata = Import-Csv -Path $path\itemMetadata.txt -Delimiter `t
        }
        elseif (!($record -eq $csv[0])) {
            $itemdata = Import-Csv -Path $path\items\metadata.txt -Delimiter `t
        }
        $itemDir = $itemdata.Directory
        $match = [array]::IndexOf($itemDir, $recordDir)
        $itemdata[$match]."File Name" = (Get-ChildItem -Path $path\items -Filter "$recordDir*")
        $itemdata | Export-Csv $path\items\metadata.txt -Delimiter `t -NoTypeInformation
    }
    else {
        Write-Verbose "$(. Get-TimeStamp) [$object] Scan JP2s in object directory and derive item-level metadata, appending it to tab-d compound object metadata file."
        Write-Output "        Deriving item-level metadata and adding it to the tab-d compound-object object metadata file." | Tee-Object -file $log_batchCreate -Append
        & Convert-Item-Metadata -path $path -object $object | Tee-Object -file $log_batchCreate -Append
    } #>

    # OCR, TXT and PDF
    if ($ocr -eq "both") {
        Write-Verbose "$(. Get-TimeStamp) [$object] Converting TIF to TXT and PDF using $ocrengine. Item-level TXT will be saved in a transcripts subdirectory, object-level PDF will be saved in object directory."
        Write-Output "        OCR starting (PDF and TXT output)." | Tee-Object -file $log_batchCreate -Append
        if (!(Test-Path $path\$object\transcripts)) { New-Item -ItemType Directory -Path $path\$object\transcripts | Out-Null }
        if ($ocrengine -eq "ABBYY") {
            & Convert-to-Text-And-PDF-ABBYY -path $path -object $object -pdftk $pdftk 2>&1 | Tee-Object -file $log_batchCreate -Append
        }
        elseif ($ocrengine -eq "tesseract") {
            & Convert-to-Text-And-PDF -path $path -object $object -throttle $throttle -log $log_batchCreate -tesseract $tesseract 2>&1 | Tee-Object -file $log_batchCreate -Append
            & Merge-PDF -path $path -object $object -pdfs transcripts -log $log_batchCreate -gs $gs 2>&1 | Tee-Object -file $log_batchCreate -Append

        }
        Write-Verbose "Optize TXT for CONTENTdm indexing"
        Get-ChildItem -Path $path\$object\transcripts *.txt -Recurse | ForEach-Object {
            & Optimize-OCR -ocrText $_.FullName | Out-Null
        }
        $txts = (Get-ChildItem *.txt -Path $path\$object\transcripts -Recurse).Count
        $pdfs = (Get-ChildItem *.pdf -Path $path\$object -Recurse).Count
        Write-Output "        OCR complete: $tiffs TIFs, $txts TXTs, and $pdfs PDF. $(. Get-TimeStamp)" | Tee-Object -file $log_batchCreate -Append
    }
    elseif ($ocr -eq "text") {

        Write-Verbose "$(. Get-TimeStamp) [$object] Converting TIF to TXT using $ocrengine. Item-level TXT will be saved in a transcripts subdirectory."
        Write-Output "        OCR starting (TXT output)." | Tee-Object -file $log_batchCreate -Append
        if (!(Test-Path $path\$object\transcripts)) { New-Item -ItemType Directory -Path $path\$object\transcripts | Out-Null }
        if ($ocrengine -eq "ABBYY") {
            & Convert-to-Text-ABBYY -path $path -object $object -throttle $throttle -log $log_batchCreate
        }
        elseif ($ocrengine -eq "tesseract") {
            & Convert-to-Text -path $path -object $object -throttle $throttle -log $log_batchCreate -gm $gm -tesseract $tesseract
        }
        Get-ChildItem -Path $path\$object\transcripts *.txt -Recurse | ForEach-Object {
            & Optimize-OCR -ocrText $_.FullName | Out-Null
        }
        $tiffs = (Get-ChildItem *.tif* -Path $path\$object  -Recurse).Count
        $txts = (Get-ChildItem *.txt -Path $path\$object\transcripts -Recurse).Count
        Write-Output "        OCR complete: $tiffs TIFs and $txts TXTs. $(. Get-TimeStamp)" | Tee-Object -file $log_batchCreate -Append

    }
    elseif ($ocr -eq "pdf") {
        Write-Verbose "$(. Get-TimeStamp) [$object] Converting TIF to PDF using $ocrengine. Object-level PDF will be saved in the object directory."
        Write-Output "        OCR starting (PDF output)." | Tee-Object -file $log_batchCreate -Append

        if ($ocrengine -eq "ABBYY") {
            & Convert-to-PDF-ABBYY -path $path -object $object -throttle $throttle -log $log_batchCreate
        }
        elseif ($ocrengine -eq "tesseract") {
            if (!(Test-Path $path\$object\transcripts)) { New-Item -ItemType Directory -Path $path\$object\transcripts | Out-Null }
            & Convert-to-PDF -path $path -object $object -throttle $throttle -log $log_batchCreate  -tesseract $tesseract 2>&1 | Tee-Object -file $log_batchCreate -Append
            & Merge-PDF -path $path -object $object -pdfs transcripts -log $log_batchCreate -gs $gs
            Remove-Item $path\$object\transcripts -Recurse | Tee-Object -file $log_batchCreate -Append
        }
        $pdfs = (Get-ChildItem *.pdf -Path $path\$object  -Recurse).Count
        Write-Output "        OCR complete: $tiffs TIFs and $pdfs PDF. $(. Get-TimeStamp)" | Tee-Object -file $log_batchCreate -Append
    }
    elseif ($ocr -eq "extract") {
        if (!($record.Level -eq "Item")) {
            Write-Verbose "$(. Get-TimeStamp) [$object] Extracting TXT from existing PDF in the object directory using pdftk. Item-level TXT will be saved in a transcripts subdirectory."
            Write-Output "        OCR starting (TXT from PDF output)." | Tee-Object -file $log_batchCreate -Append
            . Get-Text-From-PDF -path $path -object $object -log $log_batchCreate -pdftk $pdftk -pdf2text $pdf2text
            $tiffs = (Get-ChildItem *.tif* -Path $path\$object  -Recurse).Count
            $txts = (Get-ChildItem *.txt -Path $path\$object\transcripts -Recurse).Count
            $pdfs = (Get-ChildItem *.pdf -Path $path\$object  -Recurse).Count
            Write-Output "        OCR complete: $tiffs TIFs, $txts TXTs, and $pdfs PDF. $(. Get-TimeStamp)" | Tee-Object -file $log_batchCreate -Append
        }
        else { }
    }
    elseif ($ocr -eq "skip") {
        Write-Verbose "OCR processing set to skip."
    }

    # Process the originals
    if ($originals -eq "keep") {
        Write-Verbose "$(. Get-TimeStamp) [$object] Arranging TIFs into a originals subirectory."
        if (!(Test-Path $path\$object\originals)) { New-Item -ItemType Directory -Path $path\$object\originals | Out-Null }
        # Delete any reduced tifs
        Get-ChildItem -Path $path\$object *_reduced.tif* -Recurse | ForEach-Object {
            Remove-Item $_.FullName | Out-Null
        }
        # Move tifs to originals directory
        Get-ChildItem -Path $path\$object *.tif* -Recurse | ForEach-Object {
            Move-Item $_.FullName -Destination $path\$object\originals 2>&1 | Tee-Object -file $log_batchCreate -Append
        }
        Write-Output "        Originals retained." | Tee-Object -file $log_batchCreate -Append
    }
    elseif ($originals -eq "discard") {
        Write-Verbose "$(. Get-TimeStamp) [$object] Deleting TIFs."
        Get-ChildItem -Path $path\$object *.tif* -Recurse | ForEach-Object {
            Remove-Item $_.FullName 2>&1 | Tee-Object -file $log_batchCreate -Append
        }
        if (Test-Path $path\$object\originals) { Remove-Item $path\$object\originals -Recurse | Out-Null }
        Write-Output "        Originals discarded." | Tee-Object -file $log_batchCreate -Append
    }
    elseif ($originals -eq "skip") {
        Write-Verbose "$(. Get-TimeStamp) [$object] Originals handling set to skip, TIFs will be left in place."
        # Delete any reduced tifs
        Get-ChildItem -Path $path\$object *_reduced.tif* -Recurse | ForEach-Object {
            Remove-Item $_.FullName | Out-Null
        }
        # Move any unreduced originals back to the object directory and delete the originals directory
        if (Test-Path $path\$object\originals) {
            Get-ChildItem -Path $path\$object\originals | ForEach-Object { Move-Item $_.FullName -Destination $path\$object\ }
            Remove-Item -Path $path\$object\originals | Out-Null
        }
    }
    if ($record.Level) {
        Write-Output "        Type is $($record.Level)." | Tee-Object -file $log_batchCreate -Append
    }

    # Sort objects by access restrictions
    if ($record."Restriction Type") {
        if ($record."Restriction Type" -eq "none") {
            Write-Verbose "$(. Get-TimeStamp) [$object] Moving object to open-access directory."
            if (!(Test-Path $path\open-access)) { New-Item -ItemType Directory -Path $path\open-access | Out-Null }
            Move-Item $path\$object -Destination $path\open-access 2>&1 | Tee-Object -file $log_batchCreate -Append
        }
        if ($record."Restriction Type" -eq "local") {
            Write-Verbose "$(. Get-TimeStamp) [$object] Moving object to psu-access directory."
            if (!(Test-Path $path\psu-access)) { New-Item -ItemType Directory -Path $path\psu-access | Out-Null }
            Move-Item $path\$object -Destination $path\psu-access 2>&1 | Tee-Object -file $log_batchCreate -Append
        }
        if ($record."Restriction Type" -eq "total") {
            Write-Verbose "$(. Get-TimeStamp) [$object] Moving object to no-access directory."
            if (!(Test-Path $path\no-access)) { New-Item -ItemType Directory -Path $path\no-access | Out-Null }
            Move-Item $path\$object -Destination $path\no-access 2>&1 | Tee-Object -file $log_batchCreate -Append
        }
    }

    Write-Output "$(. Get-TimeStamp) Completed $object." | Tee-Object -file $log_batchCreate -Append
}

Remove-Item -Path $path\itemMetadata.txt | Out-Null

# Cleanup files
<# $headers = $csv | Get-member -MemberType 'NoteProperty' | Select-Object -ExpandProperty 'Name'
if ("Level" -in $headers) {
    if (($csv.Level | Get-Unique).Count -gt 1) {
        Write-Output "$(. Get-TimeStamp) Grouping items and objects for easier loading."
        Write-Output "Items($($items.count)): $items`nCompound Objects($($objects.count)): $objects"
        foreach ($item in $items) {
            Remove-Item -Path $path\$item -Recurse -Force | Out-Null
        }
        Remove-Item -Path $path\itemMetadata.txt | Out-Null
        $itemdata = import-csv $path\items\metadata.txt -Delimiter `t
        $itemdata | Select-Object * -ExcludeProperty Directory | Export-Csv $path\items\metadata.txt -Delimiter `t -NoTypeInformation
        foreach ($entry in $objects) {
            if (!(Test-Path $path\objects)) { New-Item -ItemType Directory -Path $path\objects | Out-Null }
            Move-Item -Path $path\$entry -Destination $path\objects\$entry
        }
    }
    if (($($csv.Level | Get-Unique).Count -le 1) -and ($csv.Level -eq "Item")) {
        foreach ($item in $items) {
            Remove-Item -Path $path\$item -Recurse -Force | Out-Null
        }
        Remove-Item -Path $path\itemMetadata.txt | Out-Null
        $itemdata = import-csv $path\items\metadata.txt -Delimiter `t
        $itemdata | Select-Object * -ExcludeProperty Directory | Export-Csv $path\items\metadata.txt -Delimiter `t -NoTypeInformation
        Move-Item $path\items\* $path\ | Out-Null
        Remove-Item $path\items | Out-Null
    }
    if (($($csv.Level | Get-Unique).Count -le 1) -and ($csv.Level -eq "Object")) {
        Remove-Item -Path $path\itemMetadata.txt | Out-Null
    }
} #>

$end = Get-Date
$runtime = New-TimeSpan -Start $start -End $end

Write-Output "----------------------------------------------" | Tee-Object -file $log_batchCreate -Append
Write-Output "$(. Get-TimeStamp) CONTENTdm Tools Batch Create Complete." | Tee-Object -file $log_batchCreate -Append
Write-Output "Total Elapsed Time:`t`t`t$runtime"
Write-Output "Batch Location:`t`t`t`t$path" | Tee-Object -file $log_batchCreate -Append
Write-Output "Batch Log:`t`t`t`t$log_batchCreate" | Tee-Object -file $log_batchCreate -Append
Write-Output "Number of objects in $($metadata):`t$($objects.Count)" | Tee-Object -file $log_batchCreate -Append
Write-Output "Number of objects processed:`t`t$o" | Tee-Object -file $log_batchCreate -Append
Write-Output "---------------------------------------------" | Tee-Object -file $log_batchCreate -Append
if ((($($csv.Count) -ne $o) -or ($($csv.Count) -ne $cdmt_rootCount) -or ($cdmt_rootCount -ne $o))) {
    Write-Warning "Warning: Check the above report and log, there is a missmatch in the final numbers." | Tee-Object -file $log_batchCreate -Append
    Write-Output "Warning: Check the above report and log, there is a missmatch in the final numbers." >> $log_batchCreate
}
Write-Host -ForegroundColor Green "This window can be closed at anytime."