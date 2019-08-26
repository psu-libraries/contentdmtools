# batchEdit.ps1
<#
    .SYNOPSIS
    Pass a CSV of bulk metadata changes to CONTENTdm using CONTENTdm Catcher.
    .DESCRIPTION
    Read stored organizational settings if none were supplied, grab the stored user password prompt the user to enter a password, read in CSV of metadata, use the CONTENTdm API to lookup the type of each record and group objects first, write a SOAP XML update record for each change and send it to CONTENTdm Catcher.
    .PARAMETER csv
    The filepath and name to a CSV of changed metadata for a CONTENTdm collection. Must use field nicknames as headers, not field names.
    .PARAMETER user
    The user name of a CONTENTdm user.
    .PARAMETER collection
    The collection alias for a CONTENTdm collection.
    .PARAMETER server
    The URL for the Admin UI for a CONTENTdm instance.
    .PARAMETER license
    The license number for a CONTENTdm instance.
    .EXAMPLE
    .\batchEdit.ps1 -csv E:\benson\changes.csv -user dfj32 -collection transa -public https://digital.libraries.psu.edu -server https://urlToAdministrativeServer.edu -license XXXX-XXXX-XXXX-XXXX -path "E:\benson"  -throttle 8 -method IIIF
    .INPUTS
    System.String
    .NOTES
    Required fields and controlled vocabularies must be disabled in the Admin UI or CONTENTdm Cathcer will fail.
    .LINK
    https://github.com/psu-libraries/contentdmtools/blob/community/docs/batchEdit.md
#>

# Read in the metadata changes with -csv path, pass the collection alias with -collection collectionAlias.
[cmdletbinding()]
Param (
    [Parameter(Mandatory)]
    [string]
    $collection = $(Throw "Use -collection to specify the collection."),

    [Parameter()]
    [string]
    $server = $(Throw "Use -public to specify a URL for the Admin UI for a CONTENTdm instance."),

    [Parameter()]
    [string]
    $license = $(Throw "Use -public to specify the license number for a CONTENTdm instance."),

    [Parameter(Mandatory)]
    [string]
    $csv = $(Throw "Use -csv to speecify the filepath and name to a CSV of changed metadata for a CONTENTdm collection"),

    [Parameter(Mandatory)]
    [string]
    $user = $(Throw "Use -user to specify the CONTENTdm user.")
)

# Variables
$scriptpath = $MyInvocation.MyCommand.Path
$cdmt_root = Split-Path $scriptpath
If (!(Test-Path $cdmt_root\logs)) { New-Item -ItemType Directory -Path $cdmt_root\logs | Out-Null }
$log_batchEdit = ("$cdmt_root\logs\batchEdit_" + $collection + "_log_" + $(Get-Date -Format yyyy-MM-ddTHH-mm-ss-ffff) + ".txt")
$i = 0
$editCount = 0
. $cdmt_root\util\lib.ps1

Write-Output "----------------------------------------------" | Tee-Object -file $log_batchEdit
Write-Output "$(. Get-TimeStamp) CONTENTdm Tools Batch Edit Starting." | Tee-Object -file $log_batchEdit -Append
Write-Output "Collection Alias: $collection" | Tee-Object -file $log_batchEdit -Append
Write-Debug "CONTENTdm User:    $User" | Tee-Object -file $log_batchEdit -Append
Write-Debug "CONTENTdm Server:  $server" | Tee-Object -file $log_batchEdit -Append
Write-Debug "CONTENTdm License: $license" | Tee-Object -file $log_batchEdit -Append
#THis causes problems when this is run via batch ocr...
#Write-Output ("Executed Command:   " + $MyInvocation.Line) | Tee-Object -FilePath $log_batchOCR -Append
Write-Output "----------------------------------------------" | Tee-Object -file $log_batchEdit -Append

# Read in the stored org settings to use if no server or license parameters were supplied.
Write-Debug "Test for existing organizational settings; if they exist, import server and license values."
if (Test-Path $cdmt_root\settings\org.csv) {
    $org = $(. Get-Org-Settings)
    if (!($server) -or ($null -eq $server)) {
        $server = $org.server
    }
    if (!($license) -or ($null -eq $license)) {
        $license = $org.license
    }
}

