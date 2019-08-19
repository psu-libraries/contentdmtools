# batchOCR.ps1
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
    [String]
    $user = $(Throw "Use -user to specify a CONTENTdm user to run the batch edit, completing the OCR process."),

    [Parameter()]
    [string]
    $public,

    [Parameter()]
    [string]
    $server,

    [Parameter()]
    [String]
    $license
)

# Variables
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$gm = "$dir\util\gm\gm.exe"
$tesseract = "$dir\util\tesseract\tesseract.exe"
$path = $(Resolve-Path "$path")
$pwd = $(Get-Location).Path
if (!(Test-Path $dir\logs)) { New-Item -ItemType Directory -Path $dir\logs | Out-Null }
$log = ($dir + "\logs\batchOCR_" + $collection + "_log_" + $(Get-Date -Format yyyy-MM-ddTHH-mm-ss-ffff) + ".txt")
$csv = @()
$i = 0
$l = 0
$nonImages = 0
[boolean]$success -eq 0 | Out-Null
$pages2ocr = $null
$pages2ocr = @{ }

# Read in the stored org settings to use if no server or license parameters were supplied.
$orgcsv = "$dir\settings\org.csv"
if (Test-Path $orgcsv) {
    $org = $(. $dir\util\lib.ps1;; Get-Org-Settings)
    if (!($public) -or ($null -eq $public)) {
        $public = $org.public
    }
    if (!($server) -or ($null -eq $server)) {
        $server = $org.server
    }
    if (!($license) -or ($null -eq $license)) {
        $license = $org.license
    }
} # error handling if no org settings? Or will user be prompted?

# Functions
function Get-TimeStamp { return "[{0:yyyy-MM-dd} {0:HH:mm:ss}]" -f (Get-Date) }

function Convert-OCR($ocrText) {
    (Get-Content $ocrText) | ForEach-Object {
        $_ -replace '[^a-zA-Z0-9_.,!?$%#@/\s]' `
            -replace '[\u009D]' `
            -replace '[\u000C]'
    } | Set-Content $ocrText
}

Write-Output "----------------------------------------------" | Tee-Object -FilePath $log
Write-Output "$(Get-Timestamp) CONTENTdm Tools Batch Re-OCR Starting." | Tee-Object -FilePath $log -Append
Write-Output "Collection Alias: $collection" | Tee-Object -FilePath $log -Append
Write-Output "----------------------------------------------" | Tee-Object -FilePath $log -Append

