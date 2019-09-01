# Batch Editing CONTENTdm Metadata
The `batchEdit.ps1` script can be used to process `metadata.csv` into SOAP XML that can be fed into [CONTENTdm Catcher](https://www.oclc.org/support/services/contentdm/help/add-ons-help/contentdm-catcher.en.html). If successfully loaded from catcher, metadata needs to be indexed (but not approved) in the CONTENTdm Administrative UI.

## Usage
Run `.\batchEdit.ps1 -csv metadata.csv -collection collectionAlias -user CONTENTdmUserName` to kick off the script. You can pass any CSV with `-csv \path\to\metadata.csv`, but if `-csv` is left out, the script will assume a file named `metadata.csv` is in the same directory as the script.

### Parameters
  - `-csv` -- Filepath and name for the metadata CSV of batch edits. If running command line, can releative. If using dashboard, always use full filepath. Always include filename.
  - `-collection` -- Collection alias for the CONTENTdm collection you wish to batch edit. REQUIRED
  - `-user` -- Username for a CONTENTdm user. REQUIRED
    - If you are using the dashboard, you can save your password in CONTENTdm Tools and it will automatically be passed through. Otherwise, you will see a command prompt asking for your CONTENTdm password.
  - `-server` -- URL to the Administrative UI. This may include a port number for self-hosted instances. (Defaults to stored settings is left out.)
  - `-license` -- CONTENTdm License. (Defaults to stored settings is left out.)
  - `-verbose` -- Optional parameter to increase logging output.

  * **Controlled vocabularies and required fields (other than title) must be turned off before pitching metadata to catcher**. Make note of the settings and turn them back on after you are done with batch editing.

### Sample metadata.csv
| CONTENTdm number | Title         | Subject       |
| ---------------- | ------------- | ------------- |
| 90               | Batch Edit 20 | Batch Edit 17 |
| 91               | Batch Edit 01 | Batch Edit 24 |
| 92               | Batch Edit 02 | Batch Edit 25 |
| 93               | Batch Edit 03 | Batch Edit 26 |
| 94               | Batch Edit 04 | Batch Edit 27 |
| 99               | OBJECT TITLE  | Batch Edit 18 |
| 108              | OBJECT TITLE  | Batch Edit 19 |

### Sample Workflow
- Export metadata from CONTENTdm.
- Work in Excel or Open Refine and batch edit.
- Remove fields/columns with no changes.
- Remove rows with no changes. (This isn't critical, but good practice.)
  - The CONTENTdm record number must always be included as the first column in the CSV. The field name is usually CONTENTdm number and file nickname is usually dmrecord.
- Note field property configurations and disable required fields and controlled vocabulary in Admin GUI.
- Export UTF-8 CSV called metadata.csv and use CONTENTdm ToolS Dashboard to upload changes.
  - Or run in manually. You can pass any CSV with `-csv C:\path\to.csv` as the first parameter when executing the script.
  - Run `batchEdit.ps1 -csv path\metadata.csv -collection collectionAlias -server https://URLforAdminUI -license XXXX-XXXX-XXXX-XXXX -user CONTENTdmUserName` in a PowerShell window.
- Index the collection.
- Re-configure field properties.
- Review log for any errors.