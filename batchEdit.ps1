# batchEdit.ps1 1.0
# By Nathan Tallman, created in August 2018, updated August 2019.
# https://github.com/psu-libraries/contentdmtools

# Read in the metadata changes with -csv path, pass the collection alias with -collection collectionAlias.
param (
    [Parameter()]
    [string]$csv = "metadata.csv",
    
    [Parameter(Mandatory = $true)]
    [string]$collection = $(Throw "Use -collection to specify a collection."),

    [Parameter(Mandatory = $true)]
    [string]$server = $(Throw "Use -server to specify a url for the Admin UI.")
)

# Variables
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
If (!(Test-Path logs)) { New-Item -ItemType Directory -Path logs | Out-Null }
$log = ("$dir\logs\batchEdit_" + $collection + "_log_" + $(Get-Date -Format yyyy-MM-ddTHH-mm-ss-ffff) + ".txt")
function Get-TimeStamp { return "[{0:yyyy-MM-dd} {0:HH:mm:ss}]" -f (Get-Date) }

Write-Output "----------------------------------------------" | Tee-Object -file $log
Write-Output "$(Get-Timestamp) CONTENTdm Tools Batch Edit Starting." | Tee-Object -file $log -Append
Write-Output "Collection Alias: $collection"  | Tee-Object -file $log -Append
Write-Output "----------------------------------------------" | Tee-Object -file $log -Append

# Read in the metadata, add Level column to sort, lookup type, sort rows so Objects are first.
Write-Output "Reading in the metadata and sorting the compound objects first." | Tee-Object -file $log -Append
$metadata = Import-Csv -Path "$csv"
$headers = ($metadata[0].psobject.Properties).Name
$metadata | Select-Object *,@{Name='Level';Expression={''}} | Export-CSV -Path "$dir\tmp1.csv" -NoTypeInformation
$metadata = Import-Csv -Path "$dir\tmp1.csv"

foreach ($record in $metadata) {
    $dmrecord = $($record.dmrecord)
    $itemInfo = Invoke-RestMethod "$server/dmwebservices/index.php?q=dmGetItemInfo/$collection/$dmrecord/json"
    $itemFile = $($itemInfo.find)
    $itemType = $itemFile.Substring($itemFile.Length - 3, 3)
    if ($itemType -eq "cpd") {
        $record.Level = "Object"
    } elseif ($itemType -ne "cpd") {
        $record.Level = "Item"
    }
}

$metadata | Sort-Object -Property Level -Descending| Export-CSV $dir\tmp2.csv -NoTypeInformation
$metadata = Import-Csv -Path "$dir\tmp2.csv"

# Setup credentials. Securely store the user, password and license on local machine so they don't have to be entered everytime.
Write-Host "Checking for stored user settings, will prompt and store if not found."
If (!(Test-Path "$dir\settings")) { New-Item -ItemType Directory -Path "$dir\settings" | Out-Null }
$user = If (Test-Path "$dir\settings\user.txt") { Get-Content "$dir\settings\user.txt" } else { Read-Host "Enter the CONTENTdm user" }
$user | Out-File "$dir\settings\user.txt"
Write-Output "CONTENTdm User: $user" >> $log
$password = If (Test-Path "$dir\settings\securePassword.txt") { Get-Content "$dir\settings\securePassword.txt" | ConvertTo-SecureString }
else { Read-Host "Enter the CONTENTdm user password" -AsSecureString }
$password | ConvertFrom-SecureString | Out-File "$dir\settings\securePassword.txt"
$license = If (Test-Path "$dir\settings/secureLicense.txt") { Get-Content "$dir\settings\secureLicense.txt" | ConvertTo-SecureString }
else { Read-Host "Enter the license for CONTENTdm" -AsSecureString }
$license | ConvertFrom-SecureString | Out-File "$dir\settings\secureLicense.txt"

$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
$pw = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
$BSTR = $null

$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($license)
$lc = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
$BSTR = $null

# Setup SOAP functions # https://ponderingthought.com/2010/01/17/execute-a-soap-request-from-powershell/
function Send-SOAPRequest
(
    [Xml] $SOAPRequest,
    [String] $URL
) {
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
}

function Send-SOAPRequestFromFile
(
    [String] $SOAPRequestFile,
    [String] $URL
) {
    write-host "Reading and converting file to XmlDocument: $SOAPRequestFile"
    $SOAPRequest = [Xml](Get-Content $SOAPRequestFile)

    return $(Execute-SOAPRequest $SOAPRequest $URL)
}

# Build and send the SOAP XML to CONTENTdm Catcher
$i = 0
$j = 0
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
    $SOAPRequest += "`t`t`t<license>$lc</license>`r`n"
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

    $soap = "$dir\logs\soap_" + $collection + "_" + $record.dmrecord + ".xml"

    $dmrecord = $record.dmrecord

    Write-Output "$(Get-Timestamp) SOAP XML created for dmrecord $dmrecord, sending it to Catcher..." | Tee-Object -Filepath $log -Append
  
    Try {
        $j++
        Send-SOAPRequest $SOAPRequest https://worldcat.org/webservices/contentdm/catcher?wsdl | Tee-Object -Filepath $log -Append
        # DEBUGGING: Comment out the Send-SOAPRequest and remove the comment from the line below to log soap. WARNING PASSWORDS EXPOSED
        #Write-Output $SOAPRequest | Out-File -FilePath $soap
    }
    Catch {
        $j--
        Write-Host "ERROR ERROR ERROR" -Fore "red" | Tee-Object -file $log -Append
        Write-Output $Return | Tee-Object -Filepath $log -Append
        Write-Output "---------------------" | Tee-Object -file $log -Append
        Write-HOST "  $(Get-Timestamp) Unknown error, dmrecord $dmrecord not updated." -Fore "red" | Tee-Object -file $log -Append
        Write-Output "  $(Get-Timestamp) Unknown error, dmrecord $dmrecord not updated." | Out-File -Filepath $log -Append
    }
}

# Cleanup the tmp files
Remove-Item "$dir\tmp*.csv" -Force -ErrorAction SilentlyContinue | Out-Null

Write-Output "----------------------------------------------" | Tee-Object -file $log -Append
Write-Output "$(Get-Timestamp) CONTENTdm Tools Batch Edit Complete." | Tee-Object -file $log -Append
Write-Output "Collection Alias: $collection"  | Tee-Object -file $log -Append
Write-Output "Batch Log: $log" | Tee-Object -file $log -Append
Write-Output "Records to be Edited:  $($metadata.count)" | Tee-Object -file $log -Append
Write-Output "Records Attempted:     $i" | Tee-Object -file $log -Append
Write-Output "Records Edited:        $j" | Tee-Object -file $log -Append
Write-Output "---------------------------------------------" | Tee-Object -file $log -Append
if (($($metadata.count) -ne $i) -or ($($metadata.count) -ne $j) -or ($i -ne $j)) {
  Write-Warning "Warning: Check the above report and log, there is a missmatch in the final numbers." | Tee-Object -file $log -Append
  Write-Output "Warning: Check the above report and log, there is a missmatch in the final numbers." >> $log
}
Write-Host -ForegroundColor Yellow "Unless it is being used within batchReOCR, this window can be closed at anytime. Don't forget to index the collection!"