# Get the CONTENTdm records for the collection
$hits = Invoke-RestMethod "$server/dmwebservices/index.php?q=dmQuery/$collection/0/dmrecord!find/nosort/1024/1/0/0/0/0/1/0/json"
$records = $hits.records
foreach ($record in $records) {
    if ($record.filetype -eq "cpd") {
        $pointer = $record.pointer
        $objects = Invoke-RestMethod "$server/dmwebservices/index.php?q=dmGetCompoundObjectInfo/$collection/$pointer/json"
        foreach ($object in $objects) {
            if ($object.type -eq "Monograph"){
                $pages = $object.node.node.page
                foreach ($page in $pages) {
                    $pages2ocr.Add($page.pageptr, $page.pagefile)
                }
            } else {
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
if (!(Test-Path $path\tmp)) { New-Item -ItemType Directory -Path $path\tmp | Out-Null }
Set-Location $path\tmp
$pages2ocr.GetEnumerator() | Select-Object -Property Name, Value | Export-CSV items.csv -NoTypeInformation
Get-Content items.csv | Select-Object -Skip 1 | Set-Content items_clean.csv
try { $items = import-csv items_clean.csv -Header dmrecord, file }
catch {
    Write-Error "Error: Check your parameters and try again. Close this window at any time." | Tee-Object -FilePath $log -Append
    Write-Output "Error: Check your parameters and try again. Close this window at any time." >>  $log
    return
}

# Download the JP2 for each item in the collection (named for the record number, not original filename) and run Tesseract OCR
foreach ($item in $items) {
    $l++
    $id = ($collection + "_" + $item.dmrecord)
    Write-Output ($(Get-Timestamp) + " Starting " + $id + " (" + $l + " of " + $pages2ocr.count + " items)...") | Tee-Object -FilePath $log -Append
    $imageInfo = Invoke-RestMethod ($server + "/dmwebservices/index.php?q=dmGetImageInfo/" + $collection + "/" + $item.dmrecord + "/json")
    $imageFile = ($id + ".jpg")
    Write-Output "        Downloading $imageFile." | Tee-Object -FilePath $log -Append
    Invoke-RestMethod ($public + "/utils/ajaxhelper/?CISOROOT=" + $collection + "&CISOPTR=" + $item.dmrecord + "&action=2&DMSCALE=100&DMWIDTH=" + $imageInfo.width + "&DMHEIGHT=" + $imageInfo.height + "&DMX=0&DMY=0") -OutFile $imageFile | Tee-Object -FilePath $log -Append
    <# IIIF for images. Test different size tifs for smaller and quicker files, eg /full/2000,/0/default.jpg
    Write-Output ($(Get-Timestamp) + " Starting dmrecord: " + $($item.dmrecord) + " (" + $l + " of " + $pages2ocr.count + " items)...") | Tee-Object -FilePath $log -Append
    $imageFile = ($item.dmrecord + ".jpg")
    Write-Output "        Downloading $imageFile." | Tee-Object -FilePath $log -Append
    Invoke-RestMethod ($public + "/digital/iiif/" + $collection + "/" + $item.dmrecord + "/full/full/0/default.jpg") -OutFile $imageFile | Tee-Object -FilePath $log -Append #>
    Write-Output "        Optimizing image for OCR." | Tee-Object -FilePath $log -Append
    Invoke-Expression ("$gm mogrify -format tif -colorspace gray $imageFile") 2>&1 | Tee-Object -FilePath $log -Append
    $imageFile = ($id + ".tif")
    Write-Output "        Running Tesseract OCR on the image." | Tee-Object -FilePath $log -Append
    Invoke-Expression ("$tesseract $imageFile " + $id + " txt quiet") 2>&1 | Tee-Object -FilePath $log -Append
    $imageTxt = ($id + ".txt")
    Write-Output "        Optimizing OCR." | Tee-Object -FilePath $log -Append
    Convert-OCR -ocrText $imageTxt
    if ($?) { $i++ }
    $imageTxt2 = ($id + "-2.txt")
    $(Get-Content $imageTxt) | Where-Object {$_.trim() -ne ""} | Set-Content $imageTxt2
    if (Test-Path $imageTxt2) {
        $value =  $(Get-Content $imageTxt2) -join "`n"
    } else {
        $value =  $(Get-Content $imageTxt) -join "`n"
    }
    Write-Output "        Add transcript to data file for updating collection." | Tee-Object -FilePath $log -Append
    $itemDetails = New-Object -TypeName PSObject
    $itemDetails | Add-Member -MemberType NoteProperty -Name dmrecord -Value $item.dmrecord
    $itemDetails | Add-Member -MemberType NoteProperty -Name $field -Value "$value"
    $csv += $itemDetails
    Write-Output "$(Get-Timestamp) Completed item $($item.dmrecord)." | Tee-Object -FilePath $log -Append
}

# Remove items that have blank OCR output
$noText = ($csv | Where-Object { $_.$field -eq "" }).count
$csv | Where-Object { $_.$field -ne "" } | Export-CSV ocr.csv -NoTypeInformation
$ocrUpdates = (Import-CSV ocr.csv).count

# Send the new OCR to CONTENTdm
Write-Output "$(Get-Timestamp) Sending new transcripts to CONTENTdm using batchEdit.ps1, which will generate an additional log." | Tee-Object -FilePath $log -Append
$ScriptBlock = {
    $dir = $args[0]
    $path = $args[1]
    $collection = $args[2]
    $user = $args[3]
    $server = $args[4]
    $license = $args[5]
    & $dir\batchEdit.ps1 -csv $path\tmp\ocr.csv -collection $collection -user $user -server $server -license $license
}
Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $dir,$path,$collection,$user,$server,$license
<# Try { Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $dir,$path,$collection,$user,$server,$license,$password }
Catch {
    Write-Error "ERROR: Batch edit not sent to CONTENTdm Catcher." | Tee-Object -FilePath $log -Append
    Write-Output "ERROR: Batch edit not sent to CONTENTdm Catcher." >> $log
    Write-Output $Return | Tee-Object -FilePath $log -Append
} #>
Write-Output "$(Get-Timestamp) Batch edit of updated transcripts complete." | Tee-Object -FilePath $log -Append
Set-Location $pwd

# Cleanup the tmp files
Write-Output "$(Get-Timestamp) Deleting any temporary files created throughout this process." | Tee-Object -FilePath $log -Append
Remove-Item $path\tmp -Recurse -Force | Tee-Object -FilePath $log -Append

Write-Output "----------------------------------------------" | Tee-Object -FilePath $log -Append
Write-Output "$(Get-Timestamp) CONTENTdm Tools Batch Re-OCR Complete." | Tee-Object -FilePath $log -Append
Write-Output "Collection Alias: $collection" | Tee-Object -FilePath $log -Append
Write-Output "Batch Log: $log" | Tee-Object -FilePath $log -Append
Write-Output "Number of collection item with images:     $($pages2ocr.count)" | Tee-Object -FilePath $log -Append
Write-Output "Number of collection items without images: $nonImages" | Tee-Object -FilePath $log -Append
Write-Output "Number of items OCRed:          $i" | Tee-Object -FilePath $log -Append
Write-Output "Number of items without text:   $noText" | Tee-Object -FilePath $log -Append
Write-Output "Number of items updates sent:   $ocrUpdates" | Tee-Object -FilePath $log -Append
Write-Output "---------------------------------------------" | Tee-Object -FilePath $log -Append
Write-Host -ForegroundColor Green "This window can be closed at anytime. Don't forget to index the collection!"