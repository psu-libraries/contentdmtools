# contentdmToolsGUI2.ps1
# GUI for CONTENTdm Tools using Universal Dashboard
# This setup script must be run in a PowerShell session with elevated rights (Run as Administrator).

Write-Host "Setting up some dependencies for the CONTENTdm Tools Dashboard. If you see a warning about the 'PackageMangement' module currently being used, you can safely ignore it."

# Install Nuget package provider.
Install-PackageProvider NuGet -Force

# Set PSGallery repository as trusted.
Set-PSRepository PSGallery -InstallationPolicy Trusted 
    
# Update the PowershellGet module.
Install-Module PowershellGet -Force -ErrorAction SilentlyContinue
    
# Install the Universal Dashboard module.
Install-Module UniversalDashboard.Community -AcceptLicense

Write-Host -BackgroundColor Black -ForegroundColor Yellow -NoNewLine "Tesseract OCR needs to be installed on this computer. Your browser will open to a page where it can be downloaded, you will probably want the 64 bit option. Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
Start-Process 'https://github.com/UB-Mannheim/tesseract/wiki'