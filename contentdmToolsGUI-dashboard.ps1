# contentdmToolsGUI-dashboard.ps1
# GUI for CONTENTdm Tools using Universal Dashboard


$theme = Get-UDTheme -Name "DarkDefault"

$HomePage = New-UDPage -Name "Home" -Content {
    New-UDLayout -Columns 2 -Content {
        New-UDCard -Title "Getting Started" -Content {
            New-UDParagraph -Color "White" -Text "CONTENTdm Tools is a set of PowerShell scripts to assist in building and managing CONTENTdm digital collections. These command line scripts can be run using this web dashboard. Use the menu in the upper-left corner to begin using CONTENTdm Tools. Full documentation for the command line tools, which provides details on the processing is available on the right."
        }
        New-UDCard -Title "Documentation" -Content {
            New-UDHtml -Markup '<ul><li><a href="https://github.com/psu-libraries/contentdmtools/blob/community/docs/batchCreateCompoundObjects.md" target="_blank" alt="Documentation for Batch Create Compound Objects">Batch Create Compound Objects<a/></li><li><a href="https://github.com/psu-libraries/contentdmtools/blob/community/docs/batchEdit.md" target="_blank" alt="Documentation for Batch Edit Metadata">Batch Edit Metadata</a></li><li><a href="https://github.com/psu-libraries/contentdmtools/blob/community/docs/batchReOCR.md" target="_blank" alt="Documentation for Batch Re-OCR">Batch Re-OCR</a></li></ul>'
        }
        New-UDCard -Title "Contributing" -Content {
            New-UDParagraph -Color "White" -Text "CONTENTdm Tools is an open-source project, a link to the GitHub repository is available on the navigation menu. If you have PowerShell scripts you would like to contribute to the toolkit, please submit a pull request!"
        }
        New-UDCard -Title "Support" -Content {
            New-UDParagraph -Color "White" -Text "CONTENTdm Tools was created by Nathan Tallman at Penn State University. Ability to provide support is limited, as is the ability to add new features, but some things may be possible. Contact Nathan at ntt7@psu.edu with questions, comments, and requests."
        }
    }
}

$Start = New-UDPage -Name "Start Batch Tasks" -Content {
    New-UDLayout -Columns 1 -Content {
        New-UDInput -Title "Create Batch of Compound Objects" -Id "createBatch" -Content {
            New-UDInputField -Type 'textbox' -Name 'metadata' -Placeholder 'metadata.csv' -DefaultValue 'metadata.csv'
            New-UDInputField -Type 'select' -Name 'jp2' -Placeholder @("JP2 Output", "No JP2 Output", "Skip") -Values @("true", "false", "skip") -DefaultValue "true"
            New-UDInputField -Type 'select' -Name 'ocr' -Placeholder @("TXT Output Only", "PDF Output Only", "TXT and PDF Output", "Skip") -Values @("text", "pdf", "both", "skip") -DefaultValue "both"
            New-UDInputField -Type 'select' -Name 'originals' -Placeholder @("Keep Originals", "Discard Origianls", "Skip") -Values @("keep", "discard", "skip") -DefaultValue "keep"
            New-UDInputField -Type 'textbox' -Name 'path' -Placeholder 'C:\path\to\files'
        } -Endpoint {
            Param($metadata, $jp2, $ocr, $originals, $path)       
            $createBatch = .\batchCreateCompoundObjects.ps1 -metadata $metadata -jp2 $jp2 -ocr $ocr -originals $originals -path $path
            if ($createBatch) {
                New-UDInputAction -Content @(
                    New-UDcard -Title "Batch Create Compound Objects Log" -Text "$createBatch" -TextAlignment left
                )
            }
        }
    }

    New-UDLayout -Columns 1 -Content {
        New-UDInput -Title "Batch Edit Metadata" -Id "batchEdit" -Content {
            New-UDInputField -Type 'textbox' -Name 'metadata' -Placeholder 'Metadata CSV' -DefaultValue 'metadata.csv'
            New-UDInputField -Type 'textbox' -Name 'collection' -Placeholder 'Collection Alias'
        } -Endpoint {
            Param($metadata, $collection)
            $batchEdit = .\batchEdit.ps1 -metadata $metadata -collection $collection
            if ($batchEdit) {
                New-UDInputAction -Content @(
                    New-UDCard -Title "Batch Edit Metadata Log" -Text "$batchEdit" -TextAlignment left
                )
            }
        }
    }

    New-UDLayout -Columns 1 -Content {
        New-UDInput -Title "Batch Re-OCR a Collection" -Id "batchReOCR" -Content {
            New-UDInputField -Type 'textbox' -Name 'collection' -Placeholder 'Collection Alias'
            New-UDInputField -Type 'textbox' -Name 'field' -Placeholder 'Fulltext Field'
            New-UDInputField -Type 'textbox' -Name 'public' -Placeholder 'URL for Public UI'
            New-UDInputField -Type 'textbox' -Name 'server' -Placeholder 'URL for Admin UI'
        } -Endpoint {
            Param($collection, $field, $public, $server)
            Invoke-Expression -Command ".\batchReOCR.ps1 -collection $collection -field $field -public $public -server $server" -OutVariable out | Out-String -OutVariable out
            New-UDInputAction -Toast "Batch OCR Started"
            New-UDInputAction -Content @(
                New-UDCard -Title "Batch Re-OCR Log" -Text "$out" -TextAlignment "left" -BackgroundColor "black" -FontColor "white" -Size "large"
            )
          }
        }
            
}

