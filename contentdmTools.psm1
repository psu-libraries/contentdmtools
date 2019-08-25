# Variables
$tesseract = "$PSScriptRoot\util\tesseract\tesseract.exe"
$gs = "$PSScriptRoot\util\gs\bin\gswin64c.exe"
$gm = "$PSScriptRoot\util\gm\gm.exe"
$adobe = "$PSScriptRoot\util\icc\sRGB_v4.icc"
$pdftk = "$PSScriptRoot\util\pdftk\bin\pdftk.exe"
$pdf2text = "$PSScriptRoot\util\xpdf\pdftotext.exe"

function Get-TimeStamp {
    return "[{0:yyyy-MM-dd} {0:HH:mm:ss}]" -f (Get-Date)
}
function Get-Org-Settings {
    $Return = @{ }
    if (Test-Path settings\org.csv) {
        $orgcsv = $(Resolve-Path settings\org.csv)
        $orgcsv = Import-Csv settings\org.csv
        foreach ($org in $orgcsv) {
            $Return.public = $org.public
            $Return.server = $org.server
            $Return.license = $org.license
            $Module:cdmt_public = $org.public
            $Module:cdmt_server = $org.server
            $Module:cdmt_license = $org.license
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
        [int16]
        $editCount
    )

    write-host "    Sending SOAP Request To Server..."
    $soapWebRequest = [System.Net.WebRequest]::Create($URL)
    $soapWebRequest.ContentType = 'text/xml;charset="utf-8"'
    $soapWebRequest.Accept = "text/xml"
    $soapWebRequest.Method = "POST"

    write-host "    Initiating Send."
    $requestStream = $soapWebRequest.GetRequestStream()
    $SOAPRequest.Save($requestStream)
    $requestStream.Close()

    write-host "    Send Complete, Waiting For Response."
    $resp = $soapWebRequest.GetResponse()
    $responseStream = $resp.GetResponseStream()
    $soapReader = [System.IO.StreamReader]($responseStream)
    $ReturnXml = [Xml] $soapReader.ReadToEnd()
    $responseStream.Close()

    write-host "    Response Received."

    $Return = @()
    $Return.SOAP = $ReturnXml.Envelope.InnerText

    if ($Return -contains "Error") {
        $editCount--
        $Return.count = $editCount
    }

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
    # Trim spaces from the headers
    $SourceHeadersDirty = Get-Content -Path $path\$metadata -First 2 | ConvertFrom-Csv
    $SourceHeadersCleaned = $SourceHeadersDirty.PSObject.Properties.Name.Trim()

    # Add the File Name field at the end if it wasn't included in the original metadata
    if ("File Name" -notin $SourceHeadersCleaned) {
        $tmpcsv = Import-CSV -Path $path\$metadata | Select-Object *, "File Name" | ConvertFrom-Csv -NoTypeInformation
    }

    # Import the metadata csv using the appropriate headers
    if ($null -ne $tmpCSV) {
        $SourceHeadersDirty = Get-Content -Path $tmpCSV -First 2 | ConvertFrom-Csv
        $SourceHeadersCleaned = $SourceHeadersDirty.PSObject.Properties.Name.Trim()
        $csv = Import-CSV $tmpCSV -Header $SourceHeadersCleaned | Select-Object -Skip 1
    }
    else {
        $csv = Import-CSV -Path $path\$metadata -Header $SourceHeadersCleaned | Select-Object -Skip 1
    }

    # Trim all the fields
    $csv | Foreach-Object {
        foreach ($property in $_.PSObject.Properties) {
            $property.value = $property.value.trim()
        }
    }

    # Export tab-d compound object metadata files, with object-level metadata.
    # Strip Directory and Level columns if present.
    # If File Name was included in the original metadata, make sure it's the last field.
    $objects = $csv | Group-Object -AsHashTable -AsString -Property Directory
    ForEach ($object in $objects.keys) {
        if (!(Test-Path $path\$object)) { New-Item -ItemType Directory -Path $path\$object | Out-Null }
        $objects.$object | Select-Object * -ExcludeProperty "File Name" | Select-Object *, "File Name" -ExcludeProperty Directory, Level | Export-Csv -Delimiter "`t" -Path $path\$object\$object.txt -NoTypeInformation
    }
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
    $f = 1
    $jp2s = (Get-ChildItem -Path $path\$object *.jp2 -Recurse).count
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
}

function Convert-Item-Metadata-2 {
    #NOT WORKING
    [cmdletbinding()]
    Param(
        [Parameter()]
        [string]
        $path,

        [Parameter()]
        [string]
        $object
    )
    $f = 1
    $jp2s = (Get-ChildItem -Path $path\$object *.jp2 -Recurse).count
    Get-ChildItem -Path $path\$object *.jp2 -Recurse | ForEach-Object {
        $object_csv = Import-Csv -Delimiter "`t" -Path "$path\$object\$object.txt"
        $item = @{ Title = "Item $f of $jp2s" ; "File Name" = "$_.Name" }
        $object_csv += $item ## $object_csv isn't really a defined object, can't add to it like this.
        $object_csv | Export-Csv "$path\$object\$object.txt" -Delimiter "`t" -NoTypeInformation -Append
        $f++
    }
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
    (Get-Content $ocrText) | ForEach-Object {
        $_ -replace '[^a-zA-Z0-9_.,!?$%#@/\s]' `
            -replace '[\u009D]' `
            -replace '[\u000C]'
    } | Where-Object { $_.trim() -ne "" } | Set-Content $ocrText
    Return $ocrText
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
        $log
    )
    # split object PDFs and move complete PDF to tmp directory
    if (!(Test-Path $path\$object\transcripts)) { New-Item -ItemType Directory -Path $path\$object\transcripts | Out-Null }
    Invoke-Expression "$pdftk $path\$object\$object.pdf burst output $path\$object\$object-%02d.pdf" -ErrorAction SilentlyContinue | Tee-Object -file $log -Append
    Remove-Item $path\$object\doc_data.txt | Tee-Object -file $log -Append
    if (!(Test-Path $path\$object\tmp)) { New-Item -ItemType Directory -Path $path\$object\tmp | Out-Null }
    Move-Item $path\$object\$object.pdf -Destination $path\$object\tmp | Tee-Object -file $log -Append

    # Move PDFs to transcripts directory because we won't be able to distinguish metadata from text otherwise
    if (!(Test-Path $path\$object\transcripts)) { New-Item -ItemType Directory -Path $path\$object\transcripts | Out-Null }
    Get-ChildItem -Path $path\$object *.pdf | ForEach-Object { Move-Item $path\$object\$_ -Destination $path\$object\transcripts | Tee-Object -file $log -Append }

    # Extract text and delete item PDF
    Get-ChildItem -Path $path\$object\transcripts *.pdf | ForEach-Object {
        Invoke-Expression "$pdf2text -raw -nopgbrk $path\$object\transcripts\$_" -ErrorAction SilentlyContinue | Tee-Object -file $log -Append
        Remove-Item $path\$object\transcripts\$_ | Tee-Object -file $log -Append
    }

    # Optimize TXT and rename to match JP2
    $jp2Files = @(Get-ChildItem *.jp2 -Path $path\$object\scans -Name | Sort-Object)
    $txtFiles = @(Get-ChildItem *.txt -Path $path\$object\transcripts -Name | Sort-Object)
    $i = 0
    Get-ChildItem *.txt -Path $path\$object\transcripts -Name | Sort-Object | ForEach-Object {
        . Optimize-OCR -ocrText $path\$object\transcripts\$_ 2>&1 | Tee-Object -file $log -Append
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
    Move-Item $path\$object\tmp\$object.pdf -Destination $path\$object | Tee-Object -file $log -Append
    Remove-Item -Recurse $path\$object\tmp | Tee-Object -file $log -Append
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
        $log
    )
    $list = (Get-ChildItem -Path $path\$object\$pdfs *.pdf).FullName
    $list > "$path\$object\list.txt"
    $list = "$path\$object\list.txt"
    $outfile = "'$path\$object\$object.pdf'"
    Invoke-Expression "$gs -sDEVICE=pdfwrite -dQUIET -dBATCH -dSAFER -dNOPAUSE -dFastWebView -dCompatibilityLevel='1.5' -dDownsampleColorImages='true' -dColorImageDownsampleType=/Bicubic -dColorImageResolution='200' -dDownsampleGrayImages='true' -dGrayImageDownsampleType=/Bicubic -dGrayImageResolution='200' -dDownsampleMonoImages='true' -sOUTPUTFILE=$outfile $(get-content "$list")" -ErrorAction SilentlyContinue  *>> $null
    $files = $(get-content "$list")
    ForEach ($file in $files) { Remove-Item $file 2>&1 | Tee-Object -file $log -Append }
    Remove-Item $list 2>&1 | Tee-Object -file $log -Append
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

    # $pdftk *.pdf cat output file.pdf
    $list = (Get-ChildItem -Path $path\$object\transcripts *.pdf).FullName
    Invoke-Expression "$pdftk $list cat output $path\$object.pdf" | Tee-Object -file $log -Append
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
	     Get-Images-List -server https://server17287.contentdm.oclc.or -collection benson -nonImages $nonImages -pages2ocr $pages2ocr -path E:\benson
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
        [int16]
        $nonImages,

        [Parameter()]
        [hashtable]
        $pages2ocr,

        [Parameter()]
        [string]
        $path,

        [Parameter()]
        [string]
        $log
    )
    $hits = Invoke-RestMethod "$server/dmwebservices/index.php?q=dmQuery/$collection/0/dmrecord!find/nosort/1024/1/0/0/0/0/1/0/json"
    # Need to deal with pager/pagination of results, maxes at 1024?
    $records = $hits.records
    foreach ($record in $records) {
        if ($null -eq $record.find) {
            $nonImages++
        }
        elseif ($record.filetype -eq "cpd") {
            $pointer = $record.pointer
            $objects = Invoke-RestMethod "$server/dmwebservices/index.php?q=dmGetCompoundObjectInfo/$collection/$pointer/json"
            foreach ($object in $objects) {
                if ($object.type -eq "Monograph") {
                    #this seems like it could miss pages at other node levels? Do i need to add lots of ifs here or something to traverse?
                    $pages = $object.node.node.page
                    foreach ($page in $pages) {
                        $pages2ocr.Add($page.pageptr, $page.pagefile)
                    }
                }
                else {
                    $pages = $object.page
                    foreach ($page in $pages) {
                        $pages2ocr.Add($page.pageptr, $page.pagefile)
                    }
                }
            }
        }
        elseif (($record.filetype -eq "jp2") -or ($record.filetype -eq "jpg")) {
            $pages2ocr.Add($record.pointer, $record.find)
        }
        else {
            $nonImages++
        }
    }
    $pages2ocr.GetEnumerator() | Select-Object -Property Name, Value | Export-CSV $path\items.csv -NoTypeInformation
    Get-Content $path\items.csv | Select-Object -Skip 1 | Set-Content $path\items_clean.csv
    return $nonImages
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
        $log
    )

    $abbyy_staging = O:\pcd\cho-cdm\staging
    $abbyy_both_in = O:\pcd\cho-cdm\input
    $abbyy_both_out = O:\pcd\cho-cdm\output
    $tifs = (Get-ChildItem *.tif* -Path $path\$object -Recurse).count
    $txts = (Get-ChildItem *.txt -Path $abbyy_text_out\$object -Recurse).count
    New-Item -ItemType Directory -Path $abbyy_staging\$object | Out-Null
    . Copy-Tif -path $path -object $object -throttle $throttle -abbyy_staging $abbyy_staging -log $log 2>&1 | Tee-Object -file $log -Append
    Move-Item $abbyy_staging\$object $abbyy_both_in 2>&1 | Tee-Object -file $log -Append
    while ($tifs -ne $txts) { Start-Sleep -Seconds 15 }
    Get-ChildItem * -Path $abbyy_both_out\$object | ForEach-Object {
        Move-Item -Path $_ -Destination $path\$object\transcripts  2>&1 | Tee-Object -file $log -Append
    }
    . Merge-PDF-PDFTK -path $path -object $object -log $log 2>&1 | Tee-Object -file $log -Append
    Move-Item $path\$object\transcripts\$object.pdf $path\$object\$object.pdf 2>&1 | Tee-Object -file $log -Append
    Remove-Item $abbyy_both_out\$object 2>&1 | Tee-Object -file $log -Append
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

    $abbyy_staging = O:\pcd\text\staging
    $abbyy_text_in = O:\pcd\text\input
    $abbyy_text_out = O:\pcd\text\output
    $tifs = (Get-ChildItem *.tif* -Path $path\$object -Recurse).count
    $txts = (Get-ChildItem *.txt -Path $abbyy_text_out\$object -Recurse).count
    New-Item -ItemType Directory -Path $abbyy_staging\$object | Out-Null
    . Copy-TIF-ABBYY -path $path -object $object -throttle $throttle -abbyy_staging $abbyy_staging -log $log 2>&1 | Tee-Object -file $log -Append
    Move-Item -Path $abbyy_staging\$object -Destination $abbyy_text_in 2>&1 | Tee-Object -file $log -Append
    while ($tifs -ne $txts) { Start-Sleep -Seconds 15 }
    Get-ChildItem *.txt -Path $abbyy_text_out\$object | ForEach-Object {
        Move-Item -Path $_ -Destination $path\$object\transcripts  2>&1 | Tee-Object -file $log -Append
    }
    Remove-Item $abbyy_text_out\$object 2>&1 | Tee-Object -file $log -Append
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

    $abbyy_staging = O:\pcd\many2pdf-high\staging
    $abbyy_pdf_in = O:\pcd\many2pdf-high\input
    $abbyy_pdf_out = O:\pcd\many2pdf-high\output
    $pdf = ($abbyy_pdf_out + "\" + $object + ".pdf")
    $txt = ($abbyy_pdf_out + "\" + $object + ".txt")

    New-Item -ItemType Directory -Path $abbyy_staging\$object | Out-Null
    . Copy-TIF-ABBYY -path $path -object $object -throttle $throttle -abbyy_staging $abbyy_staging -log $log 2>&1 | Tee-Object -file $log -Append
    Move-Item $abbyy_staging\$object $abbyy_pdf_in 2>&1 | Tee-Object -file $log -Append
    while (!(Test-Path $pdf)) {
        Start-Sleep 10
    }
    Move-Item $pdf $path\$object 2>&1 | Tee-Object -file $log -Append
    Remove-Item $txt 2>&1 | Tee-Object -file $log -Append
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

    $files = Get-ChildItem -Path $path\$object *.tif* -Recurse
    foreach -Parallel -Throttle $throttle ($file in $files) {
        $basefilename = $file.Basename
        $fullfilename = $file.Fullname
        $sourceICC = "$path\$object\source_$basefilename.icc"
        Invoke-Expression "$gm convert $fullfilename $sourceICC" -ErrorAction SilentlyContinue
        Invoke-Expression "$gm convert $fullfilename -profile $sourceICC -intent Absolute -flatten -quality 85 -define jp2:prg=rlcp -define jp2:numrlvls=7 -define jp2:tilewidth=1024 -define jp2:tileheight=1024 -profile $adobe $path\$object\scans\$basefilename.jp2" -ErrorAction SilentlyContinue
        Remove-Item $sourceICC
    }

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

    $files = Get-ChildItem -Path $path\$object *.tif* -Recurse
    foreach -Parallel -Throttle $throttle ($file in $files) {
        $basefilename = $file.BaseName
        Invoke-Expression "$tesseract $path\$object\$file $path\$object\transcripts\$basefilename txt pdf quiet" -ErrorAction SilentlyContinue
        Get-ChildItem -Path $path\$object\transcripts *.txt -Recurse | ForEach-Object {
            . Optimize-OCR -ocrText $_.FullName  2>&1 | Tee-Object -file $log -Append
        }
    }
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
    $files = Get-ChildItem -Path $path\$object *.tif* -Recurse
    foreach -Parallel -Throttle $throttle ($file in $files) {
        $basefilename = $file.BaseName
        $fullfilename = $file.FullName
        $tmp = ($basefilename + "_ocr.tif")
        $fulltmp = "$path\$object\$tmp"
        Copy-Item -Path $fullfilename -Destination $path\$object\$tmp
        Invoke-Expression "$gm mogrify -format tif -colorspace gray $fulltmp" -ErrorAction SilentlyContinue 2>&1 | Tee-Object -FilePath $log -Append
        Invoke-Expression "$tesseract $path\$object\$tmp $path\$object\transcripts\$basefilename txt quiet" -ErrorAction SilentlyContinue
        Get-ChildItem -Path $path\$object\transcripts *.txt -Recurse | ForEach-Object {
            . Optimize-OCR -ocrText $_.FullName  2>&1 | Tee-Object -file $log -Append
        }
        Remove-Item $path\$object\$tmp
    }
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
    $files = Get-ChildItem -Path $path\$object *.tif* -Recurse
    foreach -Parallel -Throttle $throttle ($file in $files) {
        $basefilename = $file.BaseName
        Invoke-Expression "$tesseract $path\$object\$file $path\$object\transcripts\$basefilename pdf quiet" -ErrorAction SilentlyContinue
    }
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

    $files = Get-ChildItem *.tif* -Path $path\$object -Recurse
    foreach -Parallel -Throttle $throttle ($file in $files) {
        Copy-Item -Path $file.FullName -Destination $abbyy_staging\$object  2>&1 | Tee-Object -file $log -Append
    }
}

Workflow Get-Images-Using-API {
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
    $list = @()
    $items = import-csv "$path\items_clean.csv" -Header dmrecord, file
    $total = ($items | Measure-Object).Count
    foreach ($item in $items) {
        $imageInfo = Invoke-RestMethod ($server + "/dmwebservices/index.php?q=dmGetImageInfo/" + $collection + "/" + $item.dmrecord + "/json")
        $url = ($public + "/utils/ajaxhelper/?CISOROOT=" + $collection + "&CISOPTR=" + $item.dmrecord + "&action=2&DMSCALE=100&DMWIDTH=" + $imageInfo.width + "&DMHEIGHT=" + $imageInfo.height + "&DMX=0&DMY=0")
        $id = ($collection + "_" + $item.dmrecord)
        $file = ("$path\" + $id + ".jpg")
        $list += [PSCustomObject]@{
            url  = $url
            file = $file
            id   = $id
        }
    }
    $i = 0
    foreach -Parallel -Throttle $throttle ($row in $list) {
        $WORKFLOW:i++
        Invoke-WebRequest $row.url -Method Get -OutFile $row.file
        Write-Output ("    Downloading " + $row.id + ", $i of $total")
    }
}

#IIIF for images. Test different size tifs for smaller and quicker files, eg /full/2000, /0/default.jpg
# Not working as of 2019-08-23, still working on getting URI and ID paired together for downloading...
Workflow Get-Images-Using-IIIF {
    [cmdletbinding()]
    Param(
        [Parameter()]
        [string]
        $public,

        [Parameter()]
        [string]
        $collection,

        [Parameter()]
        [int16]
        $throttle,

        [Parameter()]
        [string]
        $path
    )
    $collectionManifest = Invoke-Restmethod $public/iiif/info/$collection/manifest.json
    $objectManifests = $collectionManifest.manifests."@id" # CONTENTdm only generates IIIF manifests for images as of 2019-08-21.
    $uris = @()
    foreach ($manifest in $objectManifests) {
        $record = Invoke-RestMethod $manifest
        $uri = ($record.sequences.canvases.images.resource."@id")
        $uris += $uri
    }
    foreach -Parallel -Throttle $throttle ($uri in $uris) {
        $id = $uri | Select-String "\/(\d*)\/full"
        Write-Output $id
        $file = "$path\$collection\$id.jpg"
        Write-Output $file
        #Write-Output $uri #$file
        #Invoke-RestMethod -Uri $uri -OutFile $file
    }

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
        [int16]
        $ocrCount,

        [Parameter()]
        [string]
        $gm,

        [Parameter()]
        [string]
        $tesseract
    )

    $csv = @()
    $items = import-csv "$path\items_clean.csv" -Header dmrecord, file
    $total = ($items | Measure-Object).Count
    foreach -Parallel -Throttle $throttle ($item in $items) {
        $id = ($collection + "_" + $item.dmrecord)
        $imageFile = ("$path\" + $id + ".jpg")
        if ((Test-Path "$imageFile") -and ((Get-Item $imageFile).Length -gt 0kb)) {
            Invoke-Expression "$gm mogrify -format tif -colorspace gray $imageFile" -ErrorAction SilentlyContinue
        }
        $imageFile = ("$path\" + $id + ".tif")
        $imageBase = ("$path\" + $id)
        if (Test-Path "$imageFile") {
            Invoke-Expression "$tesseract $imageFile $imageBase txt quiet" -ErrorAction SilentlyContinue
        }
        $imageTxt = ("$path\" + $id + ".txt")
        if (Test-Path "$imageTxt") {
            Optimize-OCR -ocrText $imageTxt
        }
        if (Test-Path "$imageTxt") {
            $WORKFLOW:csv += [PSCustomObject]@{
                dmrecord = $item.dmrecord
                $field   = $(Get-Content $imageTxt) -join "`n"
            }
        }
        $ocrCount++
        #Can't seem to keep this out of the return...
        #Write-Output "    OCR complete for $imageBase, $ocrCount of $total"

    }
    $csv | Export-CSV $path\ocr.csv -NoTypeInformation
    Return $ocrCount
}