# Variables
$tesseract = "$PSScriptRoot\tesseract\tesseract.exe"
$gs = "$PSScriptRoot\gs\bin\gswin64c.exe"
$gm = "$PSScriptRoot\gm\gm.exe"
$adobe = "$PSScriptRoot\icc\sRGB_v4.icc"
$pdftk = "$PSScriptRoot\pdftk\bin\pdftk.exe"
$pdf2text = "$PSScriptRoot\xpdf\pdftotext.exe"

function Get-TimeStamp {
    return (Get-Date -Format u)
}
function Get-Org-Settings {
    Write-Verbose "Get-Org-Settings checking for stored settings."
    $Return = @{ }
    if (Test-Path settings\org.csv) {
        $orgcsv = $(Resolve-Path settings\org.csv)
        $orgcsv = Import-Csv settings\org.csv
        foreach ($org in $orgcsv) {
            Write-Verbose ("Public URL: " + $org.public)
            $Return.public = $org.public
            Write-Verbose ("Server URL: " + $org.server)
            $Return.server = $org.server
            Write-Verbose ("License: " + $org.license)
            $Return.license = $org.license
            $Global:cdmt_public = $org.public
            $Global:cdmt_server = $org.server
            $Global:cdmt_license = $org.license
        }
    }
    Return $Return
}

#SOAP functions # https://ponderingthought.com/2010/01/17/execute-a-soap-request-from-powershell/
function Send-SOAPRequest {
    [cmdletbinding()]
    Param(
        [Parameter()]
        [Xml]
        $SOAPRequest,

        [Parameter()]
        [string]
        $URL,

        [Parameter()]
        $editCount
    )

    Write-Verbose "Preparing to sending SOAP request to Catcher."
    $soapWebRequest = [System.Net.WebRequest]::Create($URL)
    $soapWebRequest.ContentType = 'text/xml;charset="utf-8"'
    $soapWebRequest.Accept = "text/xml"
    $soapWebRequest.Method = "POST"

    Write-Verbose "Initiating send."
    $requestStream = $soapWebRequest.GetRequestStream()
    $SOAPRequest.Save($requestStream)
    $requestStream.Close()

    Write-Verbose "Send complete, waiting for response."
    $resp = $soapWebRequest.GetResponse()
    $responseStream = $resp.GetResponseStream()
    $soapReader = [System.IO.StreamReader]($responseStream)
    $ReturnXml = [Xml] $soapReader.ReadToEnd()
    $responseStream.Close()

    if ($ReturnXml.Envelope.InnerText -like "*Error*") {
        $editCount--
        Write-Output "Catcher's Response:"
        Write-Error $ReturnXml.Envelope.InnerText
    }
    else {
        Write-Output "Catcher's Response:"
    }

    $Return = @()
    $Return += $ReturnXml.Envelope.InnerText
    return $Return
}

function Send-SOAPRequestFromFile {
    [cmdletbinding()]
    Param(
        [Parameter()]
        [String]
        $SOAPRequestFile,

        [Parameter()]
        [string]
        $URL
    )
    write-host "Reading and converting file to XmlDocument: $SOAPRequestFile"
    $SOAPRequest = [Xml](Get-Content $SOAPRequestFile)

    return $(Execute-SOAPRequest $SOAPRequest $URL)
}

function Split-Object-Metadata {
    <#
	    .SYNOPSIS
	    Parses a CSV of descriptive metadata into tab-d compound-object metadata files, in directory structure format. Object-level metadata only.
	    .DESCRIPTION
	    Metadata headers are trimmed; if necessary, File Name field is added/moved to final column; metadata fields are trimmed; and each row of object metadata is exported as tab-d text file in the directory specified on the metadata csv. If the directory doesn't exist, it will be created.
	    .PARAMETER path
        The path to the root directory for creating a batch of objects.
        .PARAMETER metadata
        The filename for a csv of object-level descriptive metadata. The first column should called Directory and include the name of the subdirectory for that object. (DEFAULT VALUE: metadata.csv)
	    .EXAMPLE
	    Split-Object-Metadata -path E:\pstsc_01822\2018-02 -metadata metadata.csv
	    .INPUTS
        System.String
        .NOTES
        This function does not return any bitstreams or data, the changes takeplace within the specified path on the filesystem.
	#>
    [cmdletbinding()]
    Param(
        [Parameter()]
        [string]
        $path,

        [Parameter()]
        [string]
        $metadata = "metadata.csv"
    )
    Write-Verbose "$(. Get-TimeStamp) Split-Object-Metadata starting"
    # Trim spaces from the headers
    Write-Verbose "Trim spaces from headers in metadata.csv"
    $SourceHeadersDirty = Get-Content -Path $path\$metadata -First 2 | ConvertFrom-Csv
    $SourceHeadersCleaned = $SourceHeadersDirty.PSObject.Properties.Name.Trim()

    <#     # Add the File Name field at the end if it wasn't included in the original metadata
    Write-Verbose "Add column for File Name, if necessary."
    if ("File Name" -notin $SourceHeadersCleaned) {
        $tmpcsv = Import-CSV -Path $path\$metadata | Select-Object *, "File Name" | ConvertFrom-Csv
    } #>

    # Import the metadata csv using the appropriate headers
    Write-verbose "Import metadata using trimmed headers"
    if ($null -ne $tmpCSV) {
        $SourceHeadersDirty = Get-Content -Path $tmpCSV -First 2 | ConvertFrom-Csv
        $SourceHeadersCleaned = $SourceHeadersDirty.PSObject.Properties.Name.Trim()
        $csv = Import-CSV $tmpCSV -Header $SourceHeadersCleaned | Select-Object -Skip 1
    }
    else {
        $csv = Import-CSV -Path $path\$metadata -Header $SourceHeadersCleaned | Select-Object -Skip 1
    }

    # Trim all the fields
    Write-Verbose "Trim all the metadata fields."
    $csv | Foreach-Object {
        foreach ($property in $_.PSObject.Properties) {
            $property.value = $property.value.trim()
        }
    }

    # Export tab-d compound object metadata files, with object-level metadata.
    # Strip Directory and Level columns if present.
    # If File Name was included in the original metadata, make sure it's the last field.
    Write-Verbose "Export tab-d compound-object metadata file, with object-level metadata. Strip out processing information (Directory, Level) and make sure File Name is the last column."
    $objects = $csv | Group-Object -AsHashTable -AsString -Property Directory
    ForEach ($object in $objects.keys) {
        if (!(Test-Path $path\$object)) { New-Item -ItemType Directory -Path $path\$object | Out-Null }
        $objects.$object | Select-Object * -ExcludeProperty "File Name" | Select-Object *, "File Name" -ExcludeProperty Directory, Level | Export-Csv -Delimiter "`t" -Path $path\$object\$object.txt -NoTypeInformation
    }
    Write-Verbose "$(. Get-TimeStamp) Split-Object-Metadata complete"
}

