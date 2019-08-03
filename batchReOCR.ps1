# batchReOCR.ps1 1.0
# Nathan Tallman, created in October 2018, re-written 31 July 2019.
# https://github.com/psu-libraries/contentdmtools

# Parameters
param(
    [Parameter(Mandatory)]
    [string]
    $collection = $(Throw "Use -collection to specify the alias for the collection."),

    [Parameter(Mandatory)]
    [string]
    $field = $(Throw "Use -field to specify the nickname of the field used to save full-text transcripts."),

    [Parameter(Mandatory)]
    [string]
    $path = $(Throw "Use -path to specify a location for temporary staging files."),

    [Parameter(Mandatory)]
    [string]
    $public = $(Throw "Use -public to specify the URL for the CONTENTdm Public GUI. Ex: https://cdm1234.contentdm.oclc.org"),

    [Parameter(Mandatory)]
    [string]
    $server = $(Throw "Use -server to specify the URL for the CONTENTdm Administrative GUI. Ex: https://server1234.contentdm.oclc.org")
)

# Variables
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$gm = "$dir\util\gm\gm.exe"
$tesseract = "$dir\util\tesseract\tesseract.exe"
$path = $(Resolve-Path "$path")
$pwd = $(Get-Location).Path
$log = ($dir + "\logs\batchReOCR_" + $collection + "_log_" + $(Get-Date -Format yyyy-MM-ddTHH-mm-ss-ffff) + ".txt")
$csv = @()
$i = 0
$l = 0
$nonImages = 0
[boolean]$success -eq 0 | Out-Null
$pages2ocr = $null
$pages2ocr = @{ }

# Functions
function Get-TimeStamp { return "[{0:yyyy-MM-dd} {0:HH:mm:ss}]" -f (Get-Date) }

function Convert-OCR($ocrText) { 
    (Get-Content $ocrText) | ForEach-Object {
        $_ -replace '[^a-zA-Z0-9_.,!?$%#@/\s]' `
            -replace '[\u009D]' `
            -replace '[\u000C]'
    } | Set-Content $ocrText 
}

function Test-Success {
    if (!($success)) { }
    if (!($LASTEXITCODE)) { $success -eq 1 }
}

Write-Output "----------------------------------------------" | Tee-Object -file $log
Write-Output "$(Get-Timestamp) CONTENTdm Tools Batch Re-OCR Starting." | Tee-Object -file $log -Append
Write-Output "Collection Alias: $collection" | Tee-Object -file $log -Append
Write-Output "----------------------------------------------" | Tee-Object -file $log -Append

# Get the CONTENTdm records for the collection
$hits = Invoke-RestMethod "$server/dmwebservices/index.php?q=dmQuery/$collection/0/dmrecord!find/nosort/1024/1/0/0/0/0/1/0/json"
$records = $hits.records
foreach ($record in $records) {
    if ($record.filetype -eq "cpd") {
        $pointer = $record.pointer
        $objects = Invoke-RestMethod "https://server17287.contentdm.oclc.org/dmwebservices/index.php?q=dmGetCompoundObjectInfo/$collection/$pointer/json"
        foreach ($object in $objects) {
            $pages = $object.page
            foreach ($page in $pages) {
                $pages2ocr.Add($page.pageptr, $page.pagefile)
            }
        }
    }
    elseif (($record.filetype -eq "jp2") -or ($record.filetype -eq "jpg")) {
        $pages2ocr.Add($record.pointer, $record.find)
    }
    elseif (($record.filetype -ne "jp2") -or ($record.filetype -ne "jpg")) {
        $nonImages++
    }
}
if (!(Test-Path $path\tmp)) { New-Item -ItemType Directory -Path $path\tmp | Out-Null }
$pages2ocr.GetEnumerator() | Select-Object -Property Name, Value | Export-CSV $path\tmp\items.csv -NoTypeInformation
Get-Content $path\tmp\items.csv | Select-Object -Skip 1 | Set-Content $path\tmp\items_clean.csv
$items = import-csv $path\tmp\items_clean.csv -Header dmnumber, file

