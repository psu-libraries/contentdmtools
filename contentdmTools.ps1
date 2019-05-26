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
$createBatchButton.location      = New-Object System.Drawing.Point(24,103)
$createBatchButton.Font          = 'Microsoft Sans Serif,10,style=Bold'
$createBatchButton.ForeColor     = "#ffffff"

$createBatchPanel                = New-Object system.Windows.Forms.Panel
$createBatchPanel.height         = 180
$createBatchPanel.width          = 180
$createBatchPanel.location       = New-Object System.Drawing.Point(23,14)
$createBatchPanel.BackColor     = "#e0e0eb"

$batchPathButton                 = New-Object system.Windows.Forms.Button
$batchPathButton.BackColor       = "#1e407c"
$batchPathButton.text            = "Set Batch Path"
$batchPathButton.width           = 130
$batchPathButton.height          = 30
$batchPathButton.location        = New-Object System.Drawing.Point(19,40)
$batchPathButton.Font            = 'Microsoft Sans Serif,10,style=Bold'
$batchPathButton.ForeColor       = "#ffffff"

$processor                       = New-Object system.Windows.Forms.ComboBox
$processor.text                  = "ABBYY"
$processor.width                 = 130
$processor.height                = 20
@('ABBYY','ImageMagick') | ForEach-Object {[void] $processor.Items.Add($_)}
$processor.location              = New-Object System.Drawing.Point(18,15)
$processor.Font                  = 'Microsoft Sans Serif,10'

$deleteTIFF                      = New-Object system.Windows.Forms.CheckBox
$deleteTIFF.text                 = "Delete TIFFs"
$deleteTIFF.AutoSize             = $false
$deleteTIFF.width                = 77
$deleteTIFF.height               = 20
$deleteTIFF.location             = New-Object System.Drawing.Point(40,78)
$deleteTIFF.Font                 = 'Microsoft Sans Serif,10'

$batchEditPanel                  = New-Object system.Windows.Forms.Panel
$batchEditPanel.height           = 180
$batchEditPanel.width            = 180
$batchEditPanel.location         = New-Object System.Drawing.Point(218,14)
$batchEditPanel.BackColor     = "#e0e0eb"

$ToolTip1                        = New-Object system.Windows.Forms.ToolTip

$aliasInput                      = New-Object system.Windows.Forms.TextBox
$aliasInput.multiline            = $false
$aliasInput.text                 = "Collection Alias"
$aliasInput.width                = 130
$aliasInput.height               = 20
$aliasInput.location             = New-Object System.Drawing.Point(24,16)
$aliasInput.Font                 = 'Microsoft Sans Serif,10'
$aliasInput.ForeColor            = "#000000"

$metadataInput                   = New-Object system.Windows.Forms.TextBox
$metadataInput.multiline         = $false
$metadataInput.text              = "Metadata CSV"
$metadataInput.width             = 130
$metadataInput.height            = 20
$metadataInput.location          = New-Object System.Drawing.Point(25,47)
$metadataInput.Font              = 'Microsoft Sans Serif,10'

$batchEditMetadataButton         = New-Object system.Windows.Forms.Button
$batchEditMetadataButton.BackColor  = "#1e407c"
$batchEditMetadataButton.text    = "Batch Edit Metadata"
$batchEditMetadataButton.width   = 156
$batchEditMetadataButton.height  = 52
$batchEditMetadataButton.location  = New-Object System.Drawing.Point(10,103)
$batchEditMetadataButton.Font    = 'Microsoft Sans Serif,10,style=Bold'
$batchEditMetadataButton.ForeColor  = "#ffffff"

$ToolTip1.SetToolTip($metadataInput,'Default value: metadata.csv')
$createBatchPanel.controls.AddRange(@($createBatchButton,$batchPathButton,$processor,$deleteTIFF))
$CONTENTdmTools.controls.AddRange(@($createBatchPanel,$batchEditPanel))
$batchEditPanel.controls.AddRange(@($aliasInput,$metadataInput,$batchEditMetadataButton))

function Get-Arguments {
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

function Find-Folders {
    [Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $browse = New-Object System.Windows.Forms.FolderBrowserDialog
    $browse.SelectedPath = "C:\"
    $browse.ShowNewFolderButton = $false
    $browse.Description = "Select a directory"

    $loop = $true
    while($loop)
    {
        if ($browse.ShowDialog() -eq "OK")
        {
        $loop = $false

		$global:source = $browse.SelectedPath

        } else
        {
            $res = [System.Windows.Forms.MessageBox]::Show("You clicked Cancel. Would you like to try again or exit?", "Select a location", [System.Windows.Forms.MessageBoxButtons]::RetryCancel)
            if($res -eq "Cancel")
            {
                #Ends script
                return
            }
        }
    }
    $browse.SelectedPath
    $browse.Dispose()
}

$createBatchButton.Add_Click({
    Get-Arguments
    $script = ".\batchLoad\batchLoadCreate.ps1"
    $global:arguments = "$imageProc $tifProc -source " + '"' + $source+ '"'
    Write-Host "Start-Process $script $arguments"
    #Start-Process $script $arguments
 })

 $batchPathButton.Add_Click({
     Find-Folders
 })

 $CONTENTdmTools.ShowDialog()