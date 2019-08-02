# contentdmToolsGUI-dashboard.ps1
# GUI for CONTENTdm Tools using Universal Dashboard

# Variables
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$global:pids = @()
$theme = Get-UDTheme -Name "Default"

$HomePage = New-UDPage -Name "Home" -Content {
    New-UDLayout -Columns 2 -Content {
        New-UDCard -Title "Getting Started" -Content {
            New-UDParagraph -Text "CONTENTdm Tools is a set of PowerShell scripts to assist in building and managing CONTENTdm digital collections. These command line scripts can be run using this web dashboard. Use the menu in the upper-left corner to begin using CONTENTdm Tools. Full documentation for the command line tools, which provides details on the processing, is available on the right."
        }
        New-UDCard -Title "Documentation" -Content {
            New-UDHtml -Markup '<ul><li><a href="https://github.com/psu-libraries/contentdmtools/blob/community/docs/batchCreateCompoundObjects.md" target="_blank" alt="Documentation for Batch Create Compound Objects">Batch Create Compound Objects<a/></li><li><a href="https://github.com/psu-libraries/contentdmtools/blob/community/docs/batchEdit.md" target="_blank" alt="Documentation for Batch Edit Metadata">Batch Edit Metadata</a></li><li><a href="https://github.com/psu-libraries/contentdmtools/blob/community/docs/batchReOCR.md" target="_blank" alt="Documentation for Batch Re-OCR">Batch Re-OCR</a></li></ul>'
        }
        New-UDCard -Title "Contributing" -Content {
            New-UDParagraph -Text "CONTENTdm Tools is an open-source project. A link to the GitHub repository is available on the navigation menu. If you have PowerShell scripts you would like to contribute to the toolkit, please submit a pull request!"
        }
        New-UDCard -Title "Support" -Content {
            New-UDParagraph -Text "CONTENTdm Tools was created by Nathan Tallman at Penn State University. Ability to provide support is limited, as is the ability to add new features, but some things may be possible. Contact Nathan at ntt7@psu.edu with questions, comments, and requests."
        }
    }
}

