# Initial basic gui using PowerShell, does not work with PowerShell Core
# Nathan Tallman, May 2019

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[System.Windows.Forms.Application]::EnableVisualStyles()

$CONTENTdmTools = New-Object system.Windows.Forms.Form
$CONTENTdmTools.ClientSize = '640,480'
$CONTENTdmTools.text = "CONTENTdm Tools"
$CONTENTdmTools.TopMost = $false

$createBatchButton = New-Object system.Windows.Forms.Button
$createBatchButton.BackColor = "#1e407c"
$createBatchButton.text = "Create Batch"
$createBatchButton.width = 119
$createBatchButton.height = 49
$createBatchButton.location = New-Object System.Drawing.Point(145, 71)
$createBatchButton.Font = 'Microsoft Sans Serif,10,style=Bold'
$createBatchButton.ForeColor = "#ffffff"

$createBatchPanel = New-Object system.Windows.Forms.Panel
$createBatchPanel.height = 175
$createBatchPanel.width = 275
$createBatchPanel.location = New-Object System.Drawing.Point(26, 13)

$processor = New-Object system.Windows.Forms.ComboBox
$processor.text = "ABBYY"
$processor.width = 120
$processor.height = 40
@('ABBYY', 'ImageMagick') | ForEach-Object { [void] $processor.Items.Add($_) }
$processor.location = New-Object System.Drawing.Point(9, 9)
$processor.Font = 'Microsoft Sans Serif,10'

$deleteTIFF = New-Object system.Windows.Forms.CheckBox
$deleteTIFF.text = "Delete TIFFs"
$deleteTIFF.width = 120
$deleteTIFF.height = 20
$deleteTIFF.location = New-Object System.Drawing.Point(141, 12)
$deleteTIFF.Font = 'Microsoft Sans Serif,10'

$batchEditPanel = New-Object system.Windows.Forms.Panel
$batchEditPanel.height = 175
$batchEditPanel.width = 275
$batchEditPanel.location = New-Object System.Drawing.Point(340, 12)

$aliasInput = New-Object system.Windows.Forms.TextBox
$aliasInput.multiline = $false
$aliasInput.text = "collectionAlias"
$aliasInput.width = 150
$aliasInput.height = 20
$aliasInput.location = New-Object System.Drawing.Point(13, 9)
$aliasInput.Font = 'Microsoft Sans Serif,10'
$aliasInput.ForeColor = "#000000"

$metadataInput = New-Object system.Windows.Forms.TextBox
$metadataInput.multiline = $false
$metadataInput.text = "C:\path\to\metadata.csv"
$metadataInput.width = 255
$metadataInput.height = 20
$metadataInput.location = New-Object System.Drawing.Point(13, 44)
$metadataInput.Font = 'Microsoft Sans Serif,10'

$batchEditButton = New-Object system.Windows.Forms.Button
$batchEditButton.BackColor = "#1e407c"
$batchEditButton.text = "Batch Edit"
$batchEditButton.width = 119
$batchEditButton.height = 49
$batchEditButton.location = New-Object System.Drawing.Point(149, 71)
$batchEditButton.Font = 'Microsoft Sans Serif,10,style=Bold'
$batchEditButton.ForeColor = "#ffffff"

$batchPathButton = New-Object system.Windows.Forms.Button
$batchPathButton.BackColor = "#1e407c"
$batchPathButton.text = "Set Batch Path"
$batchPathButton.width = 116
$batchPathButton.height = 33
$batchPathButton.location = New-Object System.Drawing.Point(10, 76)
$batchPathButton.Font = 'Microsoft Sans Serif,10,style=Bold'
$batchPathButton.ForeColor = "#ffffff"

$batchPathTextBox = New-Object system.Windows.Forms.TextBox
$batchPathTextBox.multiline = $false
$batchPathTextBox.text = "E:\path\to\batch"
$batchPathTextBox.width = 255
$batchPathTextBox.height = 20
$batchPathTextBox.location = New-Object System.Drawing.Point(9, 44)
$batchPathTextBox.Font = 'Microsoft Sans Serif,10'

$createBatchVendedPanel = New-Object system.Windows.Forms.Panel
$createBatchVendedPanel.height = 133
$createBatchVendedPanel.width = 275
$createBatchVendedPanel.location = New-Object System.Drawing.Point(26, 220)

