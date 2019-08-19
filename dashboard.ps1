# dashboard.ps1
# Nathan Tallman, August 2019.
# CONTENTdm Tools Dashboard

# Variables
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath

$HomePage = New-UDPage -Name "Home" -Content {
    New-UDLayout -Columns 2 -Content {
        New-UDCard -Title "Getting Started" -Content {
            New-UDParagraph -Text "CONTENTdm Tools is a set of PowerShell scripts to assist in building and managing CONTENTdm digital collections. These command line scripts can be run using this web dashboard. Use the menu in the upper-left corner to begin using CONTENTdm Tools. Full documentation for the command line tools, which provides details on the processing, is available on the right."
        }
        New-UDCard -Title "Documentation" -Content {
            New-UDHtml -Markup '<ul><li><a href="https://github.com/psu-libraries/contentdmtools/blob/community/docs/batchCreateCompoundObjects.md" target="_blank" alt="Documentation for Batch Create Compound Objects">Batch Create Compound Objects<a/></li><li><a href="https://github.com/psu-libraries/contentdmtools/blob/community/docs/batchEdit.md" target="_blank" alt="Documentation for Batch Edit Metadata">Batch Edit Metadata</a></li><li><a href="https://github.com/psu-libraries/contentdmtools/blob/community/docs/batchOCR.md" target="_blank" alt="Documentation for Batch Re-OCR">Batch Re-OCR</a></li></ul>'
        }
        New-UDCard -Title "Contributing" -Content {
            New-UDParagraph -Text "CONTENTdm Tools is an open-source project. A link to the GitHub repository is available on the navigation menu. If you have PowerShell scripts you would like to contribute to the toolkit, please submit a pull request!"
        }
        New-UDCard -Title "Support" -Content {
            New-UDParagraph -Text "CONTENTdm Tools was created by Nathan Tallman at Penn State University. Ability to provide support is limited, as is the ability to add new features, but some things may be possible. Contact Nathan at ntt7@psu.edu with questions, comments, and requests."
        }
    }
}

$Settings = New-UDPage -Name "Settings" -Content {

    # The app needs to be restarted after saving the org settings the first time for the -DefaultValue variable value to update. I think it's a caching thing in Universal-Dashboard. All org and user setting should be available immediately after saving regardless and anything can be passed when starting batches anyways. User passwords always need to be stored as secured credentials.;

    New-UDLayout -Columns 2 -Content {
        New-UDInput -Title "Organizational Settings" -Id "orgSettings" -SubmitText "Save" -Content {
            . $dir\util\lib.ps1;; Get-Org-Settings
            New-UDInputField -Type 'textarea' -Name 'public' -Placeholder 'https://PublicURL.org' -DefaultValue $Global:cdmt_public
            New-UDInputField -Type 'textarea' -Name 'server' -Placeholder 'https://AdminURL.org' -DefaultValue $Global:cdmt_server
            New-UDInputField -Type 'textbox' -Name 'license' -Placeholder 'XXXX-XXXX-XXXX-XXXX' -DefaultValue $Global:cdmt_license
        } -Endpoint {
            Param($public, $server, $license)
            $org = New-Object -TypeName psobject
            $org | Add-Member -MemberType NoteProperty -Name public -Value $public
            $org | Add-Member -MemberType NoteProperty -Name server -Value $server
            $org | Add-Member -MemberType NoteProperty -Name license -Value $license
            $org | Export-Csv "$dir\settings\org.csv" -NoTypeInformation
            $Global:cdmt_public = $public
            $Global:cdmt_server = $server
            $Global:cdmt_license = $license
            New-UDInputAction -Content @(
                New-UDCard -Title "Organizational Settings" -Text "Organizational Settings Saved`r`n------------------------------`r`nPublic: $Global:cdmt_public`r`nServer: $Global:cdmt_server`r`nLicense: $Global:cdmt_license"
            )
        }

        New-UDInput -Title "User Settings" -Id "userSettings" -SubmitText "Save" -Content {
            New-UDInputField -Type 'textbox' -Name 'user' -Placeholder 'CONTENTdm Username'
            New-UDInputField -Type 'password' -Name 'password'
        } -Endpoint {
            Param($user, $password)
            # Still need to update batchEdit to use these settings and see if the password actually works!
            $SecurePassword = $($password | ConvertTo-SecureString -AsPlainText -Force)
            if (Test-Path settings\user.csv) {
                $usrcsv = Import-Csv .\settings\user.csv
                if ($usrcsv.user -eq "$user") {
                    $usrcsv = Import-Csv .\settings\user.csv
                    $usrcsv | Where-Object { $_.user -eq "$user" } | ForEach-Object {
                        $_.password = $SecurePassword | ConvertFrom-SecureString
                    }
                    $usrcsv | Export-Csv -Path .\settings\user.csv -NoTypeInformation
                    New-UDInputAction -Content @(
                        New-UDCard -Title "User Settings" -Text "Existing User Updated: $user`r`n$x"
                    )
                }
                else {
                    [pscustomobject]@{
                        user     = "$user"
                        password = $SecurePassword | ConvertFrom-SecureString
                    } | Export-Csv -Path  ".\settings\user.csv" -Append -NoTypeInformation
                    New-UDInputAction -Content @(
                        New-UDCard -Title "User Settings" -Text "New User Added: $user`r`n"
                    )
                }
            }
            else {
                [pscustomobject]@{
                    user     = "$user"
                    password = $SecurePassword | ConvertFrom-SecureString
                } | Export-Csv -Path  ".\settings\user.csv" -Append -NoTypeInformation
                New-UDInputAction -Content @(
                    New-UDCard -Title "User Settings" -Text "New User Saved: $user`r`n"
                )
            }
        }
    }
}