# Check for stored user password, if not available get user input.
Write-Debug "Test for existing user credentials; if they exist use the, if they don't prompt for a password. "
if (Test-Path $cdmt_root\settings\user.csv) {
    $usrcsv = $(Resolve-Path $cdmt_root\settings\user.csv)
    $usrcsv = Import-Csv $usrcsv
    $usrcsv | Where-Object { $_.user -eq "$user" } | ForEach-Object {
        $SecurePassword = $_.password | ConvertTo-SecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
        $pw = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        $null = $BSTR
    }
    if ("$user" -notin $usrcsv.user) {
        Write-Output "No user settings found for $user. Enter a password below or store secure credentials using the dashboard." | Tee-Object -Filepath $log_batchEdit -Append
        [SecureString]$password = Read-Host "Enter $user's CONTENTdm password" -AsSecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR([SecureString]$password)
        $pw = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        $null = $BSTR
    }
}
Else {
    Write-Output "No user settings file found. Enter a password below or store secure credentials using the dashboard." | Tee-Object -Filepath $log_batchEdit -Append
    [SecureString]$password = Read-Host "Enter $user's CONTENTdm password" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR([SecureString]$password)
    $pw = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    $null = $BSTR
}

# Read in the metadata, add Level column to sort, lookup type, sort rows so Objects are first.
Write-Debug "Import $csv and read the headers."
Write-Output "Reading in the metadata and sorting the compound objects first." | Tee-Object -file $log_batchEdit -Append
$metadata = Import-Csv -Path "$csv"
$headers = ($metadata[0].psobject.Properties).Name
<# UNTESTED Lookup and convert field names to nicknames.
 $fields = Invoke-RestMethod $server/dmwebservices/index.php?q=dmGetCollectionFieldInfo/$collection/json
foreach ($header in $metadata[0].psobject.Properties) {
    if ($header -eq $fields.Name) {
        $fields.nick = $header
    }
} #>

# Try using ConvertFrom-CSV here to eliminate these tmp files. Try add-member notepropertyname/value
Write-Debug "Add a column to the metadata for object level."
$metadata = $metadata | Select-Object *, @{Name = 'Level'; Expression = { '' } } | Export-CSV -Path "$cdmt_root\tmp1.csv" -NoTypeInformation
$metadata = Import-Csv -Path "$cdmt_root\tmp1.csv"

Write-Debug "Call the CONTENTdm API for each item to determine its type."
foreach ($record in $metadata) {
    $dmrecord = $($record.dmrecord)
    $itemInfo = Invoke-RestMethod "$server/dmwebservices/index.php?q=dmGetItemInfo/$collection/$dmrecord/json"
    $itemFile = $($itemInfo.find)
    $itemType = $itemFile.Substring($itemFile.Length - 3, 3)
    if ($itemType -eq "cpd") {
        $record.Level = "Object"
    }
    elseif ($itemType -ne "cpd") {
        $record.Level = "Item"
    }
}

Write-Debug "Group compound objects first in the metadata to feed to Catcher."
$metadata | Sort-Object -Property Level -Descending | Export-CSV $cdmt_root\tmp2.csv -NoTypeInformation
$metadata = Import-Csv -Path "$cdmt_root\tmp2.csv"

