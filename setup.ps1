# contentdmToolsGUI2.ps1
# GUI for CONTENTdm Tools using Universal Dashboard
# This setup script must be run in a PowerShell session with elevated rights (Run as Administrator).

Write-Host "Setting up some dependencies for the CONTENTdm Tools Dashboard. If you see warnings about modules currently being used, you can safely ignore them."

# Install Nuget package provider.
Install-PackageProvider NuGet -Force

# Set PSGallery repository as trusted.
Set-PSRepository PSGallery -InstallationPolicy Trusted 
    
# Update the PowershellGet module.
Install-Module PowershellGet -Force -AllowClobber
    
# Install the Universal Dashboard module.
Install-Module UniversalDashboard.Community -Force -AcceptLicense -AllowPrerelease

#Write-Host -BackgroundColor Black -ForegroundColor Yellow -NoNewLine "Tesseract OCR needs to be installed on this computer. Your browser will open to a page where it can be downloaded, you will probably want the 64 bit option. Press any key to continue..."
#$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
#Start-Process 'https://github.com/UB-Mannheim/tesseract/wiki'

# Unblock CONTENTdm Tools PowerShell Scripts
Get-ChildItem *.ps1 -Recurse | ForEach-Object {
    Unblock-File $_.FullName 
}