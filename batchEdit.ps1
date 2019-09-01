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
Write-Output "Collection Alias:`t$collection" | Tee-Object -file $log_batchEdit -Append
Write-Output "Server URL:`t`t$server" | Tee-Object -file $log_batchEdit -Append
Write-Output "License No.:`t`t$license" | Tee-Object -file $log_batchEdit -Append
Write-Output "Metadata CSV:`t`t$csv" | Tee-Object -file $log_batchEdit -Append
Write-Output "CONTENTdm User:`t`t$user" | Tee-Object -file $log_batchEdit -Append
Write-Output ("Executed Command:`t"+$MyInvocation.Line) | Tee-Object -FilePath $log_batchEdit -Append
Write-Output "----------------------------------------------" | Tee-Object -file $log_batchEdit -Append

# Read in the stored org settings to use if no server or license parameters were supplied.
Write-verbose "Test for existing organizational settings; if they exist, import server and license values."
if (Test-Path $cdmt_root\settings\org.csv) {
    $org = $(. Get-Org-Settings)
    if (!($server) -or ($null -eq $server)) {
        $server = $org.server
    }
    if (!($license) -or ($null -eq $license)) {
        $license = $org.license
    }
}

Write-Verbose "Lookup stored user credentials, request if not available."
# Check for stored user password, if not available get user input.
$pw = $(. Get-User-Settings -user $user)

# Read in the metadata, add Level column to sort, lookup type, sort rows so Objects are first.
Write-Verbose "Import $csv and read the headers."
Write-Output "$(. Get-TimeStamp) Reading in the metadata and grouping compound-objects first." | Tee-Object -file $log_batchEdit -Append
$metadata = Import-Csv -Path "$csv"
$headers = ($metadata[0].psobject.Properties).Name

Write-Verbose "Lookup collection field properties with CONTENTdm API and map field names to nick names, if necessary."
$props = Invoke-RestMethod "$server/dmwebservices/index.php?q=dmGetCollectionFieldInfo/$collection/json"

foreach ($prop in $props) {
    if ($prop.name -in $headers) {
        foreach ($header in $headers) {
            if ($header -eq $prop.name) {
                $headers = $headers -replace "$header", "$($prop.nick)"
            }
        }
    }
}

Write-Verbose "Re-import metadata with the updated headers (nicknames)."
$metadata = Import-Csv -Path "$csv" -Header $headers | Select-Object -Skip 1

Write-Verbose "Call the CONTENTdm API for each item to determine its type."
foreach ($record in $metadata) {
    $dmrecord = $record.dmrecord
    $itemInfo = Invoke-RestMethod "$server/dmwebservices/index.php?q=dmGetItemInfo/$collection/$dmrecord/json"
    $itemFile = $itemInfo.find
    $itemType = $itemFile.Substring($itemFile.Length - 3, 3)
    if ($itemType -eq "cpd") {
        #$record.Level = "Object"
        $record | Add-Member -NotePropertyName Level -NotePropertyValue "Object"
    }
    elseif ($itemType -ne "cpd") {
        #$record.Level = "Item"
        $record | Add-Member -NotePropertyName Level -NotePropertyValue "Item"
    }
}

$metadata2 = New-TemporaryFile
$metadata | Export-Csv $metadata2 -NoTypeInformation

Write-Verbose "Group compound objects first in the metadata to feed to Catcher."
$metadata3 = New-TemporaryFile
$metadata = Import-Csv -Path $metadata2
$metadata | Sort-Object -Property Level -Descending | Export-Csv $metadata3 -NoTypeInformation
$metadata = Import-Csv -Path $metadata3

Write-Verbose "$(. Get-TimeStamp) Processing each metadata update for CONTENTdm Catcher." | Tee-Object -file $log_batchEdit -Append
Write-Debug "Establish the loop for building SOAP XML for each update."
ForEach ($record in $metadata) {
    $dmrecord = $record.dmrecord
    Write-Debug "Building the SOAP for $dmrecord"
    $i++
    Write-Progress -Activity "Batch Edit" -Status "Sending metadata edits to CONTENTdm Catcher" -CurrentOperation "Sending dmrecord $($collection + "_" + $dmrecord), $i of $($metadata.count)" -PercentComplete ($i / $metadata.count * 100)
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
        . Send-SOAPRequest -SOAPRequest $SOAPRequest -URL https://worldcat.org/webservices/contentdm/catcher?wsdl -editCount $editCount 2>&1 | Tee-Object -Filepath $log_batchEdit -Append
        $editCount++
    }
    Catch {
        $editCount--
        Write-Error "$(. Get-TimeStamp) Error occured, dmrecord $dmrecord not updated." 2>&1 | Tee-Object -Filepath $log_batchEdit -Append
        Write-Error $_ 2>&1 | Tee-Object -Filepath $log_batchEdit -Append
        #Write-Host "ERROR ERROR ERROR" -Fore "red" | Tee-Object -file $log_batchEdit -Append
    }

    Write-Output "---------------------" | Tee-Object -file $log_batchEdit -Append
}

# Cleanup the tmp files
Remove-Item $metadata2 -Force
Remove-Item $metadata3 -Force

Write-Output "----------------------------------------------" | Tee-Object -file $log_batchEdit -Append
Write-Output "$(. Get-TimeStamp) CONTENTdm Tools Batch Edit Complete." | Tee-Object -file $log_batchEdit -Append
Write-Output "Collection Alias: $collection" | Tee-Object -file $log_batchEdit -Append
Write-Output "Batch Log: $log_batchEdit" | Tee-Object -file $log_batchEdit -Append
Write-Output "Edits for Batch Edit:  $($metadata.count)" | Tee-Object -file $log_batchEdit -Append
Write-Output "                     -----"
Write-Output "Edits Sent:            $i" | Tee-Object -file $log_batchEdit -Append
Write-Output "Errors:                ($($metadata.count - $editCount))"
Write-Output "                     -----"
Write-Output "Edits Initiated:       $editCount" | Tee-Object -file $log_batchEdit -Append
Write-Output "---------------------------------------------" | Tee-Object -file $log_batchEdit -Append
if (($($metadata.count) -ne $i) -or ($($metadata.count) -ne $editCount) -or ($i -ne $editCount)) {
    Write-Warning "Warning: Check the above report and log, there is a missmatch in the final numbers." | Tee-Object -file $log_batchEdit -Append
    Write-Output "Warning: Check the above report and log, there is a missmatch in the final numbers." >> $log_batchEdit
}
Write-Host -ForegroundColor Green "Unless it is being used within Batch OCR, this window can be closed at anytime. Don't forget to index the collection!"