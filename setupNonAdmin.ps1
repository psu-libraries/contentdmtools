# setup.ps1
# Nathan Tallman, August 2019.
# Setup script for the CONTENTdm Tools Dashboard
# This setup script must be run in a PowerShell session with elevated rights (Run as Administrator).

# Setup directories
$scriptpath = $MyInvocation.MyCommand.Path
$cdmt_root = Split-Path $scriptpath
If (!(Test-Path "$cdmt_root\settings")) { New-Item -ItemType Directory -Path "$cdmt_root\settings" | Out-Null }
If (!(Test-Path "$cdmt_root\logs")) { New-Item -ItemType Directory -Path "$cdmt_root\logs" | Out-Null }
$log = "$cdmt_root\logs\setupNonAdmin_log" + $(Get-Date -Format yyyy-MM-ddTHH-mm-ss-ffff) + ".txt"

Write-Output "Setting up some dependencies for the CONTENTdm Tools Dashboard. If you see warnings about modules currently being used, you can safely ignore them." | Tee-Object -FilePath $log -Append

# Set PSGallery repository as trusted.
Set-PSRepository PSGallery -InstallationPolicy Trusted | Tee-Object -FilePath $log -Append

# Install Nuget package provider.
If (!(Get-Module -ListAvailable -Name "NuGet")) {
    Install-PackageProvider NuGet -Force -Scope CurrentUser | Tee-Object -FilePath $log -Append
}

# Update the PowershellGet module.
If (((get-module -listAvailable -Name "PowershellGet").version.major) -lt 2 ) {
    Install-Module PowershellGet -Force -Scope CurrentUser | Tee-Object -FilePath $log -Append
}

Write-Output "Please close this PowerShell windows and run this setup script again. After installing the last dependency, the session needs to be restarted before proceeding. If this is the second time you have seen this message, press any key to continue." | Tee-Object -FilePath $log -Append
[void][System.Console]::ReadKey($true)

# Install the Universal Dashboard module.
if (!(Get-Module -ListAvailable -Name "UniversalDashboard*")) {
    Install-Module UniversalDashboard.Community -Force -AcceptLicense -AllowPrerelease -Scope CurrentUser | Tee-Object -FilePath $log -Append
}

# Unblock CONTENTdm Tools PowerShell Scripts
Get-ChildItem *.ps1, *.bat -Recurse | ForEach-Object {
    Unblock-File $_.FullName | Tee-Object -FilePath $log -Append
}