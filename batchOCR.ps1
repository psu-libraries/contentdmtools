# batchOCR.ps1
<#
    .SYNOPSIS
    Batch OCR or Re-OCR an entire collection using the CONTENTdm API or IIIF, Tesseract OCR, and CONTENTdm Catcher with parallel processing.
    .DESCRIPTION
    Read stored organizational settings if none were supplied, use the CONTENTdm API to generate a list of dmrecord numbers for images in the collection. Use either the API or IIIF to parallel download the images, parallel optimize the images by converting them to grayscale TIFs using GraphicsMagick, parallel run Tesserat OCR on TIFs and optimize the OCR output, then store the OCR data. After OCRing all the images, export a CSV and pass it to batchEdit.ps1 to send to CONTENTdm Catcher to update the fulltext search field.
    .PARAMETER collection
    The collection alias for a CONTENTdm collection.
    .PARAMETER field
    The nickname for a field configured as fulltext search in the same CONTENTdm collection.
    .PARAMETER public
    The URL for the Public UI for a CONTENTdm instance.
    .PARAMETER server
    The URL for the Admin UI for a CONTENTdm instance.
    .PARAMETER license
    The license number for a CONTENTdm instance.
    .PARAMETER path
    The path to a staging location for temporary files.
    .PARAMETER user
    The user name of a CONTENTdm user.
    .PARAMETER throttle
    Integer for the number of CPU processes when copying TIFs to the ABBYY server. (DEFAULT VALUE: 6)
    .PARAMETER method
    The download method for collection images, API or IIIF. (DEFAULT VALUE: API)
    .EXAMPLE
    .\batchOCR.ps1 -collection benson -field transa -public https://digital.libraries.psu.edu -server https://urlToAdministrativeServer.edu -license XXXX-XXXX-XXXX-XXXX -path "E:\benson" -user dfj32 -throttle 8 -method IIIF
    .INPUTS
    System.String
    System.Integer
    .LINK
    https://github.com/psu-libraries/contentdmtools/blob/community/docs/batchOCR.md
#>

# Parameters
[cmdletbinding()]
param(
    [Parameter(Mandatory)]
    [string]
    $collection = $(Throw "Use -collection to specify the alias for the collection."),

    [Parameter(Mandatory)]
    [string]
    $field = $(Throw "Use -field to specify the nickname of the field used to save full-text transcripts."),

    [Parameter(Mandatory)]
    [string]
    $public = $(Throw "Use -public to specify a URL for the Public UI for a CONTENTdm instance."),

    [Parameter()]
    [string]
    $server = $(Throw "Use -server to specify a URL for the Admin UI for a CONTENTdm instance."),

    [Parameter()]
    [String]
    $license = $(Throw "Use -license to specify the license number for a CONTENTdm instance."),

    [Parameter(Mandatory)]
    [string]
    $path = $(Throw "Use -path to specify a location for temporary staging files."),

    [Parameter(Mandatory)]
    [String]
    $user = $(Throw "Use -user to specify a CONTENTdm user to run the batch edit, completing the OCR process."),

    [Parameter()]
    [int16]
    $throttle = 6,

    [Parameter()]
    [ValidateSet('API', 'IIIF')]
    [string]
    $method = 'API'
)

# Variables
$scriptpath = $MyInvocation.MyCommand.Path
$cdmt_root = Split-Path $scriptpath
$tesseract = "$cdmt_root\util\tesseract\tesseract.exe"
$gm = "$cdmt_root\util\gm\gm.exe"
$path = $(Resolve-Path "$path")
if (!(Test-Path $cdmt_root\logs)) { New-Item -ItemType Directory -Path $cdmt_root\logs | Out-Null }
$log_batchOCR = ($cdmt_root + "\logs\batchOCR_" + $collection + "_log_" + $(Get-Date -Format yyyy-MM-ddTHH-mm-ss-ffff) + ".txt")

# Import library
. $cdmt_root\util\lib.ps1

$start = Get-Date
Write-Output "----------------------------------------------" | Tee-Object -FilePath $log_batchOCR
Write-Output "$(. Get-TimeStamp) CONTENTdm Tools Batch OCR Starting." | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Collection Alias:`t$collection" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Transcript Field:`t$field" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Public URL:`t`t$public" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Server URL:`t`t$server" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "License No.:`t`t$license" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Staging Path:`t`t$path" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "User:`t`t`t$user" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Throttle:`t`t$throttle" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Method:`t`t`t$method" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output ("Executed Command:`t"+$MyInvocation.Line) | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "----------------------------------------------" | Tee-Object -FilePath $log_batchOCR -Append

try { Test-Path $path | Out-Null }
catch {
    Write-Error "Error: Check the path to staging. Close this window at any time." | Tee-Object -FilePath $log_batchOCR -Append
    return $Return
}

$path = "$path\tmp"
if (Test-Path $path) { Remove-Item $path -Recurse -Force | Out-Null }
if (!(Test-Path $path)) { New-Item -ItemType Directory -Path $path | Out-Null }