function Convert-Item-Metadata {
    <#
	    .SYNOPSIS
	    Derive item-level metadata for a tab-d compound-object metadata file.
	    .DESCRIPTION
        The object directory is scanned for JP2 files; for each one, a row is added to the object's tab-d compound-object metadata file with a generic title (e.g. Item 2 of 98) and JP2 file name.
	    .PARAMETER path
        The path to the root directory for batch of objects.
        .PARAMETER object
        The name of the object subdirectory in the batch of objects, usually the object identifier.
	    .EXAMPLE
	    Convert-Item-Metadata -path E:\pstsc_01822\2018-02 -object pstsc_01822_9331bb5ca9fa6863f7e1273c41738f44
	    .INPUTS
	    System.String
        .NOTES
        This function does not return any bitstreams or data, the changes takeplace within the specified path on the filesystem.
	#>
    [cmdletbinding()]
    Param(
        [Parameter()]
        [string]
        $path,

        [Parameter()]
        [string]
        $object
    )
    Write-Verbose "$(. Get-TimeStamp) Convert-Item-Metadata starting for $object"
    Write-Verbose "For every JP2 in the object directory, append derived item-level metadata to the tab-d compound-object metadata file."
    $f = 1
    $jp2s = (Get-ChildItem -Path $path\$object *.jp2 -Recurse).count

    if ($jp2s -eq 0) { Write-Warning "No JP2 files. Item metadata is derived from JP2 files, cannot be derived." }

    Get-ChildItem -Path $path\$object *.jp2 -Recurse | ForEach-Object {
        $objcsv = Import-Csv -Delimiter "`t" -Path $path\$object\$object.txt
        $row = @()
        $row += ('"Item ' + $f + ' of ' + $jp2s + '"')
        foreach ($field in ($objcsv | Select-Object * -ExcludeProperty Title, "File Name" | Get-Member -type NoteProperty)) { $row += ('""') }
        $row += ("$($_.BaseName).jp2")
        $item = $row -join "`t"
        Write-Output $item | Out-File $path\$object\$object.txt -Append -Encoding UTF8
        $f++
    }
    Write-Verbose "$(. Get-TimeStamp) Convert-Item-Metadata complete for $object"
}

