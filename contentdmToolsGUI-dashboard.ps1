# contentdmToolsGUI-dashboard.ps1
# GUI for CONTENTdm Tools using Universal Dashboard


$theme = Get-UDTheme -Name 'Azure'

$dashboard = New-UDDashboard -Title "CONTENTdm Tools Dashboard" -Theme $theme -Content {
    New-UDLayout -Columns 2 -Content {
        New-UDInput -Title "Create Batch" -Id "createBatch" -Content {
            New-UDInputField -Type 'textbox' -Name 'source' -Placeholder 'C:\path\to\files'
            New-UDInputField -Type 'checkbox' -Name 'deltif' -Placeholder 'No'
        } -Endpoint {
            param($source, $deltif)
            $createBatch = .\batchLoad\batchLoadCreate.ps1 -im $deltif $source
            if ($createBatch)
            {
                New-UDInputAction -Content @(
                    New-UDCard -Title "Verify Batch Details" -Text "$createBatch"
                )
            }
            

        }
    }
}


Start-UDDashboard -Dashboard $dashboard -Port 1000 -AutoReload