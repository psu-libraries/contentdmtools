# Variables
$tesseract = "$cdmt_root\util\tesseract\tesseract.exe"
$gs = "$cdmt_root\util\gs\bin\gswin64c.exe"
$gm = "$cdmt_root\util\gm\gm.exe"
$adobe = "$cdmt_root\util\icc\sRGB_v4.icc"
$pdftk = "$cdmt_root\util\pdftk\bin\pdftk.exe"
$pdf2text = "$cdmt_root\util\xpdf\pdftotext.exe"
function Get-Org-Settings {
    #$Return = @{}
    if (Test-Path settings\org.csv) {
        $orgcsv = $(Resolve-Path settings\org.csv)
        $orgcsv = Import-Csv settings\org.csv
        foreach ($org in $orgcsv) {
            #$Return.public = $org.public
            #$Return.server = $org.server
            #$Return.license = $org.license
            $Global:cdmt_public = $org.public
            $Global:cdmt_server = $org.server
            $Global:cdmt_license = $org.license
        }
    }
    #Return $Return
}

#SOAP functions # https://ponderingthought.com/2010/01/17/execute-a-soap-request-from-powershell/
function Send-SOAPRequest (
    [Xml] $SOAPRequest,
    [String] $URL,
    $editCount ) {
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

    write-host "Response Received."

    $Return = $ReturnXml.Envelope.InnerText
    return $Return

    if ($Return -contains "Error") {
        $editCount = $editCount - 1
    }
}

function Send-SOAPRequestFromFile (
    [String] $SOAPRequestFile,
    [String] $URL ) {
    write-host "Reading and converting file to XmlDocument: $SOAPRequestFile"
    $SOAPRequest = [Xml](Get-Content $SOAPRequestFile)

    return $(Execute-SOAPRequest $SOAPRequest $URL)
}

function Get-TimeStamp { return "[{0:yyyy-MM-dd} {0:HH:mm:ss}]" -f (Get-Date) }