function Optimize-OCR {
    <#
	    .SYNOPSIS
	    Optimized OCR for CONTENTdm indexing.
	    .DESCRIPTION
        Strip out most non-alphanumeric characters. Retain a small selection of punction marks (a-zA-Z0-9_.,!?$%#@/\s) and line breaks. Remove extra line breaks.
	    .PARAMETER ocrText
        The filepath to or variable for a string of OCR output.
	    .EXAMPLE
	    Optimize-OCR -ocrText E:\pstsc_01822\2018-02\pstsc_01822_9331bb5ca9fa6863f7e1273c41738f44\transcripts\pstsc_01822_9331bb5ca9fa6863f7e1273c41738f44_0195.txt
	    .INPUTS
	    System.String
	    .OUTPUTS
        System.String
	#>
    [cmdletbinding()]
    Param(
        [Parameter()]
        [string]
        $ocrText
    )
    Write-Verbose "$(. Get-TimeStamp) Optimize-OCR starting"
    (Get-Content $ocrText) | ForEach-Object {
        $_ -replace '[^a-zA-Z0-9_.,!?$%#@/\s]' `
            -replace '[\u009D]' `
            -replace '[\u000C]'
    } | Where-Object { $_.trim() -ne "" } | Set-Content $ocrText
    Return $ocrText
    Write-Verbose "$(. Get-TimeStamp) Optimize-OCR complete"
}

function Get-Text-From-PDF {
    <#
	    .SYNOPSIS
	    Extract text from a searchable PDF into per-page transcript files for CONTENTdm.
	    .DESCRIPTION
        Burst an object PDF into separate pages using pdftk, move the object PDF into a temporary holding subdirectory, move the page PDFs into the transcripts subdirectory and user xpdf (pdf2text) to extract the text into a TXT file. Delete the PDF, rename the TXT files to match the JP2s in sequence and optimize them for CONTENTdm indexing. Move the object PDF back to the object directory and cleanup temp files.
	    .PARAMETER path
        The path to the root directory for a batch of objects.
        .PARAMETER object
        The name of the object subdirectory in the batch of objects, usually the object identifier.
        .PARAMETER log
        The filepath or variable of a log to send console output.
        .EXAMPLE
	    Get-Text-From-PDF -path E:\pstsc_01822\2018-02 -object pstsc_01822_9331bb5ca9fa6863f7e1273c41738f44 -log $log_batchCreate
	    .INPUTS
	    System.String
        .NOTES
        This function does not return any bitstreams or data, the changes takeplace within the specified path on the filesystem.
	#>
    [cmdletbinding()]
    Param(
        [Parameter()]
        [string]
        $path,

        [Parameter()]
        [string]
        $object,

        [Parameter()]
        [string]
        $log,

        [Parameter()]
        [string]
        $pdftk,

        [Parameter()]
        [string]
        $pdf2text
    )
    Write-Verbose "$(. Get-TimeStamp) Get-Text-From-PDF starting for $object"
    # split object PDFs and move complete PDF to tmp directory
    if (!(Test-Path $path\$object\transcripts)) { New-Item -ItemType Directory -Path $path\$object\transcripts | Out-Null }
    Write-Verbose "Split the object PDF into item PDFs using pdftk"
    Invoke-Expression "$pdftk $path\$object\$object.pdf burst output $path\$object\$object-%02d.pdf" -ErrorAction SilentlyContinue | Tee-Object -file $log -Append
    Remove-Item $path\$object\doc_data.txt | Tee-Object -file $log -Append
    if (!(Test-Path $path\$object\tmp)) { New-Item -ItemType Directory -Path $path\$object\tmp | Out-Null }
    Write-Verbose "Move the object PDF to a tmp directory"
    Move-Item $path\$object\$object.pdf -Destination $path\$object\tmp | Tee-Object -file $log -Append

    # Move PDFs to transcripts directory because we won't be able to distinguish metadata from text otherwise
    Write-Verbose "Move the item PDFs to the transcripts subdirectory"
    if (!(Test-Path $path\$object\transcripts)) { New-Item -ItemType Directory -Path $path\$object\transcripts | Out-Null }
    Get-ChildItem -Path $path\$object *.pdf | ForEach-Object { Move-Item $path\$object\$_ -Destination $path\$object\transcripts | Tee-Object -file $log -Append }

    # Extract text and delete item PDF
    Write-Verbose "Extract the text from each item PDF with xpdf and delete the item PDFs."
    Get-ChildItem -Path $path\$object\transcripts *.pdf | ForEach-Object {
        Invoke-Expression "$pdf2text -raw -nopgbrk $path\$object\transcripts\$_" -ErrorAction SilentlyContinue | Tee-Object -file $log -Append
        Remove-Item $path\$object\transcripts\$_ | Tee-Object -file $log -Append
    }

    # Optimize TXT and rename to match JP2
    Write-Verbose "Rename TXT transcripts to match corresponding JP2 file."
    $jp2Files = @(Get-ChildItem *.jp2 -Path $path\$object\scans -Name | Sort-Object)
    $txtFiles = @(Get-ChildItem *.txt -Path $path\$object\transcripts -Name | Sort-Object)

    Write-Verbose "Optimize the OCR for CONTENTdm indexing."
    $i = 0
    Get-ChildItem *.txt -Path $path\$object\transcripts -Name | Sort-Object | ForEach-Object {
        . Optimize-OCR -ocrText $path\$object\transcripts\$_ 2>&1 | Out-Null # Tee-Object -file $log -Append
        $name = $jp2Files[$i]
        $name = $name.Substring(0, $name.Length - 4)
        $name = "$name.txt"
        $txt = $txtFiles[$i]
        if (!(Test-Path $path\$object\transcripts\$name)) {
            Rename-Item -Path $path\$object\transcripts\$txt -NewName $name | Tee-Object -file $log -Append
        }
        $i++
    }

    # Move the complete PDF back in to the object directory and delete the tmp directory.
    Write-Verbose "Move the object PDF back into the object directory and delete the temp directory."
    Move-Item $path\$object\tmp\$object.pdf -Destination $path\$object | Tee-Object -file $log -Append
    Remove-Item -Recurse $path\$object\tmp | Tee-Object -file $log -Append
    Write-Verbose "$(. Get-TimeStamp) Get-Text-From-PDF complete for $object"
}

function Merge-PDF {
    <#
	    .SYNOPSIS
	    Concatenate multiple PDFs pages into a single PDF.
	    .DESCRIPTION
        Create a list of item PDF files, use GhostScript to merge them into a 200 PPI object PDF, and delete the original PDFs.
	    .PARAMETER path
        The path to the root directory for a batch of objects.
        .PARAMETER object
        The name of the object subdirectory in the batch of objects, usually the object identifier.
        .PARAMETER pdfs
        The name of a subdirectory with item-level PDF files to merge into a single object-level PDF. (DEFAULT VALUE: transcripts)
        .PARAMETER log
        The filepath or variable of a log to send console output.
        .EXAMPLE
	    Merge-PDF -path $path -object $object -pdfs transcripts -log $log_batchCreate
	    .INPUTS
	    System.String
        .NOTES
        This function does not return any bitstreams or data, the changes takeplace within the specified path on the filesystem.
	#>
    [cmdletbinding()]
    Param(
        [Parameter()]
        [string]
        $path,

        [Parameter()]
        [string]
        $object,

        [Parameter()]
        [string]
        $pdfs = "transcripts",

        [Parameter()]
        [string]
        $log,

        [Parameter()]
        [string]
        $gs
    )
    Write-Verbose "$(. Get-TimeStamp) Merge-PDF starting for $object"
    Write-Verbose "Generate a list of PDF files from the pdfs subdirectory to merge"
    $list = (Get-ChildItem -Path $path\$object\$pdfs *.pdf).FullName
    $list > "$path\$object\list.txt"
    $list = "$path\$object\list.txt"
    $outfile = "'$path\$object\$object.pdf'"
    Write-Verbose "Merge PDFs using GhostScript, creating 200 PPI pdf in the object directory"
    Invoke-Expression "$gs -sDEVICE=pdfwrite -dQUIET -dBATCH -dSAFER -dNOPAUSE -dFastWebView -dCompatibilityLevel='1.5' -dDownsampleColorImages='true' -dColorImageDownsampleType=/Bicubic -dColorImageResolution='200' -dDownsampleGrayImages='true' -dGrayImageDownsampleType=/Bicubic -dGrayImageResolution='200' -dDownsampleMonoImages='true' -sOUTPUTFILE=$outfile $(get-content "$list")" -ErrorAction SilentlyContinue  *>> $null
    Write-Verbose "Delete the list and individual PDFs"
    $files = $(get-content "$list")
    ForEach ($file in $files) { Remove-Item $file 2>&1 | Tee-Object -file $log -Append }
    Remove-Item $list 2>&1 | Tee-Object -file $log -Append
    Write-Verbose "$(. Get-TimeStamp) Merge-PDF complete for $object"
}

function Merge-PDF-PDFTK {
    #UNTESTED
    [cmdletbinding()]
    Param(
        [Parameter()]
        [string]
        $path,

        [Parameter()]
        [string]
        $object,

        [Parameter()]
        [string]
        $log,

        [Parameter()]
        [string]
        $pdftk
    )
    Write-Verbose "$(. Get-TimeStamp) Merge-PDF-PDFTK starting for $object"
    # $pdftk *.pdf cat output file.pdf
    Write-Verbose "Generate a list of PDF files from the transcripts subdirectory and merge them using pdftk."
    $list = (Get-ChildItem -Path $path\$object\transcripts *.pdf).FullName
    Invoke-Expression "$pdftk $list cat output $path\$object.pdf" | Tee-Object -file $log -Append
    # need to delete the individual pages...
    Write-Verbose "$(. Get-TimeStamp) Merge-PDF-PDFTK complete for $object"
}
function Get-Images-List {
    <#
	    .SYNOPSIS
	    Using the CONTENTdm API, generate a list of dmrecord numbers for items with images in a collection.
	    .DESCRIPTION
        Make a dmquery API call for the collection; pull out the null-item records; traverse compound objects to find image items; find other image items.
	    .PARAMETER server
        The URL for the Admin UI for a CONTENTdm instance.
        .PARAMETER collection
        The collection alias for a CONTENTdm collection.
        .PARAMETER nonImages
        A variable that is to track items without image files.
        .PARAMETER pages2ocr
        A hashtable containing the dmrecord and CONTENTdm filename for an image.
        .PARAMETER path
        The path to a staging directory.
        .PARAMETER log
        The filepath or variable of a log to send console output.
        .EXAMPLE
	     Get-Images-List -server https://server17287.contentdm.oclc.org -collection benson -nonImages $nonImages -pages2ocr $pages2ocr -path E:\benson
	    .INPUTS
        System.String
        System.Integer
        System.Hashtable
        .NOTES
        This function does not return any bitstreams or data, the changes takeplace within the specified path on the filesystem.
	#>
    [cmdletbinding()]
    Param(
        [Parameter()]
        [string]
        $server,

        [Parameter()]
        [string]
        $collection,

        [Parameter()]
        [string]
        $path,

        [Parameter()]
        [string]
        $log
    )
    Write-Verbose "$(. Get-TimeStamp) Get-Images-List starting for $collection"
    Write-Verbose "Make call to CONTENTdm API for collection records."
    $hits = Invoke-RestMethod "$server/dmwebservices/index.php?q=dmQuery/$collection/0/dmrecord!find/nosort/1024/1/0/0/0/0/1/0/json"
    # Need to deal with pager/pagination of results, maxes at 1024?
    $records = $hits.records

    $items = @()
    $nonImages = 0

    Write-Verbose "For each record, derive image or nonimage."
    foreach ($record in $records) {
        if ($record.filetype -eq "cpd") {
            $pointer = $record.pointer
            $pages = Invoke-RestMethod "$server/dmwebservices/index.php?q=dmGetCompoundObjectInfo/$collection/$pointer/json"
            foreach ($object in $pages) {
                # Need to use an extenernal call to a self-recursive function that finds all the pages within any nodes. Have a placeholder started with Get-Object-Pages.
                if ($object.type -eq "Monograph") {
                    #this seems like it could miss pages at other node levels? Do i need to add lots of ifs here or something to traverse?
                    $pages = $object.node.node.page
                    foreach ($page in $pages) {
                        $items += [PSCustomObject]@{
                            dmrecord = $page.pageptr
                            type     = "Item"
                            # media = $record.filetype
                        }
                    }
                }
                else {
                    $pages = $object.page
                    foreach ($page in $pages) {
                        $items += [PSCustomObject]@{
                            dmrecord = $page.pageptr
                            type     = "Item"
                            # media = $record.filetype
                        }
                    }
                }
            }
        }
        elseif (($record.filetype -eq "jp2")) {
            $items += [PSCustomObject]@{
                dmrecord = $record.pointer
                type     = "Item"
                media    = $record.filetype
            }
        }
        else {
            $nonImages++
            <#             $items += [PSCustomObject]@{
                dmrecord = $record.pointer
                type = "unknown"
                media = $record.filetype
            } #>
        }
    }
    $items | Export-Csv $path\items.csv -NoTypeInformation
    return $nonImages
    Write-Verbose "$(. Get-TimeStamp) Get-Images-List complete for $collection"
}

