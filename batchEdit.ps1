# batchEdit.ps1
# By Nathan Tallman, created in August 2018, heavily refactored in May 2019.
# https://github.com/psu-libraries/contentdmtools

# Read in the metadata changes with -csv path, pass the collection alias with -alias collectionAlias.
param (
    [Parameter()]
    [string]$csv = "metadata.csv",
    
    [Parameter(Mandatory=$true)]
    [string]$alias = $(Throw "Use -alias to specify a collection.")
 )

# Setup timestamps
function Get-TimeStamp { return "[{0:yyyy-MM-dd} {0:HH:mm:ss}]" -f (Get-Date) }

# Setup logs
If(!(Test-Path logs)) {New-Item -ItemType Directory -Path logs | Out-Null }
$log = ("logs\batchEdit_" + $alias + "_log_" + $(Get-Date -Format yyyyMMddTHHmmssffff) + ".txt")

# Setup credentials. Securely store the user, password and license on local machine so they don't have to be entered everytime.
Write-Output "Checking for stored user settings, will prompt and store if not found."
If(!(Test-Path settings)) {New-Item -ItemType Directory -Path settings | Out-Null }
$user = If(Test-Path settings/user.txt) {Get-Content "settings/user.txt"} else { Read-Host "Enter the CONTENTdm user" }
$user | Out-File settings/user.txt
$password = If(Test-Path settings/securePassword.txt) { Get-Content "settings/securePassword.txt" | ConvertTo-SecureString }
  else { Read-Host "Enter the CONTENTdm user password" -AsSecureString }
$password | ConvertFrom-SecureString | Out-File "settings/securePassword.txt"
$license = If(Test-Path settings/secureLicense.txt) { Get-Content "settings/secureLicense.txt" | ConvertTo-SecureString }
  else { Read-Host "Enter the license for CONTENTdm" -AsSecureString }
$license | ConvertFrom-SecureString | Out-File "settings/secureLicense.txt"

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
)
{
  write-host "Sending SOAP Request To Server: $URL"
  $soapWebRequest = [System.Net.WebRequest]::Create($URL)
  $soapWebRequest.ContentType = 'text/xml;charset="utf-8"'
  $soapWebRequest.Accept      = "text/xml"
  $soapWebRequest.Method      = "POST"

  write-host "Initiating Send."
  $requestStream = $soapWebRequest.GetRequestStream()
  $SOAPRequest.Save($requestStream)
  $requestStream.Close()

  write-host "Send Complete, Waiting For Response."
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
)
{
  write-host "Reading and converting file to XmlDocument: $SOAPRequestFile"
  $SOAPRequest = [Xml](Get-Content $SOAPRequestFile)

  return $(Execute-SOAPRequest $SOAPRequest $URL)
}

# Read in the metadata.
Write-Output "$(Get-Timestamp) Processing metadata edits into SOAP XML for catcher..." | Tee-Object -Filepath $log
Write-Output "---------------------" | Out-File -Filepath $log -Append
$metadata = Import-Csv -Path "$csv"
$headers = ($metadata[0].psobject.Properties).Name


# Build and send the SOAP XML to CONTENTdm Catcher
ForEach ($record in $metadata) {
$SOAPRequest = '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:v6="http://catcherws.cdm.oclc.org/v6.0.0/">' + "`r`n"
$SOAPRequest += "`t<soapenv:Header/>`r`n"
$SOAPRequest += "`t<soapenv:Body>`r`n"
$SOAPRequest += "`t`t<v6:processCONTENTdm>`r`n"
$SOAPRequest += "`t`t`t<action>edit</action>`r`n"
$SOAPRequest += "`t`t`t<cdmurl>http://server17287.contentdm.oclc.org:8888</cdmurl>`r`n"
$SOAPRequest += "`t`t`t<username>$user</username>`r`n"
$SOAPRequest += "`t`t`t<password>$pw</password>`r`n"
$SOAPRequest += "`t`t`t<license>$lc</license>`r`n"
$SOAPRequest += "`t`t`t<collection>$alias</collection>`r`n"
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

$soap = "logs/soap_" + $alias+ "_" + $record.dmrecord + ".xml"

Write-Output "  $(Get-Timestamp) SOAP XML created for $soap, sending it to Catcher..." | Tee-Object -Filepath $log -Append
  Try {
    Send-SOAPRequest $SOAPRequest https://worldcat.org/webservices/contentdm/catcher?wsdl | Tee-Object -Filepath $log -Append
    Write-Output $Return | Tee-Object -Filepath $log -Append
    # DEBUGGING: Comment out the Send-SOAPRequest and remove the comment from the line below to log soap. WARNING PASSWORDS EXPOSED
    #Write-Output $SOAPRequest | Out-File -FilePath $soap
  }
  Catch {
    Write-Host "ERROR ERROR ERROR" -Fore "red"
    Write-Output $Return | Tee-Object -Filepath $log -Append
    Write-Output "---------------------" | Out-File -Filepath $log -Append
    Write-HOST "  $(Get-Timestamp) Unknown error, $soap not sent" -Fore "red"
    Write-Output "  $(Get-Timestamp) Unknown error, $soap not sent" | Out-File -Filepath $log -Append
  }
}

Write-Output "---------------------" | Out-File -Filepath $log -Append
Write-Host "$(Get-Timestamp) Batch metadata changes are complete."
Write-Output "$(Get-Timestamp) Batch metadata changes are complete." | Out-File -Filepath $log -Append