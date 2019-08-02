# setup.ps1
# Nathan Tallman, August 2019.
# Setup script for the CONTENTdm Tools Dashboard
# This setup script must be run in a PowerShell session with elevated rights (Run as Administrator).

Write-Host "Setting up some dependencies for the CONTENTdm Tools Dashboard. If you see warnings about modules currently being used, you can safely ignore them."

# Install Nuget package provider.
Install-PackageProvider NuGet -Force

# Set PSGallery repository as trusted.
Set-PSRepository PSGallery -InstallationPolicy Trusted 
    
# Update the PowershellGet module.
Install-Module PowershellGet -Force -AllowClobber

Write-Host "Please close this PowerShell windows and run this setup script again. After installing the last dependency, the session needs to be restarted before proceeding. If this is the second time you have seen this message, press any key to continue."
[void][System.Console]::ReadKey($true)
    
# Install the Universal Dashboard module.
Install-Module UniversalDashboard.Community -Force -AcceptLicense -AllowPrerelease

# Unblock CONTENTdm Tools PowerShell Scripts
Get-ChildItem *.ps1,*.bat -Recurse | ForEach-Object {
    Unblock-File $_.FullName 
}