function Get-Object-Pages {
    # INCOMPLETE
    Param(
        [Parameter()]
        [string]
        $server,

        [Parameter()]
        [string]
        $collection,

        [Parameter()]
        [string]
        $dmrecord
    )
    $pointer = $dmrecord
    $pages = Invoke-RestMethod "$server/dmwebservices/index.php?q=dmGetCompoundObjectInfo/$collection/$pointer/json"
    foreach ($node in $pages.node) {

    }
}


function Convert-to-Text-And-PDF-ABBYY {
    <#
	    .SYNOPSIS
	    Convert TIF to TXT and PDF using ABBYY Recognition Server. Destroys original TIFs.
	    .DESCRIPTION
        Parallel copy object TIFs to ABBYY server, via a staging folder. When there is one TXT file and one PDF file for every TIF file in a transcripts subdirectory within the object directory, merge the PDFs into a single object PDF using pdftk and move it into root of the object directory.
	    .PARAMETER path
        The path to the root directory for a batch of objects.
        .PARAMETER object
        The name of the object subdirectory in the batch of objects, usually the object identifier.
        .PARAMETER throttle
        Integer for the number of CPU processes when copying TIFs to the ABBYY server.
        .PARAMETER log
        The filepath or variable of a log to send console output.
        .EXAMPLE

	    .INPUTS
	    System.String
        .NOTES
        This function does not return any bitstreams or data, the changes takeplace within the specified path on the filesystem. Assumes filepaths of Penn State University Libraries for ABBYY Recogntion Server.
	#>
    [cmdletbinding()]
    Param(
        [Parameter()]
        [string]
        $path,

        [Parameter()]
        [string]
        $object,

        [Parameter()]
        [string]
        $throttle,

        [Parameter()]
        [string]
        $log,

        [Parameter()]
        [string]
        $pdftk
    )
    Write-Verbose "$(. Get-TimeStamp) Convert-to-Text-And-PDF-ABBYY starting for $object"
    $abbyy_staging = O:\pcd\cho-cdm\staging
    $abbyy_both_in = O:\pcd\cho-cdm\input
    $abbyy_both_out = O:\pcd\cho-cdm\output
    $tifs = (Get-ChildItem *.tif* -Path $path\$object -Recurse).count
    $txts = (Get-ChildItem *.txt -Path $abbyy_text_out\$object -Recurse).count
    New-Item -ItemType Directory -Path $abbyy_staging\$object | Out-Null
    . Copy-Tif -path $path -object $object -throttle $throttle -abbyy_staging $abbyy_staging -log $log 2>&1 | Tee-Object -file $log -Append
    Write-Verbose "Move copy of object TIFs from ABBYY staging to ABBYY in directory."
    Move-Item $abbyy_staging\$object $abbyy_both_in 2>&1 | Tee-Object -file $log -Append
    Write-Verbose "Sleep script until there is in TXT for every TIF"
    while ($tifs -ne $txts) { Start-Sleep -Seconds 15 }
    Get-ChildItem * -Path $abbyy_both_out\$object | ForEach-Object {
        Move-Item -Path $_ -Destination $path\$object\transcripts  2>&1 | Tee-Object -file $log -Append
    }
    . Merge-PDF-PDFTK -path $path -object $object -log $log -pdftk $pdftk 2>&1 | Tee-Object -file $log -Append
    Write-Verbose "Move object PDF from transcripts subdirectory to object directory."
    Move-Item $path\$object\transcripts\$object.pdf $path\$object\$object.pdf 2>&1 | Tee-Object -file $log -Append
    Write-Verbose "Delete the object directory in ABBYY out directory."
    Remove-Item $abbyy_both_out\$object 2>&1 | Tee-Object -file $log -Append
    Write-Verbose "$(. Get-TimeStamp) Convert-to-Text-And-PDF-ABBYY complete for $object"
}

