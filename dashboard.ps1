# dashboard.ps1
# Nathan Tallman, August 2019.
# CONTENTdm Tools Dashboard

# Variables
$scriptpath = $MyInvocation.MyCommand.Path
$cdmt_root = Split-Path $scriptpath

# Import Library
. $cdmt_root\util\lib.ps1
. Get-Org-Settings

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
            New-UDInputField -Type 'textarea' -Name 'public' -Placeholder 'https://PublicURL.org' -DefaultValue $Global:cdmt_public
            New-UDInputField -Type 'textarea' -Name 'server' -Placeholder 'https://AdminURL.org' -DefaultValue $Global:cdmt_server
            New-UDInputField -Type 'textbox' -Name 'license' -Placeholder 'XXXX-XXXX-XXXX-XXXX' -DefaultValue $Global:cdmt_license
        } -Endpoint {
            Param($public, $server, $license)
            $org = New-Object -TypeName psobject
            $org | Add-Member -MemberType NoteProperty -Name public -Value $public
            $org | Add-Member -MemberType NoteProperty -Name server -Value $server
            $org | Add-Member -MemberType NoteProperty -Name license -Value $license
            $org | Export-Csv "$cdmt_root\settings\org.csv" -NoTypeInformation
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
            Param($user, $password, $throttle, $staging)
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
            New-UDInputField -Type 'textbox' -Name 'metadata' -Placeholder 'metadata.csv' -DefaultValue "metadata.csv"
            New-UDInputField -Type 'select' -Name 'throttle' -Placeholder "Throttle" -Values @("1","2","4","6","8") -DefaultValue "2"
            New-UDInputField -Type 'select' -Name 'jp2' -Placeholder "JP2 Output" -Values @("true", "false", "skip") -DefaultValue "true"
            New-UDInputField -Type 'select' -Name 'ocr' -Placeholder "OCR Output" -Values @("text", "pdf", "both", "extract", "skip") -DefaultValue "both"
            New-UDInputField -Type 'select' -Name 'ocrengine' -Placeholder "OCR Engine" -Values @("ABBYY", "tesseract") -DefaultValue "tesseract"
            New-UDInputField -Type 'select' -Name 'originals' -Placeholder @("Originals") -Values @("keep", "discard", "skip") -DefaultValue "keep"
        } -Endpoint {
            Param($path, $metadata, [int16]$throttle, $jp2, $ocr, $ocrengine, $originals)
            $scriptblock = "$cdmt_root\batchCreateCompoundObjects.ps1 -path $path -metadata $metadata -throttle $throttle -jp2 $jp2 -ocr $ocr -ocrengine $ocrengine -originals $originals"
            Start-Process PowerShell.exe -ArgumentList "-NoExit -WindowStyle Maximized -ExecutionPolicy ByPass -Command $scriptblock"
            New-UDInputAction -Content @(
                New-UDCard -Title "Batch Create Compound Objects" -Text "`nBatch creation has started in a new PowerShell window, you should see running output there. When it's complete, a brief report that includes the path to a log file containing the all output will be shown and you can close the window.`r`n
                You can also close the window at any time to halt the batch.`n
                ------------------------------`n
                Path:`t$path`n
                Metadata:`t$metadata`n
                Throttle:`t$throttle`n
                JP2s:`t$jp2`n
                OCR:`t$ocr`n
                OCR Engine:`t$ocrengine`n
                Originals:`t$originals`n
                ------------------------------`n
                Batch Start Time:`t$(Get-Date -Format u)"
            )
        }

        New-UDInput -Title "Batch Edit Metadata" -Id "batchEdit" -SubmitText "Start" -Content {
            New-UDInputField -Type 'textbox' -Name 'collection' -Placeholder 'Collection Alias'
            New-UDInputField -Type 'textarea' -Name 'server' -Placeholder 'URL for Admin UI' -DefaultValue $Global:cdmt_server
            New-UDInputField -Type 'textarea' -Name 'license' -Placeholder 'XXXX-XXXX-XXXX-XXXX' -DefaultValue $Global:cdmt_license
            New-UDInputField -Type 'textarea' -Name 'metadata' -Placeholder 'C:\path\to\metadata.csv'
            New-UDInputField -Type 'textbox' -Name 'user' -Placeholder 'CONTENTdm Username'
        } -Endpoint {
            Param($collection, $server, $license, $metadata, $user)
            $scriptblock = "$cdmt_root\batchEdit.ps1 -collection $collection -server $server -license $license -csv $metadata  -user $user"
            Start-Process PowerShell.exe -ArgumentList "-NoExit -WindowStyle Maximized -ExecutionPolicy ByPass -Command $scriptblock"
            New-UDInputAction -Content @(
                New-UDCard -Title "Batch Edit Metadata" -Text "`rBatch edit has started in a new PowerShell window, you should see running output there. When it's complete, a brief report that includes the path to a log file containing the all output will be shown and you can close the window.`r`n
                You can also close the window at any time to halt the batch.`n
                ------------------------------`n
                Collection:`t$collection`n
                Server:`t$server`n
                License:`t$license`n
                Metadata:`t$metadata`n`
                User:`t$user`n
                ------------------------------`n
                Batch Start Time`t$(Get-Date -Format u)"
            )
        }

        New-UDInput -Title "Batch OCR a Collection" -Id "batchOCR" -SubmitText "Start" -Content {
            New-UDInputField -Type 'textbox' -Name 'collection' -Placeholder 'Collection Alias'
            New-UDInputField -Type 'textbox' -Name 'field' -Placeholder 'Fulltext Field'
            New-UDInputField -Type 'textarea' -Name 'public' -Placeholder 'URL for Public UI' -DefaultValue $Global:cdmt_public
            New-UDInputField -Type 'textarea' -Name 'server' -Placeholder 'URL for Admin UI' -DefaultValue $Global:cdmt_server
            New-UDInputField -Type 'textarea' -Name 'license' -Placeholder 'XXXX-XXXX-XXXX-XXXX' -DefaultValue $Global:cdmt_license
            New-UDInputField -Type 'textarea' -Name 'path' -Placeholder 'C:\path\to\staging'
            New-UDInputField -Type 'textbox' -Name 'user' -Placeholder 'CONTENTdm Username'
            New-UDInputField -Type 'select' -Name 'throttle' -Placeholder "Throttle" -Values @("1","2","4","6","8") -DefaultValue "2"
            New-UDInputField -Type 'select' -Name 'method' -Placeholder "Download Method" -Values @("API", "IIIF") -DefaultValue "API"
        } -Endpoint {
            Param($collection, $field, $public, $server, $license, $path, $user, $throttle, $method)
            $scriptblock = "$cdmt_root\batchOCR.ps1 -collection $collection -field $field -public $public -server $server -license $license -path $path -user $user -throttle $throttle -method $method"
            Start-Process PowerShell.exe -ArgumentList "-NoExit -WindowStyle Maximized -ExecutionPolicy ByPass -Command $scriptblock"
            New-UDInputAction -Content @(
                New-UDCard -Title "Batch OCR a Collection" -Text "`nBatch OCR has started in a new PowerShell window, you should see running output there. When it's complete, a brief report that includes the path to a log file containing the all output will be shown and you can close the window.`r`n
                You can also close the window at any time to halt the batch.`n
                ------------------------------`n
                Collection:`t`t$collection`n
                Field:`t`t$field`n
                Public:`t`t$public`n
                Server:`t`t$server`n
                License:`t`t$license`n
                Path:`t`t$path`n
                User:`t`t$user`n
                Throttle:`t`t$throttle`n
                Method:`t`t$method`n
                ------------------------------`n
                Batch Start Time:`t`t$(Get-Date -Format u)"
            )
        }
    }

    New-UDLayout -Columns 2 -Content {
        New-UDInput -Title "Published Collection Alias Look Up" -Id "getCollections" -SubmitText "Look Up" -Content {
            New-UDInputField -Type 'textarea' -Name 'server' -Placeholder 'URL for Admin UI' -DefaultValue $Global:cdmt_server
        } -Endpoint {
            Param($server)
            $data = Invoke-RestMethod "$server/dmwebservices/index.php?q=dmGetCollectionList/json"
            New-UDInputAction -Content @(
                New-UDGrid -Title "Published Collection Alias'" -Headers @("Name", "Alias") -Properties @("name", "secondary_alias") -Endpoint { $data | Out-UDGridData }
            )
        }

        New-UDInput -Title "Collection Field Properties Look Up" -Id "getCollProp" -SubmitText "Look Up" -Content {
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

    New-UDLayout -Columns 2 -Content {
        New-UDInput -Title "Collection Metadata Export" -Id "getMetadataTxt" -SubmitText "Export" -Content {
            New-UDInputField -Type 'textbox' -Name 'collection' -Placeholder 'Collection Alias'
            New-UDInputField -Type 'textarea' -Name 'server' -Placeholder 'URL for Admin UI' -DefaultValue $Global:cdmt_server
            New-UDInputField -Type 'textarea' -Name 'path' -Placeholder 'C:\path\to\staging'
            New-UDInputField -Type 'textbox' -Name 'user' -Placeholder 'CONTENTdm Username'
        } -Endpoint {
            Param($user,$server,$collection,$path)
            Write-Debug "Test for existing user credentials; if they exist use the, if they don't prompt for a password. "
            if (Test-Path $cdmt_root\settings\user.csv) {
                $usrcsv = $(Resolve-Path $cdmt_root\settings\user.csv)
                $usrcsv = Import-Csv $usrcsv
                $usrcsv | Where-Object { $_.user -eq "$user" } | ForEach-Object {
                    $SecurePassword = $_.password | ConvertTo-SecureString
                    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
                    $pw = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                    $null = $BSTR
                }
                if ("$user" -notin $usrcsv.user) {
                    Write-Output "No user settings found for $user. Enter a password below or store secure credentials using the dashboard."
                    [SecureString]$password = Read-Host "Enter $user's CONTENTdm password" -AsSecureString
                    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR([SecureString]$password)
                    $pw = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                    $null = $BSTR
                }
            }
            Else {
                Write-Output "No user settings file found. Enter a password below or store secure credentials using the dashboard."
                [SecureString]$password = Read-Host "Enter $user's CONTENTdm password" -AsSecureString
                $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR([SecureString]$password)
                $pw = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                $null = $BSTR
            }
            $pair = "$($user):$($pw)"
            $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
            $basicAuthValue = "Basic $encodedCreds"
            $Headers = @{
                Authorization = $basicAuthValue
            }
            Invoke-WebRequest "$server/cgi-bin/admin/export.exe?CISODB=/$collection&CISOOP=ascii&CISOMODE=1&CISOPTRLIST=" -Headers $Headers | Out-Null
            Invoke-RestMethod "$server/cgi-bin/admin/getfile.exe?CISOMODE=1&CISOFILE=/$collection/index/description/export.txt" -Headers $Headers -OutFile "$path\$collection.txt"
            New-UDInputAction -Toast "Collection metadata exported to $path\$collection.txt"
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
        New-UDSideNavItem -Text "Batch OCR" -Url 'https://github.com/psu-libraries/contentdmtools/blob/community/docs/batchOCR.md' -Icon font
    }
}

Enable-UDLogging -Level Info -FilePath "$cdmt_root\logs\dashboard_log.txt" #-Console

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