$createBatchPanelLabel = New-Object system.Windows.Forms.Label
$createBatchPanelLabel.text = "In-House"
$createBatchPanelLabel.AutoSize = $true
$createBatchPanelLabel.width = 25
$createBatchPanelLabel.height = 10
$createBatchPanelLabel.location = New-Object System.Drawing.Point(76, 134)
$createBatchPanelLabel.Font = 'Microsoft Sans Serif,20,style=Bold'
$createBatchPanelLabel.ForeColor = "#1e407c"

$createBatchVendedPanelLabel = New-Object system.Windows.Forms.Label
$createBatchVendedPanelLabel.text = "Vended"
$createBatchVendedPanelLabel.AutoSize = $true
$createBatchVendedPanelLabel.width = 25
$createBatchVendedPanelLabel.height = 10
$createBatchVendedPanelLabel.location = New-Object System.Drawing.Point(78, 97)
$createBatchVendedPanelLabel.Font = 'Microsoft Sans Serif,20,style=Bold'
$createBatchVendedPanelLabel.ForeColor = "#1e407c"

$batchVendedPathTextBox = New-Object system.Windows.Forms.TextBox
$batchVendedPathTextBox.multiline = $false
$batchVendedPathTextBox.text = "E:\path\to\batch"
$batchVendedPathTextBox.width = 255
$batchVendedPathTextBox.height = 20
$batchVendedPathTextBox.location = New-Object System.Drawing.Point(9, 9)
$batchVendedPathTextBox.Font = 'Microsoft Sans Serif,10'

$batchVendedPathButton = New-Object system.Windows.Forms.Button
$batchVendedPathButton.BackColor = "#1e407c"
$batchVendedPathButton.text = "Set Batch Path"
$batchVendedPathButton.width = 116
$batchVendedPathButton.height = 33
$batchVendedPathButton.location = New-Object System.Drawing.Point(9, 41)
$batchVendedPathButton.Font = 'Microsoft Sans Serif,10,style=Bold'
$batchVendedPathButton.ForeColor = "#ffffff"

$createBatchVendedButton = New-Object system.Windows.Forms.Button
$createBatchVendedButton.BackColor = "#1e407c"
$createBatchVendedButton.text = "Create Batch"
$createBatchVendedButton.width = 119
$createBatchVendedButton.height = 49
$createBatchVendedButton.location = New-Object System.Drawing.Point(145, 34)
$createBatchVendedButton.Font = 'Microsoft Sans Serif,10,style=Bold'
$createBatchVendedButton.ForeColor = "#ffffff"

$batchEditLabel = New-Object system.Windows.Forms.Label
$batchEditLabel.text = "Batch Edit"
$batchEditLabel.AutoSize = $true
$batchEditLabel.width = 25
$batchEditLabel.height = 10
$batchEditLabel.location = New-Object System.Drawing.Point(76, 134)
$batchEditLabel.Font = 'Microsoft Sans Serif,20,style=Bold'
$batchEditLabel.ForeColor = "#1e407c"

$metadataPathButton = New-Object system.Windows.Forms.Button
$metadataPathButton.BackColor = "#1e407c"
$metadataPathButton.text = "Choose CSV"
$metadataPathButton.width = 116
$metadataPathButton.height = 33
$metadataPathButton.location = New-Object System.Drawing.Point(13, 76)
$metadataPathButton.Font = 'Microsoft Sans Serif,10,style=Bold'
$metadataPathButton.ForeColor = "#ffffff"

$name = New-Object system.Windows.Forms.Label
$name.text = "PennState CONTENTdm Tools"
$name.AutoSize = $true
$name.width = 25
$name.height = 10
$name.location = New-Object System.Drawing.Point(26, 391)
$name.Font = 'Microsoft Sans Serif,30,style=Bold'
$name.ForeColor = "#1e407c"

$versionLabel = New-Object system.Windows.Forms.Label
$versionLabel.text = "Version: 0.9"
$versionLabel.AutoSize = $true
$versionLabel.width = 25
$versionLabel.height = 10
$versionLabel.location = New-Object System.Drawing.Point(31, 442)
$versionLabel.Font = 'Microsoft Sans Serif,10'

$exitButton                      = New-Object system.Windows.Forms.Button
$exitButton.BackColor            = "#d0021b"
$exitButton.text                 = "EXIT"
$exitButton.width                = 80
$exitButton.height               = 60
$exitButton.location             = New-Object System.Drawing.Point(500,230)
$exitButton.Font                 = 'Microsoft Sans Serif,10,style=Bold'
$exitButton.ForeColor            = "#ffffff"