function Convert-to-Text-ABBYY {
    <#
	    .SYNOPSIS
	    Convert TIF to TXT using ABBYY Recognition Server. Destroys original TIFs.
	    .DESCRIPTION
        Parallel copy object TIFs to ABBYY server, via a staging folder. When there is one TXT file for every TIF file, move them back to the object directory in a transcripts subdirectory.
	    .PARAMETER path
        The path to the root directory for a batch of objects.
        .PARAMETER object
        The name of the object subdirectory in the batch of objects, usually the object identifier.
        .PARAMETER throttle
        Integer for the number of CPU processes when copying TIFs to the ABBYY server.
        .PARAMETER log
        The filepath or variable of a log to send console output.
        .EXAMPLE

	    .INPUTS
        System.String
        System.Integer
        .NOTES
        This function does not return any bitstreams or data, the changes takeplace within the specified path on the filesystem. Assumes filepaths of Penn State University Libraries for ABBYY Recogntion Server.
	#>
    [cmdletbinding()]
    Param(
        [Parameter()]
        [string]
        $path,

        [Parameter()]
        [string]
        $object,

        [Parameter()]
        [string]
        $throttle,

        [Parameter()]
        [string]
        $log
    )
    Write-Verbose "$(. Get-TimeStamp) Convert-to-Text-ABBYY starting for $object"
    $abbyy_staging = O:\pcd\text\staging
    $abbyy_text_in = O:\pcd\text\input
    $abbyy_text_out = O:\pcd\text\output
    $tifs = (Get-ChildItem *.tif* -Path $path\$object -Recurse).count
    $txts = (Get-ChildItem *.txt -Path $abbyy_text_out\$object -Recurse).count
    New-Item -ItemType Directory -Path $abbyy_staging\$object | Out-Null
    . Copy-TIF-ABBYY -path $path -object $object -throttle $throttle -abbyy_staging $abbyy_staging -log $log 2>&1 | Tee-Object -file $log -Append
    Write-Verbose "Move copy of object TIFs from ABBYY staging to ABBYY in directory."
    Move-Item -Path $abbyy_staging\$object -Destination $abbyy_text_in 2>&1 | Tee-Object -file $log -Append
    Write-Verbose "Sleep script until there is in TXT for every TIF"
    while ($tifs -ne $txts) { Start-Sleep -Seconds 15 }
    Get-ChildItem *.txt -Path $abbyy_text_out\$object | ForEach-Object {
        Move-Item -Path $_ -Destination $path\$object\transcripts  2>&1 | Tee-Object -file $log -Append
    }
    Write-Verbose "Delete the object directory in ABBYY out directory."
    Remove-Item $abbyy_text_out\$object 2>&1 | Tee-Object -file $log -Append
    Write-Verbose "$(. Get-TimeStamp) Convert-to-Text-ABBYY complete for $object"
}

