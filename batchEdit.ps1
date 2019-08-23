# batchEdit.ps1
# https://github.com/psu-libraries/contentdmtools

# Read in the metadata changes with -csv path, pass the collection alias with -collection collectionAlias.
[cmdletbinding()]
param (
    [Parameter()]
    [string]$csv = "metadata.csv",

    [Parameter(Mandatory = $true)]
    [string]$user = $(Throw "Use -user to specify the CONTENTdm user."),

    [Parameter(Mandatory = $true)]
    [string]$collection = $(Throw "Use -collection to specify a collection."),

    [Parameter()]
    [string]$server,

    [Parameter()]
    [string]$license
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
#DEBUGGING
#Write-Output "CONTENTdm User:    $User" | Tee-Object -file $log_batchEdit -Append
#Write-Output "CONTENTdm Server:  $server" | Tee-Object -file $log_batchEdit -Append
#Write-Output "CONTENTdm License: $license" | Tee-Object -file $log_batchEdit -Append
Write-Output "----------------------------------------------" | Tee-Object -file $log_batchEdit -Append

# Read in the stored org settings to use if no server or license parameters were supplied.
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
} Else {
    Write-Output "No user settings file found. Enter a password below or store secure credentials using the dashboard." | Tee-Object -Filepath $log_batchEdit -Append
    [SecureString]$password = Read-Host "Enter $user's CONTENTdm password" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR([SecureString]$password)
    $pw = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    $null = $BSTR
}

# Read in the metadata, add Level column to sort, lookup type, sort rows so Objects are first.
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
$metadata | Select-Object *, @{Name = 'Level'; Expression = { '' } } | Export-CSV -Path "$cdmt_root\tmp1.csv" -NoTypeInformation
$metadata = Import-Csv -Path "$cdmt_root\tmp1.csv"


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
$metadata | Sort-Object -Property Level -Descending | Export-CSV $cdmt_root\tmp2.csv -NoTypeInformation
$metadata = Import-Csv -Path "$cdmt_root\tmp2.csv"

# Build and send the SOAP XML to CONTENTdm Catcher
ForEach ($record in $metadata) {
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

    $dmrecord = $record.dmrecord

    Write-Output "$(. Get-TimeStamp) SOAP XML created for dmrecord $dmrecord, sending it to Catcher..." | Tee-Object -Filepath $log_batchEdit -Append
    Try {
        . Send-SOAPRequest $SOAPRequest https://worldcat.org/webservices/contentdm/catcher?wsdl $editCount | Tee-Object -Filepath $log_batchEdit -Append; if ($? -eq $true) { $editCount++ }
        # DEBUGGING: Comment out the Send-SOAPRequest above and remove the comment from the two lines below to log soap. WARNING PASSWORDS EXPOSED
        #$soap = "$cdmt_root\logs\" + $collection + "_" + $record.dmrecord + ".xml"
        #Write-Output $SOAPRequest | Out-File -FilePath $soap
    }
    Catch {
        if ($? -eq $true) { $editCount=$editCount-1 }
        Write-Host "ERROR ERROR ERROR" -Fore "red" | Tee-Object -file $log_batchEdit -Append
        Write-Output $Return | Tee-Object -Filepath $log_batchEdit -Append
        Write-Output "---------------------" | Tee-Object -file $log_batchEdit -Append
        Write-Host "  $(. Get-TimeStamp) Unknown error, dmrecord $dmrecord not updated." -Fore "red" | Tee-Object -file $log_batchEdit -Append
        Write-Output "  $(. Get-TimeStamp) Unknown error, dmrecord $dmrecord not updated." | Out-File -Filepath $log_batchEdit -Append
    }
}

# Cleanup the tmp files
Remove-Item "$cdmt_root\tmp*.csv" -Force -ErrorAction SilentlyContinue | Out-Null

Write-Output "----------------------------------------------" | Tee-Object -file $log_batchEdit -Append
Write-Output "$(. Get-TimeStamp) CONTENTdm Tools Batch Edit Complete." | Tee-Object -file $log_batchEdit -Append
Write-Output "Collection Alias: $collection" | Tee-Object -file $log_batchEdit -Append
Write-Output "Batch Log: $log_batchEdit" | Tee-Object -file $log_batchEdit -Append
Write-Output "Records to be Edited:  $($metadata.count)" | Tee-Object -file $log_batchEdit -Append
Write-Output "Records Attempted:     $i" | Tee-Object -file $log_batchEdit -Append
Write-Output "Records Edited:        $editCount" | Tee-Object -file $log_batchEdit -Append
Write-Output "---------------------------------------------" | Tee-Object -file $log_batchEdit -Append
if (($($metadata.count) -ne $i) -or ($($metadata.count) -ne $editCount) -or ($i -ne $editCount)) {
    Write-Warning "Warning: Check the above report and log, there is a missmatch in the final numbers." | Tee-Object -file $log_batchEdit -Append
    Write-Output "Warning: Check the above report and log, there is a missmatch in the final numbers." >> $log_batchEdit
}
Write-Host -ForegroundColor Green "Unless it is being used within batchOCR, this window can be closed at anytime. Don't forget to index the collection!"