# Build and send the SOAP XML to CONTENTdm Catcher
Write-Debug "Establish the loop for building SOAP XML for each update."
ForEach ($record in $metadata) {
    $dmrecord = $record.dmrecord
    Write-Debug "Building the SOAP for $dmrecord"
    $i++
    $SOAPRequest = '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:v6="http://catcherws.cdm.oclc.org/v6.0.0/">' + "`r`n"
    $SOAPRequest += "`t<soapenv:Header/>`r`n"
    $SOAPRequest += "`t<soapenv:Body>`r`n"
    $SOAPRequest += "`t`t<v6:processCONTENTdm>`r`n"
    $SOAPRequest += "`t`t`t<action>edit</action>`r`n"
    $SOAPRequest += "`t`t`t<cdmurl>http://server17287.contentdm.oclc.org:8888</cdmurl>`r`n"
    $SOAPRequest += "`t`t`t<username>$user</username>`r`n"
    $SOAPRequest += "`t`t`t<password>$pw</password>`r`n"
    $SOAPRequest += "`t`t`t<license>$license</license>`r`n"
    $SOAPRequest += "`t`t`t<collection>$collection</collection>`r`n"
    $SOAPRequest += "`t`t`t`t<metadata>`r`n"
    $SOAPRequest += "`t`t`t`t`t<metadataList>`r`n"
    ForEach ($header in $headers) {
        $SOAPRequest += "`t`t`t`t`t`t<metadata>`r`n"
        ForEach ($data in $record.$header) {
            $SOAPRequest += "`t`t`t`t`t`t`t<field>" + $header + "</field>`r`n"
            $SOAPRequest += "`t`t`t`t`t`t`t<value>" + $data + "</value>`r`n"
        }
        $SOAPRequest += "`t`t`t`t`t`t</metadata>`r`n"
    }
    $SOAPRequest += "`t`t`t`t`t</metadataList>`r`n"
    $SOAPRequest += "`t`t`t`t</metadata>`r`n"
    $SOAPRequest += "`t`t</v6:processCONTENTdm>`r`n"
    $SOAPRequest += "`t</soapenv:Body>`r`n"
    $SOAPRequest += "</soapenv:Envelope>"

    Write-Debug $SOAPRequest

    Write-Debug "Send the SOAP XML for $dmrecord"
    Write-Output "$(. Get-TimeStamp) SOAP XML created for dmrecord $dmrecord, sending it to Catcher..." | Tee-Object -Filepath $log_batchEdit -Append

    Try {
        $editCount++
        . Send-SOAPRequest -SOAPRequest $SOAPRequest -URL https://worldcat.org/webservices/contentdm/catcher?wsdl -editCount $editCount 2>&1 | Tee-Object -Filepath $log_batchEdit -Append
    } Catch {
        $editCount--
        Write-Error "$(. Get-TimeStamp) Error occured, dmrecord $dmrecord not updated." 2>&1  | Tee-Object -Filepath $log_batchEdit -Append
        Write-Error $_ 2>&1 | Tee-Object -Filepath $log_batchEdit -Append
        #Write-Host "ERROR ERROR ERROR" -Fore "red" | Tee-Object -file $log_batchEdit -Append
    }

    Write-Output "---------------------" | Tee-Object -file $log_batchEdit -Append
}
# Cleanup the tmp files
#Remove-Item "$cdmt_root\tmp*.csv" -Force -ErrorAction SilentlyContinue | Out-Null

Write-Output "----------------------------------------------" | Tee-Object -file $log_batchEdit -Append
Write-Output "$(. Get-TimeStamp) CONTENTdm Tools Batch Edit Complete." | Tee-Object -file $log_batchEdit -Append
Write-Output "Collection Alias: $collection" | Tee-Object -file $log_batchEdit -Append
Write-Output "Batch Log: $log_batchEdit" | Tee-Object -file $log_batchEdit -Append
Write-Output "Edits to Send:         $($metadata.count)" | Tee-Object -file $log_batchEdit -Append
Write-Output "Edits Sent:            $i" | Tee-Object -file $log_batchEdit -Append
Write-Output "Edits Initiated:       $editCount" | Tee-Object -file $log_batchEdit -Append
Write-Output "---------------------------------------------" | Tee-Object -file $log_batchEdit -Append
if (($($metadata.count) -ne $i) -or ($($metadata.count) -ne $editCount) -or ($i -ne $editCount)) {
    Write-Warning "Warning: Check the above report and log, there is a missmatch in the final numbers." | Tee-Object -file $log_batchEdit -Append
    Write-Output "Warning: Check the above report and log, there is a missmatch in the final numbers." >> $log_batchEdit
}
Write-Host -ForegroundColor Green "Unless it is being used within batchOCR, this window can be closed at anytime. Don't forget to index the collection!"