function Split-Object-Metadata ($path, $metadata) {
    # Trim spaces from the headers
    $SourceHeadersDirty = Get-Content -Path $path\$metadata -First 2 | ConvertFrom-Csv
    $SourceHeadersCleaned = $SourceHeadersDirty.PSObject.Properties.Name.Trim()

    # Add the File Name field at the end if it wasn't included in the original metadata
    if ("File Name" -notin $SourceHeadersCleaned) {
        $tmpCSV = "$path\tmp.csv"
        Import-CSV -Path $path\$metadata | Select-Object *, "File Name" | Export-Csv $tmpCSV -NoTypeInformation
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

    # Delete the temporary CSV file if necessary
    if ($null -ne $tmpCSV) {
        Remove-Item $tmpCSV
    }
}

function Convert-Item-Metadata ($path, $object) {
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

function Optimize-OCR ($ocrText) {
    (Get-Content $ocrText) | ForEach-Object {
        $_ -replace '[^a-zA-Z0-9_.,!?$%#@/\s]' `
            -replace '[\u009D]' `
            -replace '[\u000C]'
    } | Where-Object { $_.trim() -ne "" } | Set-Content $ocrText
}

function Get-Text-From-PDF ($path, $object, $log_batchCreate) {
    # split object PDFs and move complete PDF to tmp directory
    if (!(Test-Path $path\$object\transcripts)) { New-Item -ItemType Directory -Path $path\$object\transcripts | Out-Null }
    Invoke-Expression "$pdftk $path\$object\$object.pdf burst output $path\$object\$object-%02d.pdf" | Tee-Object -file $log_batchCreate -Append
    Remove-Item $path\$object\doc_data.txt | Tee-Object -file $log_batchCreate -Append
    if (!(Test-Path $path\$object\tmp)) { New-Item -ItemType Directory -Path $path\$object\tmp | Out-Null }
    Move-Item $path\$object\$object.pdf -Destination $path\$object\tmp | Tee-Object -file $log_batchCreate -Append

    # Move PDFs to transcripts directory because we won't be able to distinguish metadata from text otherwise
    if (!(Test-Path $path\$object\transcripts)) { New-Item -ItemType Directory -Path $path\$object\transcripts | Out-Null }
    Get-ChildItem -Path $path\$object *.pdf | ForEach-Object { Move-Item $path\$object\$_ -Destination $path\$object\transcripts | Tee-Object -file $log_batchCreate -Append }

    # Extract text and delete item PDF
    Get-ChildItem -Path $path\$object\transcripts *.pdf | ForEach-Object {
        Invoke-Expression "$pdf2text -raw -nopgbrk $path\$object\transcripts\$_" | Tee-Object -file $log_batchCreate -Append
        Remove-Item $path\$object\transcripts\$_ | Tee-Object -file $log_batchCreate -Append
    }

    # Optimize TXT and rename to match JP2
    $jp2Files = @(Get-ChildItem *.jp2 -Path $path\$object\scans -Name | Sort-Object)
    $txtFiles = @(Get-ChildItem *.txt -Path $path\$object\transcripts -Name | Sort-Object)
    $i = 0
    Get-ChildItem *.txt -Path $path\$object\transcripts -Name | Sort-Object | ForEach-Object {
        . Optimize-OCR -ocrText $path\$object\transcripts\$_ 2>&1 | Tee-Object -file $log_batchCreate -Append
        $name = $jp2Files[$i]
        $name = $name.Substring(0, $name.Length - 4)
        $name = "$name.txt"
        $txt = $txtFiles[$i]
        if (!(Test-Path $path\$object\transcripts\$name)) {
            Rename-Item -Path $path\$object\transcripts\$txt -NewName $name | Tee-Object -file $log_batchCreate -Append
        }
        $i++
    }

    # Move the complete PDF back in to the object directory and delete the tmp directory.
    Move-Item $path\$object\tmp\$object.pdf -Destination $path\$object | Tee-Object -file $log_batchCreate -Append
    Remove-Item -Recurse $path\$object\tmp | Tee-Object -file $log_batchCreate -Append
}

function Merge-PDF ($path, $object, $log_batchCreate) {
    $list = (Get-ChildItem -Path $path\$object\transcripts *.pdf).FullName
    $list > "$path\$object\list.txt"
    $list = "$path\$object\list.txt"
    $outfile = "'$path\$object\$object.pdf'"
    Invoke-Expression "$gs -sDEVICE=pdfwrite -dQUIET -dBATCH -dSAFER -dNOPAUSE -dFastWebView -dCompatibilityLevel='1.5' -dDownsampleColorImages='true' -dColorImageDownsampleType=/Bicubic -dColorImageResolution='200' -dDownsampleGrayImages='true' -dGrayImageDownsampleType=/Bicubic -dGrayImageResolution='200' -dDownsampleMonoImages='true' -sOUTPUTFILE=$outfile $(get-content "$list")"  *>> $null
    $files = $(get-content "$list")
    ForEach ($file in $files) { Remove-Item $file 2>&1 | Tee-Object -file $log_batchCreate -Append }
    Remove-Item $list 2>&1 | Tee-Object -file $log_batchCreate -Append
}
function Get-Images-List {
    Param($server, $collection, $nonImages, $pages2ocr, $path)
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
}

# Workflows require Powershell 5.1, i.e. Windows...
# When PowerShell 7 is released, ForEach-Object will have -Parallel and -ThrottleLimit parameters, can convert these to functions. https://devblogs.microsoft.com/powershell/powershell-7-preview-3/#user-content-foreach-object--parallel
Workflow Convert-to-JP2 {
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
        $gm,

        [Parameter()]
        [string]
        $log,

        [Parameter()]
        [string]
        $adobe
    )

    $files = Get-ChildItem -Path $path\$object *.tif* -Recurse
    foreach -Parallel -Throttle $throttle ($file in $files) {
        $basefilename = $file.Basename
        $fullfilename = $file.Fullname
        $sourceICC = "$path\$object\source_$basefilename.icc"
        #Write-Output "        Converting $basefilename to JP2." | Tee-Object -file $log -Append
        Invoke-Expression "$gm convert $fullfilename $sourceICC"
        Invoke-Expression "$gm convert $fullfilename -profile $sourceICC -intent Absolute -flatten -quality 85 -define jp2:prg=rlcp -define jp2:numrlvls=7 -define jp2:tilewidth=1024 -define jp2:tileheight=1024 -profile $adobe $path\$object\scans\$basefilename.jp2"
        Remove-Item $sourceICC
    }

}

Workflow Convert-to-Text-And-PDF {
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
        #$i++
        $basefilename = $file.BaseName
        #$fullfilename = $file.FullName
        #$tmp = ($basefilename + "_ocr.tif")
        #$fulltmp = "$path\$object\$tmp"
        #$count = $files.Count
        #Write-Output "        Converting $basefilename to TXT and PDF." | Tee-Object -file $log -Append
        #Copy-Item -Path $fullfilename -Destination $path\$object\$tmp
        #Invoke-Expression "$gm mogrify -format tif -colorspace gray $fulltmp" 2>&1 | Tee-Object -FilePath $log -Append
        Invoke-Expression "$tesseract $path\$object\$file $path\$object\transcripts\$basefilename txt pdf quiet"
        #Remove-Item $path\$object\$tmp
    }
}

