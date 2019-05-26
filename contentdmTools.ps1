# Initial basic gui using PowerShell, does not work with PowerShell Core
# Nathan Tallman, May 2019


[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void] [System.Windows.Forms.Application]::EnableVisualStyles()


$CONTENTdmTools                  = New-Object system.Windows.Forms.Form
$CONTENTdmTools.ClientSize       = '400,289'
$CONTENTdmTools.text             = "CONTENTdm Tools"
$CONTENTdmTools.TopMost          = $false

$createBatchButton               = New-Object system.Windows.Forms.Button
$createBatchButton.BackColor     = "#1e407c"
$createBatchButton.text          = "Create Batch"
$createBatchButton.width         = 120
$createBatchButton.height        = 49
$createBatchButton.location      = New-Object System.Drawing.Point(19,79)
$createBatchButton.Font          = 'Microsoft Sans Serif,10,style=Bold'
$createBatchButton.ForeColor     = "#ffffff"

$createBatchPanel                = New-Object system.Windows.Forms.Panel
$createBatchPanel.height         = 152
$createBatchPanel.width          = 169
$createBatchPanel.location       = New-Object System.Drawing.Point(11,14)
$createBatchPanel.BackColor     = "#e0e0eb"

$processor                       = New-Object system.Windows.Forms.ComboBox
$processor.text                  = "ABBYY"
$processor.width                 = 129
$processor.height                = 20
@('ABBYY','ImageMagick') | ForEach-Object {[void] $processor.Items.Add($_)}
$processor.location              = New-Object System.Drawing.Point(18,15)
$processor.Font                  = 'Microsoft Sans Serif,10'

$deleteTIFF                      = New-Object system.Windows.Forms.CheckBox
$deleteTIFF.text                 = "Delete TIFFs"
$deleteTIFF.AutoSize             = $false
$deleteTIFF.width                = 77
$deleteTIFF.height               = 20
$deleteTIFF.location             = New-Object System.Drawing.Point(42,49)
$deleteTIFF.Font                 = 'Microsoft Sans Serif,10'

$batchEditPanel                  = New-Object system.Windows.Forms.Panel
$batchEditPanel.height           = 152
$batchEditPanel.width            = 169
$batchEditPanel.location         = New-Object System.Drawing.Point(218,13)
$batchEditPanel.BackColor     = "#e0e0eb"

$ToolTip1                        = New-Object system.Windows.Forms.ToolTip

$aliasInput                      = New-Object system.Windows.Forms.TextBox
$aliasInput.multiline            = $false
$aliasInput.text                 = "Collection Alias"
$aliasInput.width                = 129
$aliasInput.height               = 20
$aliasInput.location             = New-Object System.Drawing.Point(24,16)
$aliasInput.Font                 = 'Microsoft Sans Serif,10'
$aliasInput.ForeColor            = "#000000"

$metadataInput                   = New-Object system.Windows.Forms.TextBox
$metadataInput.multiline         = $false
$metadataInput.text              = "Metadata CSV"
$metadataInput.width             = 129
$metadataInput.height            = 20
$metadataInput.location          = New-Object System.Drawing.Point(25,47)
$metadataInput.Font              = 'Microsoft Sans Serif,10'

$batchEditMetadataButton         = New-Object system.Windows.Forms.Button
$batchEditMetadataButton.BackColor  = "#1e407c"
$batchEditMetadataButton.text    = "Batch Edit Metadata"
$batchEditMetadataButton.width   = 156
$batchEditMetadataButton.height  = 52
$batchEditMetadataButton.location  = New-Object System.Drawing.Point(8,82)
$batchEditMetadataButton.Font    = 'Microsoft Sans Serif,10,style=Bold'
$batchEditMetadataButton.ForeColor  = "#ffffff"

$ToolTip1.SetToolTip($metadataInput,'Default value: metadata.csv')
$createBatchPanel.controls.AddRange(@($createBatchButton,$processor,$deleteTIFF))
$CONTENTdmTools.controls.AddRange(@($createBatchPanel,$batchEditPanel))
$batchEditPanel.controls.AddRange(@($aliasInput,$metadataInput,$batchEditMetadataButton))

function getArguments {
    If($processor.Text -contains "ImageMagick") {
        $global:imageProc = '-im'
    }
    ElseIf($processor.Text -contains "ABBYY") {
        $global:imageProc = '-abbyy'
    } Else {
        $global:imageProc = $null
    }

    If($deleteTIFF.Checked  -eq $true) {
        $global:tifProc = '-deltif'
    } Else{
        $global:tifProc = $null
    }
}

$createBatchButton.Add_Click({
    getArguments
    $script = ".\batchLoad\batchLoadCreate.ps1"
    $global:arguments = "$imageProc $tifProc"
    #Write-Host "Start-Process $script $arguments"
    Start-Process $script $arguments
 })

 $CONTENTdmTools.ShowDialog()