$cancelButton                    = New-Object system.Windows.Forms.Button
$cancelButton.BackColor          = "#f5a623"
$cancelButton.text               = "CANCEL"
$cancelButton.width              = 80
$cancelButton.height             = 60
$cancelButton.location           = New-Object System.Drawing.Point(375,230)
$cancelButton.Font               = 'Microsoft Sans Serif,10,style=Bold'
$cancelButton.ForeColor          = "#ffffff"

$createBatchPanel.controls.AddRange(@($createBatchButton, $processor, $deleteTIFF, $batchPathButton, $batchPathTextBox, $createBatchPanelLabel))
$CONTENTdmTools.controls.AddRange(@($createBatchPanel, $batchEditPanel, $createBatchVendedPanel, $name, $versionLabel,$exitButton,$cancelButton))
$batchEditPanel.controls.AddRange(@($aliasInput, $metadataInput, $batchEditButton, $batchEditLabel, $metadataPathButton))
$createBatchVendedPanel.controls.AddRange(@($createBatchVendedPanelLabel, $batchVendedPathTextBox, $batchVendedPathButton, $createBatchVendedButton))

function Get-Local-Arguments {
    If ($processor.Text -contains "ImageMagick") {
        $global:imageProc = '-im'
    }
    ElseIf ($processor.Text -contains "ABBYY") {
        $global:imageProc = '-abbyy'
    }
    Else {
        $global:imageProc = $null
    }

    If ($deleteTIFF.Checked -eq $true) {
        $global:tifProc = '-deltif'
    }
    Else {
        $global:tifProc = $null
    }
}

function Find-Folders {
    $browse = New-Object System.Windows.Forms.FolderBrowserDialog
    $browse.SelectedPath = "C:\"
    $browse.ShowNewFolderButton = $false
    $browse.Description = "Select a directory"
    $loop = $true
    while ($loop) {
        if ($browse.ShowDialog() -eq "OK") {
            $loop = $false
            $global:source = $browse.SelectedPath
            $batchPathTextBox.text = $browse.SelectedPath
            $batchVendedPathTextBox.text = $browse.SelectedPath
        }
        else {
            $res = [System.Windows.Forms.MessageBox]::Show("You clicked Cancel. Would you like to try again or exit?", "Select a location", [System.Windows.Forms.MessageBoxButtons]::RetryCancel)
            if ($res -eq "Cancel") {
                #Ends script
                return
            }
        }
    }
    $browse.SelectedPath
    $browse.Dispose()
}

function Find-CSV {
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog
    $FileBrowser.ShowDialog()
    $file = $FileBrowser.FileName;
    $global:source = "$file"
    $metadataInput.text = "$file"
}

$createBatchButton.Add_Click( {
        $script = ".\batchLoad\batchLoadCreate.ps1"
        Get-Local-Arguments
        $global:arguments = "$global:imageProc $global:tifProc -source " + '"' + $global:source + '"'
        #Write-Host "$global:proc = Start-Process $script $global:arguments -PassThru"
        $global:proc = Start-Process $script $global:arguments -PassThru
    })

$batchPathButton.Add_Click( {
        Find-Folders
    })

$createBatchVendedButton.Add_Click( {
        $script = ".\batchLoadMisc\batchLoadCLIR.ps1"
        $global:arguments = "-source " + '"' + $global:source + '"'
        #Write-Host "$global:proc = Start-Process $script $global:arguments -PassThru"
        $global:proc = Start-Process $script $global:arguments -PassThru
    })

$batchVendedPathButton.Add_Click( {
        Find-Folders
    })

$batchEditButton.Add_Click( {
        $script = ".\batchEdit\batchEdit.ps1"
        $global:arguments = "-csv " + '"' + $global:source + '"' + " -alias " + $aliasInput.text
        #Write-Host "$global:proc = Start-Process $script $global:arguments -PassThru"
        $global:proc = Start-Process $script $global:arguments -PassThru
    })

$metadataPathButton.Add_Click( {
        Find-CSV
    })

$cancelButton.Add_Click( {
        Stop-Process -Id $global:proc.Id
    })

$exitButton.Add_Click( {
        $CONTENTdmTools.Dispose()
    })

$CONTENTdmTools.ShowDialog()