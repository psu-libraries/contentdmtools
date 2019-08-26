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
Write-Output "Collection Alias:   $collection" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Transcript Field:   $field" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Public URL:         $public" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Server URL:         $server" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "License No.:        $license" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Staging Path:       $path" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "User:               $user" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Throttle:           $throttle" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Method:             $method" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output ("Executed Command:   " + $MyInvocation.Line) | Tee-Object -FilePath $log_batchOCR -Append
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

Write-Output "$(. Get-TimeStamp) Generating a list of images for the collection..." | Tee-Object -FilePath $log_batchOCR -Append
$nonImages = . Get-Images-List -server $server -collection $collection -path $path | Tee-Object -FilePath $log_batchOCR -Append
Write-Verbose "nonImages is $nonImages"

$total = ($(Import-Csv $path\items.csv) | Measure-Object).Count

if ($method -eq "API") {
    Write-Output ("$(. Get-TimeStamp) Downloading $total images from CONTENTdm using the API...") | Tee-Object -FilePath $log_batchOCR -Append
   . Get-Images-Using-API-2 -path $path -server $server -collection $collection -public $public -throttle $throttle -log $log_batchOCR | Tee-Object -FilePath $log_batchOCR -Append
    if ($LastExitCode -eq 1) {
        Write-Output "$(. Get-TimeStamp) Something went wrong when downloading the images, Batch OCR exiting before completion."
        Return
    }
}
elseif ($method -eq "IIIF") {
    # Not working yet -- 2019-08-23
    Write-Output ("$(. Get-TimeStamp) Downloading $total images from CONTENTdm using IIIF...") | Tee-Object -FilePath $log_batchOCR -Append
    . Get-Images-Using-IIIF -public $public -collection $collection -throttle $throttle -path $path | Tee-Object -FilePath $log_batchOCR -Append
    if ($LastExitCode -eq 1) {
        Write-Output "$(. Get-TimeStamp) Something went wrong when downloading the images, Batch OCR exiting before completion."
        Return
    }
}

Write-Output "$(. Get-TimeStamp) Running Tesseract OCR on images..." | Tee-Object -FilePath $log_batchOCR -Append
$return = . Update-OCR -path $path -throttle $throttle -collection $collection -field $field -gm $gm -tesseract $tesseract | Tee-Object -FilePath $log_batchOCR -Append
$ocrCount = $return[0]
$nonText = $return[1]
Write-Verbose "ocrCount is $ocrCount"
Write-Verbose "nonText is $nonText"

if (!(Test-Path $path\ocr.csv)) {
    Write-Error "(. Get-TimeStamp) An error occured before the OCR metadata CSV for Batch Edit could be created. Exiting Batch OCR."
    Return
}

# Remove blank rows from the CSV (no text)
Import-Csv $path\ocr.csv | Where-Object { $_.$field -ne "" } | Export-CSV $path\ocr_clean.csv -NoTypeInformation

#$csv | Select-Object -Property dmrecord, "$field" | Where-Object { $_.$field -ne "" } | Export-CSV $path\ocr.csv -NoTypeInformation

Write-Output "$(. Get-TimeStamp) Running Batch Edit to send updated OCR text to CONTENTdm..." | Tee-Object -FilePath $log_batchOCR -Append
$csvRows = (Import-CSV $path\ocr_clean.csv).count
$ScriptBlock = {
    $cdmt_root = $args[0]
    $collection = $args[1]
    $server = $args[2]
    $license = $args[3]
    $path = $args[4]
    $user = $args[5]
    $csv = ($path+"\ocr_clean.csv")

    . $cdmt_root\batchEdit.ps1 -collection $collection -server $server -license $license -csv $csv -user $user
}
Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $cdmt_root, $collection, $server, $license, $path, $user 2>&1 | Tee-Object -FilePath $log_batchOCR -Append

# Cleanup the tmp files
#Remove-Item $path -Recurse -Force | Tee-Object -FilePath $log_batchOCR -Append

$end = Get-Date
$runtime = New-TimeSpan -Start $start -End $end

Write-Output "----------------------------------------------" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "$(. Get-TimeStamp) CONTENTdm Tools Batch Re-OCR Complete." | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Total Elapsed Time: $runtime"
Write-Output "Collection Alias: $collection" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Batch Log: $log_batchOCR" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Items with images:     $total" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Items without images:  $nonImages" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Images for OCR:        $csvRows" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Images processed:      $ocrCount" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "Images without text:   $nonText" | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "---------------------------------------------" | Tee-Object -FilePath $log_batchOCR -Append
Write-Host -ForegroundColor Green "Read the Batch Edit report to see if any OCR updates were successfully sent to CONTENTdm. Don't forget to index the collection to save any edits. This window can be closed at anytime."