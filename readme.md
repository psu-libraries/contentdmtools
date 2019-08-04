# CONTENTdm Tools
A set of PowerShell scripts for batch procesing digital content for CONTENTdm and for batch management of existing digital collections. For those who prefer, a web-based GUI is available.

## PowerShell Scripts
PowerShell is a scripting language that is included in all versions of Windows since Windows 7. To run Powershell scripts, you need to first run a command to allow them. To do this, you will need to open PowerShell with Administrative Privileges and run the following command: `Set-ExecutionPolicy Unrestricted`. If you are unable to run PowerShell with Administrative Privileges, you can run the following command to run scripts, but it will need to be run in every PowerShell session: `powershell.exe -ExecutionPolicy bypass`.

## Getting Started
1. Download or Git Clone [CONTENTdm Tools from GitHub](https://github.com/psu-libraries/contentdmtools).
   * If downloading instead of using Git, you may want to download from the [release](https://github.com/psu-libraries/contentdmtools/releases) page so you can more easily track what version you are using.
   * Extract your ZIP or Clone to a stable location, not your Downloads directory.
   * Tesseract can raise false-positives on anti-virus software, you may need to add an exception and re-extract.
2. If you haven't already, set the PowerShell ExecutionPolicy as described above.
3. In File Explorer, navigate to your CONTENTdm Tools directory, in the area it shows files, but not on a file, hold the Shift key and right-click, then choose `Open a PowerShell Window Here`.
4. If you plan to use the dashboard, you will need to run a setup script. Two are provided, one which requires Administrative Rights and one which does not. Both will need to be run twice because the session needs to be restarted half-way through. Type `.\setup.ps1` or `.\setupNonAdmin.ps1` and press enter. Follow the prompts. Once complete, you can close the window.
5. To start the dashboard, double click on the `startDashboard.bat` file. This will open a terminal window. Once text stops appearing on the screen, go to a browser and visit http://localhost:10000 to view the CONTENTdm Tools Dashboard.
   * **Do not close the terminal window or it will kill the dashboard**. When you are done using CONTENTdm Tools, you can safely close the terminal window.
   * When you start the dashboard for the first time, you will be prompted for Administrative Credentials and asked which networks the web server can run on.
6. If you are not using the dashboard, you can run the scripts in a PowerShell session, in the root directory of CONTENTdm Tools. 

## Documentation
Even if you are using the CONTENTdm Tools Dashboard, you will find the documentation, which is aimed more at command line usage, helpful. It provides details on the parameters and specific usage of each tool.
  * [Batch create compound objects](docs/batchCreateCompoundObjects.md)
  * [Batch edit objects and items](docs/batchEdit.md)
  * [Batch Re-OCR items](docs/batchReOCR.md)

## Dependencies
CONTENTdm Tools uses openly-licensed tools to process images and CONTENTdm services. These tools are already included, so you don't need to install anything apart from running the setup script. They are listed here to credit the original projects and their contributors.
* [CONTENTdm API](https://www.oclc.org/support/services/contentdm/help/customizing-website-help/other-customizations/contentdm-api-reference.en.html) -- The CONTENTdm API is used to retrieve record numbers and images.
* [Ghostscript](https://ghostscript.com/) -- A tool for processing PDF files, used here to merge PDFs and downsample image resolution within PDFs.
* [GraphicsMagick](http://www.graphicsmagick.org/) -- "The swiss army knife of image processing", used here to convert TIF to JP2, while ensuring JP2 compliance and color management.
  * [ImageMagick](https://imagemagick.org/index.php) -- GraphicsMagick itself is based on an earlier project called ImageMagick.
* [Tesseract OCR](https://github.com/tesseract-ocr/tesseract) -- Tesseract is the leading open-source OCR package which is currently developed by Google, used here to convert TIF to TXT and generate searchable PDFs.
* [Universal Dashboard](https://universaldashboard.io/) -- Universal Dashboard is an open-souce, cross-platform PowerShell module for developing and hosting web-based interactive dashboards; used here to provide the CONTENTdm Tools Dashboard GUI.