# Read in the stored org settings to use if no server or license parameters were supplied.
if (Test-Path $cdmt_root\settings\org.csv) {
    $org = $(. Get-Org-Settings)
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

# Download the images to OCR
switch ($method) {
    API {
        Write-Output "$(. Get-TimeStamp) Generating a list of images for the collection..." | Tee-Object -FilePath $log_batchOCR -Append
        $nonImages = . Get-Images-List -server $server -collection $collection -path $path | Tee-Object -FilePath $log_batchOCR -Append
        Write-Verbose "nonImages is $nonImages"
        $items = Import-Csv -path $path\items.csv
        $total = ( $items | Measure-Object).Count
        Write-Output ("$(. Get-TimeStamp) Downloading $total images from CONTENTdm using the API. Images will be downloaded in parallel, without throttle for efficency. Batch OCR will pause until all downloads have completed. You can ignore any warning about suspended or disconnected jobs...") | Tee-Object -FilePath $log_batchOCR -Append
        . Get-Images-Using-API -path $path -server $server -collection $collection -public $public | Tee-Object -FilePath $log_batchOCR -Append
        if ($LastExitCode -eq 1) {
            Write-Output "$(. Get-TimeStamp) Something went wrong when downloading the images, Batch OCR exiting before completion." | Tee-Object -FilePath $log_batchOCR -Append
            Return
        }
    }
    IIIF {
        Write-Output "$(. Get-TimeStamp) Downloading images from CONTENTdm using IIIF..." | Tee-Object -FilePath $log_batchOCR -Append
        . Get-Images-Using-IIIF -public $public -collection $collection -path $path | Tee-Object -FilePath $log_batchOCR -Append
        if ($LastExitCode -eq 1) {
            Write-Output "$(. Get-TimeStamp) Something went wrong when downloading the images, Batch OCR exiting before completion." | Tee-Object -FilePath $log_batchOCR -Append
            Return
        }
    }
}

Write-Output "$(. Get-TimeStamp) Running Tesseract OCR on images. This really cranks up your CPU and you may occassionally see warning messages from Tesseract, e.g. box not within image. Usually nothing to worry about, just don't set your throttle past the maximum number of logical processors on this computer.`r`n
$(. Get-TimeStamp) Sometimes Tesseract can take a long time on complex images. If it looks like Batch OCR is stuck, give it more time and see if the batch completes. Large collections sometimes take longer without screen updates too. OCRing...`r`n" | Tee-Object -FilePath $log_batchOCR -Append

# does batching need to be added in for large record sets? (already comes paged...) Tesseract stays open in Task Manager for a while
$return = . Update-OCR -path $path -throttle $throttle -collection $collection -field $field -gm $gm -tesseract $tesseract -method $method | Tee-Object -FilePath $log_batchOCR -Append
$ocrCount = $return[0]
$nonText = $return[1]
Write-Verbose "ocrCount is $ocrCount"
Write-Verbose "nonText is $nonText"

if (!(Test-Path $path\ocr.csv)) {
    Write-Error "(. Get-TimeStamp) An error occured before the OCR metadata CSV for Batch Edit could be created. Exiting Batch OCR." | Tee-Object -FilePath $log_batchOCR -Append
    Return
}

$noText = (Import-Csv $path\ocr.csv | Where-Object { $_.$field -eq "" }).Count
Write-Verbose "noText is $noText"

# Remove blank rows from the CSV (no text)
Import-Csv $path\ocr.csv | Where-Object { $_.$field -ne "" } | Export-CSV $path\ocr_clean.csv -NoTypeInformation
$csvRows = (Import-CSV $path\ocr_clean.csv).count

Write-Output "$(. Get-TimeStamp) Running Batch Edit to send updated OCR text to CONTENTdm..." | Tee-Object -FilePath $log_batchOCR -Append
$ScriptBlock = {
    $cdmt_root = $args[0]
    $collection = $args[1]
    $server = $args[2]
    $license = $args[3]
    $path = $args[4]
    $user = $args[5]
    $csv = ($path + "\ocr_clean.csv")

    . $cdmt_root\batchEdit.ps1 -collection $collection -server $server -license $license -csv $csv -user $user
}
Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $cdmt_root, $collection, $server, $license, $path, $user 2>&1 | Tee-Object -FilePath $log_batchOCR -Append

# Cleanup the tmp files
Remove-Item $path -Recurse -Force | Tee-Object -FilePath $log_batchOCR -Append

$end = Get-Date
$runtime = New-TimeSpan -Start $start -End $end

Write-Output "----------------------------------------------" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "$(. Get-TimeStamp) CONTENTdm Tools Batch Re-OCR Complete." | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Total Elapsed Time:`t$runtime" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Collection Alias:`t$collection" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Batch Log:`t`t$log_batchOCR" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Images for Batch OCR:    $total" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "                        ------" | Tee-Object -FilePath $log_batchOCR -Append
#Write-Output "Items without images:       $nonImages" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Images with text:        $ocrCount" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Images without text:     $($nonText + $noText)" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "                        ------" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Updates for Batch Edit:  $csvRows" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "---------------------------------------------" | Tee-Object -FilePath $log_batchOCR -Append
Write-Host -ForegroundColor Green "Read the Batch Edit report above to see if OCR updates were successfully sent to CONTENTdm. Don't forget to index the collection to save any initiated edits. This window can be closed at anytime."