$Batch = New-UDPage -Name "Batches" -Content {

    New-UDLayout -Columns 1 -Content {
        New-UDInput -Title "Batch Create Compound Objects" -Id "createBatch" -SubmitText "Start" -Content {
            New-UDInputField -Type 'textarea' -Name 'path' -Placeholder 'C:\path\to\batch'
            New-UDInputField -Type 'textbox' -Name 'metadata' -Placeholder 'metadata.csv' -DefaultValue 'metadata.csv'
            New-UDInputField -Type 'select' -Name 'jp2' -Placeholder "JP2 Output" -Values @("true", "false", "skip") -DefaultValue "true"
            New-UDInputField -Type 'select' -Name 'ocr' -Placeholder "OCR Output" -Values @("text", "pdf", "both", "skip") -DefaultValue "both"
            New-UDInputField -Type 'select' -Name 'originals' -Placeholder @("Originals") -Values @("keep", "discard", "skip") -DefaultValue "keep"
        } -Endpoint {
            Param($metadata, $jp2, $ocr, $originals, $path)
            $scriptblock = "$dir\batchCreateCompoundObjects.ps1 -metadata $metadata -jp2 $jp2 -ocr $ocr -originals $originals -path $path"
            Start-Process PowerShell.exe -ArgumentList "-noexit -command $scriptblock"
            New-UDInputAction -Content @(
                New-UDCard -Title "Batch Create Compound Objects" -Text "The batch creation process has started in a new PowerShell window, you should see running output there. When it's complete, you can close the window. You can also close the window to cancel at any time."
            )
        }

        New-UDInput -Title "Batch Edit Metadata" -Id "batchEdit" -SubmitText "Start" -Content {
            . $dir\util\lib.ps1;; Get-Org-Settings
            New-UDInputField -Type 'textarea' -Name 'metadata' -Placeholder 'C:\path\to\metadata.csv'
            New-UDInputField -Type 'textbox' -Name 'collection' -Placeholder 'Collection Alias'
            New-UDInputField -Type 'textbox' -Name 'user' -Placeholder 'CONTENTdm Username'
            New-UDInputField -Type 'textarea' -Name 'server' -Placeholder 'URL for Admin UI' -DefaultValue $Global:cdmt_server
            New-UDInputField -Type 'textbox' -Name 'license' -Placeholder 'XXXX-XXXX-XXXX-XXXX' -DefaultValue $Global:cdmt_license
        } -Endpoint {
            Param($metadata, $collection, $user, $server, $license)
            $scriptblock = "$dir\batchEdit.ps1 -csv $metadata -collection $collection -user $user -server $server -license $license"
            Start-Process PowerShell.exe -ArgumentList "-noexit -command $scriptblock"
            New-UDInputAction -Content @(
                New-UDCard -Title "Batch Edit Metadata" -Text "The batch edit has started in a new PowerShell window, you should see running output there. When it's complete, you can close the window. You can also close the window to cancel at any time."
            )
        }

        New-UDInput -Title "Batch OCR/Re-OCR a Collection" -Id "batchOCR" -SubmitText "Start" -Content {
            New-UDInputField -Type 'textarea' -Name 'path' -Placeholder 'C:\path\to\staging'
            New-UDInputField -Type 'textbox' -Name 'collection' -Placeholder 'Collection Alias'
            New-UDInputField -Type 'textbox' -Name 'field' -Placeholder 'Fulltext Field'
            New-UDInputField -Type 'textbox' -Name 'user' -Placeholder 'CONTENTdm Username'
            New-UDInputField -Type 'textarea' -Name 'public' -Placeholder 'URL for Public UI' -DefaultValue $Global:cdmt_public
            New-UDInputField -Type 'textarea' -Name 'server' -Placeholder 'URL for Admin UI' -DefaultValue $Global:cdmt_server
            New-UDInputField -Type 'textbox' -Name 'license' -Placeholder 'XXXX-XXXX-XXXX-XXXX' -DefaultValue $Global:cdmt_license
        } -Endpoint {
            Param($path, $collection, $field, $user, $public, $server, $license)
            $scriptblock = "$dir\batchOCR.ps1 -collection $collection -field $field -path $path -user $user -public $public -server $server -license $license"
            Start-Process PowerShell.exe -ArgumentList "-noexit -command $scriptblock"
            New-UDInputAction -Content @(
                New-UDCard -Title "Re-OCR a Collection" -Text "The batch re-OCR has started in a new PowerShell window, you should see running output there. When it's complete, you can close the window. You can also close the window to cancel at any time."
            )
        }
    }

    New-UDLayout -Columns 2 -Content {
        New-UDInput -Title "Published Collection Alias Look Up" -Id "getCollections" -SubmitText "Submit" -Content {
            New-UDInputField -Type 'textarea' -Name 'server' -Placeholder 'URL for Admin UI' -DefaultValue $Global:cdmt_server
        } -Endpoint {
            Param($server)
            $data = Invoke-RestMethod "$server/dmwebservices/index.php?q=dmGetCollectionList/json"
            New-UDInputAction -Content @(
                New-UDGrid -Title "Published Collection Alias'" -Headers @("Name", "Alias") -Properties @("name", "secondary_alias") -Endpoint { $data | Out-UDGridData }
            )
        }

        New-UDInput -Title "Collection Field Properties Look Up" -Id "getCollProp" -SubmitText "Submit" -Content {
            New-UDInputField -Type 'textbox' -Name 'collection' -Placeholder 'Collection Alias'
            New-UDInputField -Type 'textarea' -Name 'server' -Placeholder 'URL for Admin UI' -DefaultValue $Global:cdmt_server
        } -Endpoint {
            Param($collection, $server)
            $data = Invoke-RestMethod "$server/dmwebservices/index.php?q=dmGetCollectionFieldInfo/$collection/json"
            New-UDInputAction -Content @(
                New-UDGrid -Title "Collection Field Properties: $collection" -Headers @("Name", "Nickname", "Data Type", "Large", "Searchable", "Hidden", "Admin", "Required", "Controlled Vocab") -Properties @("name", "nick", "type", "size", "search", "hide", "admin", "req", "vocab") -Endpoint { $data | Out-UDGridData }
            )
        }
    }
}