function Convert-to-PDF-ABBYY {
    <#
	    .SYNOPSIS
	    Convert TIF to PDF using ABBYY Recognition Server. Destroys original TIFs.
	    .DESCRIPTION
        Parallel copy object TIFs to ABBYY server, via a staging folder. When a PDF file for the object exists on the ABBYY server, move it to the object directory and remove the plain text object-level transcript from ABBYY.
	    .PARAMETER path
        The path to the root directory for a batch of objects.
        .PARAMETER object
        The name of the object subdirectory in the batch of objects, usually the object identifier.
        .PARAMETER throttle
        Integer for the number of CPU processes when copying TIFs to the ABBYY server.
        .PARAMETER log
        The filepath or variable of a log to send console output.
        .EXAMPLE

	    .INPUTS
        System.String
        System.Integer
        .NOTES
        This function does not return any bitstreams or data, the changes takeplace within the specified path on the filesystem. Assumes filepaths of Penn State University Libraries for ABBYY Recogntion Server.
	#>
    [cmdletbinding()]
    Param(
        [Parameter()]
        [string]
        $path,

        [Parameter()]
        [string]
        $object,

        [Parameter()]
        [int16]
        $throttle,

        [Parameter()]
        [string]
        $log
    )
    Write-Verbose "$(. Get-TimeStamp) Convert-to-PDF-ABBYY starting for $object"
    $abbyy_staging = O:\pcd\many2pdf-high\staging
    $abbyy_pdf_in = O:\pcd\many2pdf-high\input
    $abbyy_pdf_out = O:\pcd\many2pdf-high\output
    $pdf = ($abbyy_pdf_out + "\" + $object + ".pdf")
    $txt = ($abbyy_pdf_out + "\" + $object + ".txt")
    New-Item -ItemType Directory -Path $abbyy_staging\$object | Out-Null
    . Copy-TIF-ABBYY -path $path -object $object -throttle $throttle -abbyy_staging $abbyy_staging -log $log 2>&1 | Tee-Object -file $log -Append
    Write-Verbose "Move copy of object TIFs from ABBYY staging to ABBYY in directory."
    Move-Item $abbyy_staging\$object $abbyy_pdf_in 2>&1 | Tee-Object -file $log -Append
    while (!(Test-Path $pdf)) {
        Start-Sleep 10
    }
    Write-Verbose "Move object PDF from ABBYY in directory to object directory and cleanup ABBYY in."
    Move-Item $pdf $path\$object 2>&1 | Tee-Object -file $log -Append
    Remove-Item $txt 2>&1 | Tee-Object -file $log -Append
    Write-Verbose "$(. Get-TimeStamp) Convert-to-PDF-ABBYY complete for $object"
}

function Get-Images-Using-API {
    <#
	    .SYNOPSIS
	    Parallel download JPG images from a CONTENTdm collection using the API.
	    .DESCRIPTION
        Using a list generated by Get-Images-List, query CONTENTdm API for properties of images from collection items. Use that information to parallel download JPG images.
        .PARAMETER path
        The path to a staging directory.
	    .PARAMETER server
        The URL for the Admin UI for a CONTENTdm instance.
        .PARAMETER collection
        The collection alias for a CONTENTdm collection.
        .PARAMETER public
        The URL for the Public UI for a CONTENTdm instance.
        .PARAMETER throttle
        Integer for the number of CPU processes when copying TIFs to the ABBYY server.
        .PARAMETER log
        The filepath or variable of a log to send console output.
        .EXAMPLE
        Get-Images-Using-API -path E:\ -server https://server17287.contentdm.oclc.org -collection benson -public https://digital.libraries.psu.edu -throttle 8 -log $log_batchOCR
	    .INPUTS
        System.String
        System.Integer
        .NOTES
        This function does not return any bitstreams or data, the changes takeplace within the specified path on the filesystem.
	#>
    [cmdletbinding()]
    Param(
        [Parameter()]
        [string]
        $path,

        [Parameter()]
        [string]
        $server,

        [Parameter()]
        [string]
        $collection,

        [Parameter()]
        [string]
        $public,

        [Parameter()]
        [int16]
        $throttle
    )

    Write-Verbose "$(. Get-TimeStamp) Get-Images-Using-API starting for $collection"
    Write-Verbose "Import item CSV and call CONTENTdm API for additional information about the item."

    $items = Import-Csv $path\items.csv
    $total = ($items | Measure-Object).Count

    foreach ($item in $items) {
        $imageInfo = Invoke-RestMethod ($server + "/dmwebservices/index.php?q=dmGetImageInfo/" + $collection + "/" + $item.dmrecord + "/json")
        $item | Add-Member -NotePropertyName id -NotePropertyValue ($collection + "_" + $item.dmrecord)
        $item | Add-Member -NotePropertyName uri -NotePropertyValue ($public + "/utils/ajaxhelper/?CISOROOT=" + $collection + "&CISOPTR=" + $item.dmrecord + "&action=2&DMSCALE=100&DMWIDTH=" + $imageInfo.width + "&DMHEIGHT=" + $imageInfo.height + "&DMX=0&DMY=0")
        $item | Add-Member -NotePropertyName filename -NotePropertyValue ("$path\" + $collection + "_" + $item.dmrecord + ".jpg")
    }

    Write-Verbose "Export item CSV with additional information for each item."
    $items | export-csv $path\items.csv -NoTypeInformation

    $i = 0
    $jobs = @()
    Write-Verbose "For each item, download a JPG image using the CONTENTdm API."
    foreach ($item in $items) {
        $i++
        $uri = $($item.uri)
        $file = $item.filename
        $id = $item.id
        $jobs += Start-Job { Invoke-WebRequest $using:uri -Method Get -OutFile $using:file } -Name $id
        $jobName = $jobs[-1].Name
        Write-Information "@{Job Name=$jobName; CDM ID=$id; action=download}"
        Write-Output "    [Job: $jobName] Download $id ($i of $total)"
        Write-Verbose "Request: Invoke-WebRequest $uri -Method Get -OutFile $file"
    }
    Do {
        $completed = (Get-Job -Name $collection* | Where-Object { $_.State -eq "Completed" }).count
        Write-Progress -Activity "Get Images Using API" -Status "Downloading images..." -PercentComplete ($completed / $items.count * 100)
        Write-Verbose "$completed/$($items.count) * 100 = $($completed/$items.count * 100)"
    } Until ($completed -eq $items.count)



    Write-Verbose "$(. Get-TimeStamp) Get-Images-Using-API starting for $collection"
}

#IIIF for images. Test different size tifs for smaller and quicker files, eg /full/2000, /0/default.jpg
# Not working as of 2019-08-23, still working on getting URI and ID paired together for downloading...
function Get-Images-Using-IIIF {
    [cmdletbinding()]
    Param(
        [Parameter()]
        [string]
        $public,

        [Parameter()]
        [string]
        $collection,

        [Parameter()]
        [string]
        $path
    )
    $startTime = (Get-Date)
    Write-Verbose "$(Get-TimeStamp) Get-Images-Using-IIIF starting for $collection"
    Write-Verbose "$(Get-TimeStamp) Retrieve collection-level IIIF presentation manifest."
    Write-Output "$(Get-TimeStamp) Reading IIIF presentation manifests for $collection and generating a list of images to download."
    
    $collectionManifest = Invoke-Restmethod $public/iiif/info/$collection/manifest.json
    $objectManifests = $collectionManifest.manifests."@id" # CONTENTdm only generates IIIF manifests for images as of 2019-08-21.
    $uris = @()
    $images = @()

    Write-Verbose "$(Get-TimeStamp) Build an array with dmrecord and uri for each object-level IIIF presentation manifest"
    foreach ($manifest in $objectManifests) {
        $record = Invoke-RestMethod $manifest
        $uri = ($record.sequences.canvases.images.resource."@id")
        $uris += $uri
    }

    Write-Verbose "$(Get-TimeStamp) Traverse each object-level IIIF presentation manifest, find the images, and build an image downoad list object."
    foreach ($uri in $uris) {
        $pattern = [regex] "/(\d*)/"
        $id = $pattern.Matches($uri)[1] -replace '/'
        $file = ("$path\$collection" + "_" + $id + ".jpg")
        $image = @($id, $uri, $file)
        Write-Verbose "$image"
        $images += , $image
    }

    Write-Output "$(Get-TimeStamp) Downloading $($images.count) images for $collection using IIIF Image API from CONTENTdm. All downloads will be queued and script will wait until all downloads have completed before proceeding. Large images and large collections may take a long time to complete."

    $jobs = @()
    $total = $images.Count
    $i=0
    foreach ($image in $images) {
        $i++
        $id = ($collection+"_"+$image[0])
        $jobs += Start-Job { Invoke-RestMethod -Uri $using:image[1] -OutFile $using:image[2] } -Name "$id-iiif"
        $jobName = $jobs[-1].Name
        Write-Information "@{Job Name=$jobName; CDM ID=$id; action=download}"
        Write-Output "$(Get-TimeStamp)`t[Job: $jobName]`tDownload $id ($i of $total)"
        Write-Verbose "$(Get-TimeStamp) Request: Invoke-RestMethod -Uri $($image[1]) -OutFile $($image[2])"
    }
    Do {
        $running = @()
        $completed = (Get-Job -Name "$collection*iiif" | Where-Object { $_.State -eq "Completed" }).count
        $running += Get-Job -Name "$collection*iiif" | Where-Object { $_.State -eq "Running" } | ForEach-Object {$_.Name}
        Write-Progress -Activity "Get Images Using IIIF" -Status "Downloading images for $collection..." -PercentComplete (($completed/$images.count) * 100)
        Write-Debug "$(Get-TimeStamp) $completed/$($images.count) = $(($completed/$images.count)*100)"
        Write-Verbose "$(Get-TimeStamp) Running Jobs: $running"
        Start-Sleep 2
    } Until ($completed -eq $images.count)

    $endTime = (Get-Date)
    Write-Verbose "$(Get-TimeStamp) Get-Images-Using-IIIF complete for $collection (runtime of $(New-TimeSpan -Start $startTime -End $endTime))"
}

# Workflows require Powershell 5.1, i.e. Windows...
# When PowerShell 7 is released, ForEach-Object will have -Parallel and -ThrottleLimit parameters, can convert these to functions. https://devblogs.microsoft.com/powershell/powershell-7-preview-3/#user-content-foreach-object--parallel
Workflow Convert-to-JP2 {
    [cmdletbinding()]
    Param(
        [Parameter()]
        [string]
        $path,

        [Parameter()]
        [string]
        $object,

        [Parameter()]
        [int16]
        $throttle,

        [Parameter()]
        [string]
        $log,

        [Parameter()]
        [string]
        $gm,

        [Parameter()]
        [string]
        $adobe
    )
    Write-Verbose "Convert-to-JP2 starting for $object"
    $files = Get-ChildItem *.tif* -Path $path\$object -Recurse
    $total = (Get-ChildItem *.tif* -Path $path\$object -Recurse).Count
    $i = 0
    foreach -Parallel -Throttle $throttle ($file in $files) {
        $workflow:i++
        Write-Progress -Activity "Batch Create Compound objects" -Status "Converting $file to JP2" -PercentComplete ($i / $total * 100)
        $basefilename = $file.Basename
        $fullfilename = $file.Fullname
        $sourceICC = "$path\$object\source_$basefilename.icc"
        Write-Verbose "Extracting color profile for $basefilename using GraphicsMagick"
        Invoke-Expression "$gm convert $fullfilename $sourceICC" 2>&1 | Tee-Object -file $log -Append
        Write-Verbose "Converting $basefilename to JP2 using souce color profile"
        Write-Debug "$gm convert $fullfilename -profile $sourceICC -intent Absolute -flatten -quality 85 -define jp2:prg=rlcp -define jp2:numrlvls=7 -define jp2:tilewidth=1024 -define jp2:tileheight=1024 -profile $adobe $path\$object\scans\$basefilename.jp2" 2>&1 | Tee-Object -file $log -Append
        Invoke-Expression "$gm convert $fullfilename -profile $sourceICC -intent Absolute -flatten -quality 85 -define jp2:prg=rlcp -define jp2:numrlvls=7 -define jp2:tilewidth=1024 -define jp2:tileheight=1024 -profile $adobe $path\$object\scans\$basefilename.jp2" 2>&1 | Tee-Object -file $log -Append
        Write-Verbose "Delete source color profile"
        Remove-Item $sourceICC
    }
    Write-Verbose "Convert-to-JP2 complete for $object"
}

Workflow Convert-to-Text-And-PDF {
    [cmdletbinding()]
    Param(
        [Parameter()]
        [string]
        $path,

        [Parameter()]
        [string]
        $object,

        [Parameter()]
        [int16]
        $throttle,

        [Parameter()]
        [string]
        $log,

        [Parameter()]
        [string]
        $gm,

        [Parameter()]
        [string]
        $tesseract
    )
    Write-Verbose "Convert-to-Text-And-PDF starting for $object"
    $files = Get-ChildItem -Path $path\$object *.tif* -Recurse
    foreach -Parallel -Throttle $throttle ($file in $files) {
        $basefilename = $file.BaseName
        Write-Verbose "Run Tesseract on $basefilename to generate TXT and PDF"
        Invoke-Expression "$tesseract $path\$object\$file $path\$object\transcripts\$basefilename txt pdf quiet" 2>&1 | Tee-Object -FilePath $log -Append
    }
    Write-Verbose "Convert-to-Text-And-PDF complete for $object"
}

Workflow Convert-to-Text {
    [cmdletbinding()]
    Param(
        [Parameter()]
        [string]
        $path,

        [Parameter()]
        [string]
        $object,

        [Parameter()]
        [int16]
        $throttle,

        [Parameter()]
        [string]
        $log,

        [Parameter()]
        [string]
        $gm,

        [Parameter()]
        [string]
        $tesseract
    )
    Write-Verbose "Convert-to-Text starting for $object"
    $files = Get-ChildItem -Path $path\$object *.tif* -Recurse
    foreach -Parallel -Throttle $throttle ($file in $files) {
        $basefilename = $file.BaseName
        $fullfilename = $file.FullName
        $tmp = ($basefilename + "_ocr.tif")
        $fulltmp = "$path\$object\$tmp"
        Write-Verbose "Copy TIFs to a temporary directory"
        Copy-Item -Path $fullfilename -Destination $path\$object\$tmp
        Write-Verbose "Convert TIF to grayscale TIF for OCR using GraphicsMagick"
        Invoke-Expression "$gm mogrify -format tif -colorspace gray $fulltmp" 2>&1 | Tee-Object -FilePath $log -Append
        Write-Verbose "Convert grayscale TIF to TXT using Tesseract"
        Invoke-Expression "$tesseract $path\$object\$tmp $path\$object\transcripts\$basefilename txt quiet" 2>&1 | Tee-Object -FilePath $log -Append
        Remove-Item "$path\$object\$tmp"
    }
    Write-Verbose "Convert-to-Text complete for $object"
}

Workflow Convert-to-PDF {
    [cmdletbinding()]
    Param(
        [Parameter()]
        [string]
        $path,

        [Parameter()]
        [string]
        $object,

        [Parameter()]
        [int16]
        $throttle,

        [Parameter()]
        [string]
        $log,

        [Parameter()]
        [string]
        $gm,

        [Parameter()]
        [string]
        $tesseract
    )
    Write-Verbose "Convert-to-PDF starting for $object"
    $files = Get-ChildItem -Path $path\$object *.tif* -Recurse
    foreach -Parallel -Throttle $throttle ($file in $files) {
        $basefilename = $file.BaseName
        Write-Verbose "Convert TIFs to PDF using Tesseract"
        Invoke-Expression "$tesseract $path\$object\$file $path\$object\transcripts\$basefilename pdf quiet" -ErrorAction SilentlyContinue
    }
    Write-Verbose "Convert-to-PDF complete for $object"
}


Workflow Copy-TIF-ABBYY {
    [cmdletbinding()]
    Param(
        [Parameter()]
        [string]
        $path,

        [Parameter()]
        [string]
        $object,

        [Parameter()]
        [int16]
        $throttle,

        [Parameter()]
        [string]
        $log,

        [Parameter()]
        [string]
        $abbyy_staging
    )
    Write-Verbose "Copy-TIF-ABBYY starting for $object"
    $files = Get-ChildItem *.tif* -Path $path\$object -Recurse
    Write-Verbose "Parallel copy TIFs to ABBYY staging."
    foreach -Parallel -Throttle $throttle ($file in $files) {
        Copy-Item -Path $file.FullName -Destination $abbyy_staging\$object  2>&1 | Tee-Object -file $log -Append
    }
    Write-Verbose "Copy-TIF-ABBYY complete for $object"
}



Workflow Update-OCR {

    [cmdletbinding()]
    Param(
        [Parameter()]
        [string]
        $path,

        [Parameter()]
        [int16]
        $throttle,

        [Parameter()]
        [string]
        $collection,

        [Parameter()]
        [string]
        $field,

        [Parameter()]
        [string]
        $gm,

        [Parameter()]
        [string]
        $tesseract,

        [Parameter()]
        $ocrCount,

        [Parameter()]
        $nonText
    )
    Write-Verbose "$(Get-Date -Format u) Update-OCR starting."
    Write-Verbose "$(Get-Date -Format u) Import list of dmrecord numbers for items with images for the collection."

    $items = Import-Csv $path\items.csv
    $total = ($items | Measure-Object).Count
    $csv = @()
    $ocrCount = 0
    $nonText = 0

    Write-Verbose "$(Get-Date -Format u) $total Images to process. Starting parallel loop with throttle set to $throttle."

    $i = 0
    $l = 0
    foreach -Parallel -Throttle $throttle ($item in $items) {
        $id = $item.id
        $workflow:i++
        InlineScript {
            Write-Progress -Activity "Update OCR" -Status "Processing $using:id" -PercentComplete ($using:l / $using:total * 100)
            Write-Verbose "$(Get-Date -Format o) OCR starting for $using:id. ($using:i of $using:total)"
            $imageFile = $using:item.filename
            if ((Test-Path "$imageFile") -and ((Get-Item $imageFile).Length -gt 0kb)) {
                Write-Verbose "$(Get-Date -Format o) Converting $imageFile to grayscale TIF for OCR."
                Invoke-Expression "$using:gm mogrify -format tif -colorspace gray $imageFile"
            }
            $imageFile = ($using:path + "\" + $using:id + ".tif")
            $imageBase = ($using:path + "\" + $using:id)
            if (Test-Path "$imageFile") {
                Write-Verbose "$(Get-Date -Format o) Running OCR on $imageFile."
                Write-Verbose "Command: Invoke-Expression $using:tesseract $using:imageFile $using:imageBase txt quiet"
                Invoke-Expression "$using:tesseract $using:imageFile $using:imageBase txt quiet"
            }
            $imageTxt = ($using:path + "\" + $using:id + ".txt")
            if (Test-Path "$imageTxt") {
                Write-Progress -Activity "Update OCR" -Status "Processing $using:id" -PercentComplete ($using:l / $using:total * 100)
                Write-Verbose "$(Get-Date -Format o) Optimizing the OCR for CONTENTdm indexing."
                (Get-Content $imageTxt) | ForEach-Object {
                    $_ -replace '[^a-zA-Z0-9_.,!?$%#@/\s]' `
                        -replace '[\u009D]' `
                        -replace '[\u000C]'
                } | Where-Object { $_.trim() -ne "" } | Set-Variable -Name ocrText
                ($ocrText) -join "`n" | Set-Variable -Name ocrText
                Write-Verbose "$(Get-Date -Format o) Creating an OCR update entry for $imageBase in metadata object to send to CONTENTdm Catcher."
                $csv += [PSCustomObject]@{
                    dmrecord     = $using:item.dmrecord
                    $using:field = $ocrText #$(Get-Content $imageTxt) -join "`n"
                }
                Write-Verbose "$(Get-Date -Format o) Export metadata CSV for use in Batch Edit."
                $csv | Export-CSV $using:path\ocr.csv -Append -NoTypeInformation -Force
            }
        }
        $workflow:l++
        if (Test-Path $($path + "\" + $id + ".txt")) { $ocrCount++ } else { $nonText++ }
        Write-Verbose "$(Get-Date -Format o) OCR complete for $id."
        Write-Progress -Activity "Update OCR" -Status "Processing $id" -PercentComplete ($l / $total * 100)
    }
    Write-Verbose "$(Get-Date -Format o) Update-OCR complete. $ocrCount images with text out of $i images processed."
    return $ocrCount, $nonText
}