$Start = New-UDPage -Name "Start Batch Tasks" -Content {
    New-UDLayout -Columns 1 -Content {
        New-UDInput -Title "Create Batch of Compound Objects" -Id "createBatch" -SubmitText "Start" -Content {
            New-UDInputField -Type 'textarea' -Name 'path' -Placeholder 'C:\path\to\batch' -DefaultValue 'C:\path\to\batch'
            New-UDInputField -Type 'textarea' -Name 'metadata' -Placeholder 'metadata.csv' -DefaultValue 'metadata.csv'
            New-UDInputField -Type 'select' -Name 'jp2' -Placeholder "JP2 Output" -Values @("true", "false", "skip") -DefaultValue "true"
            New-UDInputField -Type 'select' -Name 'ocr' -Placeholder "OCR Output" -Values @("text", "pdf", "both", "skip") -DefaultValue "both"
            New-UDInputField -Type 'select' -Name 'originals' -Placeholder @("Originals") -Values @("keep", "discard", "skip") -DefaultValue "keep"
        } -Endpoint {
            Param($metadata, $jp2, $ocr, $originals, $path)       
            $scriptblock = "$dir\batchCreateCompoundObjects.ps1 -metadata $metadata -jp2 $jp2 -ocr $ocr -originals $originals -path $path"
            $p = Start-Process PowerShell.exe -ArgumentList "-noexit -command $scriptblock" -PassThru
            $batchCreateId = $($p.id)
            $global:pids += $batchCreateId
            New-UDInputAction -Content @(
                New-UDCard -Title "Create Batch of Compound Objects" -Text "The batch creation process has started in a new PowerShell window, you should see running output there. When it's complete, you can close the window. You can also close the window to cancel at any time."
            )
        }

        New-UDInput -Title "Edit Batch of Metadata" -Id "batchEdit" -SubmitText "Start" -Content {
            New-UDInputField -Type 'textbox' -Name 'metadata' -Placeholder 'C:\path\to\metadata.csv' -DefaultValue 'C:\path\to\metadata.csv'
            New-UDInputField -Type 'textbox' -Name 'collection' -Placeholder 'Collection Alias' -DefaultValue "collectionAlias"
        } -Endpoint {
            Param($metadata, $collection)
            $scriptblock = "$dir\batchEdit.ps1 -csv $metadata -collection $collection"
            $p = Start-Process PowerShell.exe -ArgumentList "-noexit -command $scriptblock" -PassThru
            $batchEditId = $($p.id)
            $global:pids += $batchEditId
            New-UDInputAction -Content @(
                New-UDCard -Title "Edit Batch of Metadata" -Text "The batch edit has started in a new PowerShell window, you should see running output there. When it's complete, you can close the window. You can also close the window to cancel at any time."
            )
        }

        New-UDInput -Title "Re-OCR a Collection" -Id "batchReOCR" -SubmitText "Start" -Content {
            New-UDInputField -Type 'textbox' -Name 'collection' -Placeholder 'Collection Alias' -DefaultValue "collectionAlias"
            New-UDInputField -Type 'textbox' -Name 'field' -Placeholder 'Fulltext Field' -DefaultValue "fulltextFieldNickname"
            New-UDInputField -Type 'textbox' -Name 'path' -Placeholder 'C:\path\to\staging' -DefaultValue "C:\path\to\staging"
            New-UDInputField -Type 'textbox' -Name 'public' -Placeholder 'URL for Public UI' -DefaultValue "https://public/"
            New-UDInputField -Type 'textbox' -Name 'server' -Placeholder 'URL for Admin UI' -DefaultValue "https://admin"
        } -Endpoint {
            Param($collection, $field, $path, $public, $server)
            $scriptblock = "$dir\batchReOCR.ps1 -collection $collection -field $field -path $path -public $public -server $server"
            $p = Start-Process PowerShell.exe -ArgumentList "-noexit -command $scriptblock"
            $batchReOCRId = $($p.id)
            $global:pids += $batchReOCRId
            New-UDInputAction -Content @(
                New-UDCard -Title "Re-OCR a Collection" -Text "The batch re-OCR has started in a new PowerShell window, you should see running output there. When it's complete, you can close the window. You can also close the window to cancel at any time."
            )
        }
    }
}

<# $Manage = New-UDPage -Name "Manage Batches" -Content {
    New-UDLayout -Columns 3 -Content {  
        New-UDCard -Title "Batch" -Text "$global:pids"
    }
} #>

$NavBarLinks = @((New-UDLink -Text "Home" -Url "/Home" -Icon home),
                 (New-UDLink -Text "Start Batches" -Url "/Start-Batch-Tasks" -Icon play),
                 (New-UDLink -Text "Documentation" -Url "https://github.com/psu-libraries/contentdmtools/tree/community/docs" -Icon book))


$Navigation = New-UDSideNav -Content {
    New-UDSideNavItem -Text "Home" -PageName "Home" -Icon home
    New-UDSideNavItem -Text "Start Batches" -PageName "Start Batch Tasks" -Icon play
    #New-UDSideNavItem -Text "Manage Batches" -PageName "Manage Batches" -Icon tasks
    New-UDSideNavItem -Text "Documentation" -Children {
        New-UDSideNavItem -Text "Batch Create" -Url 'https://github.com/psu-libraries/contentdmtools/blob/community/docs/batchCreateCompoundObjects.md' -Icon plus_square
        New-UDSideNavItem -Text "Batch Edit" -Url 'https://github.com/psu-libraries/contentdmtools/blob/community/docs/batchEdit.md' -Icon edit
        New-UDSideNavItem -Text "Batch Re-OCR" -Url 'https://github.com/psu-libraries/contentdmtools/blob/community/docs/batchReOCR.md' -Icon font
    }
}

Enable-UDLogging -Level Debug -FilePath "$dir\logs\dashboard_log.txt" -Console

Start-UDDashboard -Content {
    New-UDDashboard -Title "CONTENTdm Tools Dashboard" -Navigation $Navigation -NavbarLinks $NavBarLinks -Theme $theme -Pages @($HomePage, $Start)
} -Port 1000 -Name 'cdm-tools' -AutoReload