$NavBarLinks = @(
    (New-UDLink -Text "Home" -Url "/Home" -Icon home),
    (New-UDLink -Text "Settings" -Url "/Settings" -Icon sliders_h),
    (New-UDLink -Text "Batches" -Url "/Batches" -Icon play),
    (New-UDLink -Text "Documentation" -Url "https://github.com/psu-libraries/contentdmtools/tree/community/docs" -Icon book))


$Navigation = New-UDSideNav -Content {
    New-UDSideNavItem -Text "Home" -PageName "Home" -Icon home
    New-UDSideNavItem -Text "Settings" -PageName "Settings" -Icon sliders_h
    New-UDSideNavItem -Text "Batches" -PageName "Batches" -Icon play
    New-UDSideNavItem -Text "Documentation" -Children {
        New-UDSideNavItem -Text "Batch Create" -Url 'https://github.com/psu-libraries/contentdmtools/blob/community/docs/batchCreateCompoundObjects.md' -Icon plus_square
        New-UDSideNavItem -Text "Batch Edit" -Url 'https://github.com/psu-libraries/contentdmtools/blob/community/docs/batchEdit.md' -Icon edit
        New-UDSideNavItem -Text "Batch Re-OCR" -Url 'https://github.com/psu-libraries/contentdmtools/blob/community/docs/batchOCR.md' -Icon font
    }
}

Enable-UDLogging -Level Info -FilePath "$dir\logs\dashboard_log.txt" #-Console

$theme = New-UDTheme -Name "cdm-tools" -Definition @{
    '::placeholder'                 = @{
        color = 'black'
    }
    'textarea.materialize-textarea' = @{
        'height'     = 'auto !important'
        'overflow-y' = 'hidden !important'
        'resize'     = 'none !important'
    }
} -Parent "Default"

Start-UDDashboard -Content {
    New-UDDashboard -Title "CONTENTdm Tools Dashboard" -Navigation $Navigation -NavbarLinks $NavBarLinks -Theme $theme -Pages @($HomePage, $Batch, $Settings)
} -Port 1000 -Name 'cdm-tools' -AutoReload