$Manage = New-UDPage -Name "Manage Batches" -Content {
    
}

$Monitor = New-UDPage -Name "Monitors" -Icon link -Content {  
    New-UDRow -Columns {
        New-UDColumn -Size 3 -Content { }
        New-UDColumn -Size 6 -Content {              
            New-UDMonitor -Title "Downloads per second" -Type Line  -Endpoint {
                Get-Random -Minimum 0 -Maximum 10 | Out-UDMonitorData
            } -ChartBackgroundColor '#59FF681B' -ChartBorderColor '#FFFF681B' -BackgroundColor "#252525" -FontColor "#FFFFFF"
        }
    }
    New-UDRow -Columns {
        New-UDColumn -Size 3 -Content { }
        New-UDColumn -Size 6 -Content {              
            New-UdMonitor -Title "Network (IO Read Bytes/sec)" -Type Line -DataPointHistory 20 -RefreshInterval 5 -ChartBackgroundColor '#80E8611D' -ChartBorderColor '#FFE8611D'  -Endpoint {
                Get-Counter '\Process(_Total)\IO Read Bytes/sec' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty CounterSamples | Select-Object -ExpandProperty CookedValue | Out-UDMonitorData
            }
        }
    }
    New-UDRow -Columns {
        New-UDColumn -Size 3 -Content { }
        New-UDColumn -Size 6 -Content {   
            New-UDChart -Title "Threads by Process" -Type Doughnut -RefreshInterval 5 -Endpoint {  
                Get-Process | ForEach-Object { [PSCustomObject]@{ Name = $_.Name; Threads = $_.Threads.Count } } | Out-UDChartData -DataProperty "Threads" -LabelProperty "Name"  
            } -Options @{  
                legend = @{  
                    display = $false  
                }  
            }		  
        }  
    }
}



$Navigation = New-UDSideNav -Content {
    New-UDSideNavItem -Text "Home" -PageName "Home" -Icon home
    New-UDSideNavItem -Text "Start Batches" -PageName "Start Batch Tasks" -Icon play
    New-UDSideNavItem -Text "Manage Batches" -PageName "Manage Batches" -Icon tasks
    New-UDSideNavItem -Text "Monitor Workstation" -PageName "Monitors" -Icon link
    New-UDSideNavItem -Text "Documentation" -Children {
        New-UDSideNavItem -Text "Batch Create" -Url 'https://github.com/psu-libraries/contentdmtools/blob/community/docs/batchCreateCompoundObjects.md' -Icon plus_square
        New-UDSideNavItem -Text "Batch Edit" -Url 'https://github.com/psu-libraries/contentdmtools/blob/community/docs/batchEdit.md' -Icon edit
        New-UDSideNavItem -Text "Batch Re-OCR" -Url 'https://github.com/psu-libraries/contentdmtools/blob/community/docs/batchReOCR.md' -Icon font
    }
}

Enable-UDLogging -Level Debug -FilePath logs\dashboard_log.txt -Console

Start-UDDashboard -Content {
    New-UDDashboard -Title "CONTENTdm Tools Dashboard" -Navigation $Navigation -Theme $theme -Pages @($HomePage, $Start, $Manage, $Monitor)
} -Port 1000 -Name 'cdm_tools' -AutoReload