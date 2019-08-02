# CONTENTdm Tools
A set of PowerShell scripts for batch procesing digital content for CONTENTdm and for batch management of existing digital collections. For those who prefer, a web-based GUI is available.

## PowerShell Scripts
PowerShell is a scripting language that is included in all versions of Windows since Windows 7. To run Powershell scripts, you need to first run a command to allow them. To do this, you will need to open PowerShell with Administrative Privileges and run the following command: `Set-ExecutionPolicy Unrestricted`. If you are unable to run PowerShell with Administrative Privileges, you can run the following command to run scripts, but it will need to be run in every PowerShell session: `powershell.exe -ExecutionPolicy bypass`.

## Documentation
Even if you are using the CONTENTdm Tools Dashboard, you will find the documentation, which is aimed more at command line usage, helpful. It provides details on the parameters and specific usage of each tool.
  * [Batch create compound objects](docs/batchCreateCompoundObjects.md)
  * [Batch edit objects and items](docs/batchEdit.md)
  * [Batch Re-OCR items](docs/batchReOCR.md)