function Convert-to-Text-And-PDF-ABBYY {
    Param(
        [Parameter()]
        [string]
        $path,

        [Parameter()]
        [string]
        $object,

        [Parameter()]
        [string]
        $log_batchCreate
    )
    
    $abbyy_staging = O:\pcd\cho-cdm\staging
    $abbyy_both_in = O:\pcd\cho-cdm\input
    $abbyy_both_out = O:\pcd\cho-cdm\output
    
    $tifs = (Get-ChildItem *.tif* -Path $path\$object -Recurse).count
    $txts = (Get-ChildItem *.txt -Path $abbyy_text_out\$object -Recurse).count

    New-Item -ItemType Directory -Path $abbyy_staging\$object | Out-Null   

    . Copy-Tif $path $object $throttle $abbyy_staging $log_batchCreate 2>&1 | Tee-Object -file $log_batchCreate -Append

    Move-Item $abbyy_staging\$object $abbyy_both_in 2>&1 | Tee-Object -file $log_batchCreate -Append
    
    while ($tifs -ne $txts) { Start-Sleep -Seconds 15 }

    Get-ChildItem * -Path $abbyy_both_out\$object | ForEach-Object {
        Move-Item -Path $_ -Destination $path\$object\transcripts  2>&1 | Tee-Object -file $log_batchCreate -Append
    }

    . Merge-PDF $path $object $log_batchCreate 2>&1 | Tee-Object -file $log_batchCreate -Append

    Move-Item $path\$object\transcripts\$object.pdf $path\$object\$object.pdf 2>&1 | Tee-Object -file $log_batchCreate -Append

    Remove-Item $abbyy_both_out\$object 2>&1 | Tee-Object -file $log_batchCreate -Append

}

Workflow Convert-to-Text {
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
        $log_batchCreate,

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
        Invoke-Expression "$gm mogrify -format tif -colorspace gray $fulltmp" 2>&1 | Tee-Object -FilePath $log -Append
        Invoke-Expression "$tesseract $path\$object\$tmp $path\$object\transcripts\$basefilename txt quiet"
        Remove-Item $path\$object\$tmp
    }
}

function Convert-to-Text-ABBYY {
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
        $log_batchCreate
    )

    $abbyy_staging = O:\pcd\text\staging
    $abbyy_text_in = O:\pcd\text\input
    $abbyy_text_out = O:\pcd\text\output
    
    $tifs = (Get-ChildItem *.tif* -Path $path\$object -Recurse).count
    $txts = (Get-ChildItem *.txt -Path $abbyy_text_out\$object -Recurse).count
    
    New-Item -ItemType Directory -Path $abbyy_staging\$object | Out-Null   

    . Copy-Tif $path $object $throttle $abbyy_staging $log_batchCreate 2>&1 | Tee-Object -file $log_batchCreate -Append

    Move-Item $abbyy_staging\$object $abbyy_text_in 2>&1 | Tee-Object -file $log_batchCreate -Append
    
    while ($tifs -ne $txts) { Start-Sleep -Seconds 15 }

    Get-ChildItem *.txt -Path $abbyy_text_out\$object | ForEach-Object {
        Move-Item -Path $_ -Destination $path\$object\transcripts  2>&1 | Tee-Object -file $log_batchCreate -Append
    }

    Remove-Item $abbyy_text_out\$object 2>&1 | Tee-Object -file $log_batchCreate -Append
}

Workflow Convert-to-PDF {
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
        $log_batchCreate,

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
        #$fullfilename = $file.FullName
        #$tmp = ($basefilename + "_ocr.tif")
        #$fulltmp = "$path\$object\$tmp"
        #Copy-Item -Path $fullfilename -Destination $path\$object\$tmp
        #Invoke-Expression "$gm mogrify -format tif -colorspace gray $fulltmp" 2>&1 | Tee-Object -FilePath $log -Append
        Invoke-Expression "$tesseract $path\$object\$file $path\$object\transcripts\$basefilename pdf quiet"
        #Remove-Item $path\$object\$tmp
    }
}