# Download the JP2 for each item in the collection (named for the record number, not original filename) and run Tesseract OCR
Set-Location $path\tmp | Tee-Object -file $log -Append
foreach ($item in $items) {
    $l++
    $imageInfo = Invoke-RestMethod ($server + "/dmwebservices/index.php?q=dmGetImageInfo/" + $collection + "/" + $item.dmnumber + "/json")
    Write-Output ($(Get-Timestamp) + " Starting item " + $($item.dmnumber) + " (" + $l + " of " + $pages2ocr.count + " items)...") | Tee-Object -file $log -Append
    $imageFile = ($item.dmnumber + ".jpg")
    Write-Output "        Downloading $imageFile." | Tee-Object -file $log -Append
    Invoke-RestMethod ($public + "/utils/ajaxhelper/?CISOROOT=" + $collection + "&CISOPTR=" + $item.dmnumber + "&action=2&DMSCALE=100&DMWIDTH=" + $imageInfo.width + "&DMHEIGHT=" + $imageInfo.height + "&DMX=0&DMY=0") -OutFile $imageFile | Tee-Object -file $log -Append
    Write-Output "        Optimizing image for OCR." | Tee-Object -file $log -Append
    Invoke-Expression ("$gm mogrify -format tif -colorspace gray $imageFile") 2>&1 | Tee-Object -file $log -Append
    $imageFile = ($item.dmnumber + ".tif")
    Write-Output "        Running Tesseract OCR on the image." | Tee-Object -file $log -Append
    Invoke-Expression ("$tesseract $imageFile " + $item.dmnumber + " txt quiet") 2>&1 | Tee-Object -file $log -Append
    $imageTxt = ($item.dmnumber + ".txt")
    Write-Output "        Sanitizing OCR text for CONTENTdm." | Tee-Object -file $log -Append
    Convert-OCR -ocrText $imageTxt
    $value = (get-content $imageTxt) | Where-Object { $_.Trim(" `t") }
    Write-Output "        Add transcript to data file for updating collection." | Tee-Object -file $log -Append
    $itemDetails = New-Object -TypeName PSObject
    $itemDetails | Add-Member -MemberType NoteProperty -Name dmrecord -Value $item.dmnumber
    $itemDetails | Add-Member -MemberType NoteProperty -Name $field -Value $("$value")
    $csv += $itemDetails
    $noText = ($csv | Where-Object { $_.$field -ne "" }).count
    $csv | Where-Object { $_.$field -ne "" } | Export-CSV ocr.csv -NoTypeInformation
    Write-Output "$(Get-Timestamp) Completed item $($item.dmnumber)." | Tee-Object -file $log -Append
    if ($success) { $i++ }
}

# Send the new OCR to CONTENTdm
Write-Output "$(Get-Timestamp) Sending new transcripts to CONTENTdm using batchEdit.ps1, which will also generate its own log. Errors will not appear in this log..." | Tee-Object -file $log -Append
$command = ($dir + "\batchEdit.ps1 -csv " + $path + "\tmp\ocr.csv -collection " + $collection)
Write-Output $command 2>&1 | Tee-Object -file $log -Append
Try { Invoke-Expression -Command "$command" 2>&1 | Tee-Object -file $log -Append }
Catch { Write-Host "ERROR ERROR ERROR" -Fore "red" | Tee-Object -file $log -Append ; Write-Output $Return | Tee-Object -Filepath $log -Append }
Write-Output "$(Get-Timestamp) Transcripts sent, don't forget to re-index the collection in the Administrative GUI." | Tee-Object -file $log -Append

# Cleanup the tmp files
Write-Output "$(Get-Timestamp) Deleting any temporary files created throughout this process." | Tee-Object -file $log -Append
Remove-Item $path\tmp -Recurse -Force | Tee-Object -file $log -Append
Set-Location $pwd

Write-Output "----------------------------------------------" | Tee-Object -file $log -Append
Write-Output "$(Get-Timestamp) CONTENTdm Tools Batch Re-OCR Complete." | Tee-Object -file $log -Append
Write-Output "Collection Alias: $collection" | Tee-Object -file $log -Append
Write-Output "Batch Log: $log" | Tee-Object -file $log -Append
Write-Output "Number of images in collection: $($pages2ocr.count)" | Tee-Object -file $log -Append
Write-Output "Number of items without images: $nonImage" | Tee-Object -file $log -Append
Write-Output "Number of items without text:   $noText" | Tee-Object -file $log -Append
Write-Output "Number of items OCRed:          $i" | Tee-Object -file $log -Append
Write-Output "---------------------------------------------" | Tee-Object -file $log -Append
Write-Host -ForegroundColor Yellow "This window can be closed at anytime. Don't forget to index the collection!"