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
$path = $(Resolve-Path "$path")
if (!(Test-Path $cdmt_root\logs)) { New-Item -ItemType Directory -Path $cdmt_root\logs | Out-Null }
$log_batchOCR = ($cdmt_root + "\logs\batchOCR_" + $collection + "_log_" + $(Get-Date -Format yyyy-MM-ddTHH-mm-ss-ffff) + ".txt")
$nonImages = 0
$ocrCount = 0
$pages2ocr = $null
$pages2ocr = @{ }

# Import library
. $cdmt_root\util\lib.ps1

Write-Output "----------------------------------------------" | Tee-Object -FilePath $log_batchOCR
Write-Output "$(. Get-Timestamp) CONTENTdm Tools Batch OCR Starting." | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Collection Alias:   $collection" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Transcript Field:   $field" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Public URL:         $public" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Server URL:         $server" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "License No.:        $license" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Staging Path:       $path" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "User:               $user" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Throttle:           $throttle" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Method:             $method" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "----------------------------------------------" | Tee-Object -FilePath $log_batchOCR -Append

try { Test-Path $path | Out-Null }
catch {
    Write-Error "Error: Check the path to staging. Close this window at any time." | Tee-Object -FilePath $log_batchOCR -Append
    return
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

Write-Output "$(. Get-TimeStamp) Generating a list of images for the collection..." | Tee-Object -FilePath $log_batchOCR -Append
$nonImages = (. Get-Images-List -server $server -collection $collection -nonImages $nonImages -pages2ocr $pages2ocr -path $path)# | Tee-Object -FilePath $log_batchOCR -Append

if ($method -eq "API") {
    Write-Output ("$(. Get-TimeStamp) Downloading " + $pages2ocr.count + " images from CONTENTdm using the API...") | Tee-Object -FilePath $log_batchOCR -Append
    . Get-Images-Using-API -path $path -server $server -collection $collection -public $public -throttle $throttle | Tee-Object -FilePath $log_batchOCR -Append
}
elseif ($method -eq "IIIF") {
    # Not working yet -- 2019-08-23
    Write-Output ("$(. Get-TimeStamp) Downloading " + $pages2ocr.count + " images from CONTENTdm using IIIF...") | Tee-Object -FilePath $log_batchOCR -Append
    . Get-Images-Using-IIIF -public $public -collection $collection -throttle $throttle -path $path | Tee-Object -FilePath $log_batchOCR -Append
}

Write-Output "$(. Get-TimeStamp) Running Tesseract OCR on images..." | Tee-Object -FilePath $log_batchOCR -Append
$ocrCount = (. Update-OCR -path $path -throttle $throttle -collection $collection -field $field -ocrCount $ocrCount $gm $tesseract) | Tee-Object -FilePath $log_batchOCR -Append

# Remove items that have blank OCR output
if (Test-Path $path\ocr.csv) {
    $csv = Import-CSV  $path\ocr.csv
}
else {
    Write-Output "There was an error before the OCR metadata file for Batch Edit could be created."
    Return
}
$noText = ($csv | Where-Object { $_.$field -eq "" }).count
$csv | Select-Object -Property dmrecord, "$field" | Where-Object { $_.$field -ne "" } | Export-CSV $path\ocr.csv -NoTypeInformation

Write-Output "$(. Get-TimeStamp) Running Batch Edit to send updated OCR text to CONTENTdm..." | Tee-Object -FilePath $log_batchOCR -Append
$csvRows = (Import-CSV $path\ocr.csv).count
$ScriptBlock = {
    $cdmt_root = $args[0]
    $path = $args[1]
    $collection = $args[2]
    $user = $args[3]
    $server = $args[4]
    $license = $args[5]
    & $cdmt_root\batchEdit.ps1 -csv $path\ocr.csv -collection $collection -user $user -server $server -license $license | Tee-Object -FilePath $log_batchOCR -Append
}
Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $cdmt_root, $path, $collection, $user, $server, $license

# Cleanup the tmp files
#Remove-Item $path -Recurse -Force | Tee-Object -FilePath $log_batchOCR -Append

Write-Output "----------------------------------------------" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "$(. Get-TimeStamp) CONTENTdm Tools Batch Re-OCR Complete." | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Collection Alias: $collection" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Batch Log: $log_batchOCR" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Number of collection item with images:     $($pages2ocr.count)" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Number of collection items without images: $nonImages" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Number of items OCRed:          $ocrCount" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Number of items without text:   $noText" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Number of item updates sent:    $csvRows" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "---------------------------------------------" | Tee-Object -FilePath $log_batchOCR -Append
Write-Warning "The QC report numbers may not be valid. As of 2019-08-23 some of the variables are not reporting correctly."
Write-Host -ForegroundColor Green "This window can be closed at anytime. Don't forget to index the collection!"