function Convert-to-PDF-ABBYY {
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
        $log_batchCreate

    )
    $abbyy_staging = O:\pcd\many2pdf-high\staging
    $abbyy_pdf_in = O:\pcd\many2pdf-high\input
    $abbyy_pdf_out = O:\pcd\many2pdf-high\output
    
    $pdf = ($abbyy_pdf_out + "\" + $object + ".pdf")
    $txt = ($abbyy_pdf_out + "\" + $object + ".txt")
    
    New-Item -ItemType Directory -Path $abbyy_staging\$object | Out-Null   
    
    . Copy-Tif $path $object $throttle $abbyy_staging $log_batchCreate 2>&1 | Tee-Object -file $log_batchCreate -Append

    Move-Item $abbyy_staging\$object $abbyy_pdf_in 2>&1 | Tee-Object -file $log_batchCreate -Append

    while (!(Test-Path $pdf)) { 
        Start-Sleep 10
    }
    
    Move-Item $pdf $path\$object 2>&1 | Tee-Object -file $log_batchCreate -Append
    Remove-Item $txt 2>&1 | Tee-Object -file $log_batchCreate -Append
}

Workflow Copy-Tif ($path,$object,$throttle,$abbyy_staging,$log_batchCreate) {
    $files = Get-ChildItem *.tif* -Path $path\$object -Recurse
    foreach -Parallel -Throttle $throttle ($file in $files) {    
        Copy-Item -Path $file.FullName -Destination $abbyy_staging\$object  2>&1 | Tee-Object -file $log_batchCreate -Append
    }
}

Workflow Get-Images-Using-API {
    Param($path, $server, $collection, $public, $throttle)
    $list = @()
    $items = import-csv "$path\items_clean.csv" -Header dmrecord, file
    foreach ($item in $items) {
        $imageInfo = Invoke-RestMethod ($server + "/dmwebservices/index.php?q=dmGetImageInfo/" + $collection + "/" + $item.dmrecord + "/json")
        $url = ($public + "/utils/ajaxhelper/?CISOROOT=" + $collection + "&CISOPTR=" + $item.dmrecord + "&action=2&DMSCALE=100&DMWIDTH=" + $imageInfo.width + "&DMHEIGHT=" + $imageInfo.height + "&DMX=0&DMY=0")
        $id = ($collection + "_" + $item.dmrecord)
        $file = ("$path\" + $id + ".jpg")
        $list += [PSCustomObject]@{
            url  = $url
            file = $file
        }
    }
    foreach -Parallel -Throttle $throttle ($row in $list) {
        Invoke-WebRequest $row.url -Method Get -OutFile $row.file
        Write-Output ("Downloading " + $row.file)
    }
}

#IIIF for images. Test different size tifs for smaller and quicker files, eg /full/2000, /0/default.jpg
# Not working as of 2019-08-23, still working on getting URI and ID paired together for downloading...
Workflow Get-Images-Using-IIIF {
    Param($public, $collection, $throttle, $path)
    $collectionManifest = Invoke-Restmethod $public/iiif/info/$collection/manifest.json
    $objectManifests = $collectionManifest.manifests."@id" # CONTENTdm only generates IIIF manifests for images as of 2019-08-21.
    $uris = @()
    foreach ($manifest in $objectManifests) {
        $record = Invoke-RestMethod $manifest
        $uri = ($record.sequences.canvases.images.resource."@id")
        $uris += $uri
    }
    foreach -Parallel -Throttle $throttle ($uri in $uris) {
            
        "$uri" -match "\/(\d*)\/full"
        $matches

        #Write-Output $uri #$file
        #Invoke-RestMethod -Uri $uri -OutFile $file


    }

}

Workflow Update-OCR {
    Param($path, $throttle, $collection, $gm, $tesseract, $field, $ocrCount)
    $csv = @()
    $items = import-csv "$path\items_clean.csv" -Header dmrecord, file
    foreach -Parallel -Throttle $throttle ($item in $items) {
        $id = ($collection + "_" + $item.dmrecord)
        $imageFile = ("$path\" + $id + ".jpg")
        if ((Test-Path "$imageFile") -and ((Get-Item $imageFile).Length -gt 0kb)) {
            Invoke-Expression ("$gm mogrify -format tif -colorspace gray $imageFile") -ErrorAction SilentlyContinue
        }
        $imageFile = ("$path\" + $id + ".tif")
        $imageBase = ("$path\" + $id)
        if (Test-Path "$imageFile") {
            Invoke-Expression ("$tesseract $imageFile $imageBase txt quiet") -ErrorAction SilentlyContinue
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
    }
    $csv | Export-CSV $path\ocr.csv -NoTypeInformation
}