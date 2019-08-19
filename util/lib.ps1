function Get-Org-Settings {
    $Return = @{}
    if (Test-Path settings\org.csv) {
        $orgcsv = $(Resolve-Path settings\org.csv)
        $orgcsv = Import-Csv settings\org.csv
        foreach ($org in $orgcsv) {
            $Return.public = $org.public
            $Return.server = $org.server
            $Return.license = $org.license
            $Global:cdmt_public = $org.public
            $Global:cdmt_server = $org.server
            $Global:cdmt_license = $org.license
        }
    }
    Return $Return
}

#SOAP functions # https://ponderingthought.com/2010/01/17/execute-a-soap-request-from-powershell/
function Send-SOAPRequest (
    [Xml] $SOAPRequest,
    [String] $URL ) {
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

    if ($Return -contains "Error") { ForEach-Object { $j = $j - 1 } }
}

function Send-SOAPRequestFromFile (
    [String] $SOAPRequestFile,
    [String] $URL ) {
    write-host "Reading and converting file to XmlDocument: $SOAPRequestFile"
    $SOAPRequest = [Xml](Get-Content $SOAPRequestFile)

    return $(Execute-SOAPRequest $SOAPRequest $URL)
}

<# #Tracing images through IIIF
$collMan = Invoke-Restmethod https://digital.libraries.psu.edu/iiif/info/kirschner/manifest.json
$records = $collMan.manifests."@id" #records with images anyways
    $record = Invoke-RestMethod $imagesManifests[0]
        $recordId = ($record."@id").Substring(($record."@id").length-16,2)
        $images = $record.sequences.canvases.images.resource."@id"
            Invoke-WebRequest $images[0] -OutFile $recordId.jpg #>