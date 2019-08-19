# Batch Editing CONTENTdm Metadata
The `batchEdit.ps1` script can be used to process `metadata.csv` into SOAP XML that can be fed into [CONTENTdm Catcher](https://www.oclc.org/support/services/contentdm/help/add-ons-help/contentdm-catcher.en.html). If successfully loaded from catcher, metadata needs to be indexed (but not approved) in the CONTENTdm Administrative UI.

## Usage
Run `.\batchEdit.ps1 -csv metadata.csv -collection collectionAlias -user CONTENTdmUserName` to kick off the script. You can pass any CSV with `-csv \path\to\metadata.csv`, but if `-csv` is left out, the script will assume a file named `metadata.csv` is in the same directory as the script.

If you are using the dashboard, you can save your password in CONTENTdm Tools and it will automatically be passed through. Otherwise, you will see a command prompt asking for your CONTENTdm password. The `-server` and `-license` parameters are also automatically supplied if stored in the dashboard. You should pass them through with the command or will be prompted if necessary.

  * **Field names used as headers are not the same as the field name labels in CONTENTdm**. The dashboard provides a Collection Field Properties Lookup that will display the **field nicknames** for a collection. Also, yoou can look at the `CISONICK` value in the Field Properties in the Admin Gui for the correct field name to use as the CSV header.
  * **Controlled vocabularies and required fields (other than title) must be turned off before pitching metadata to catcher**. Make note of the settings and turn them back on after you are done with batch editing.

### Sample metadata.csv
| dmrecord | title         | subjec        |
| -------- | ------------- | ------------- |
| 90       | Batch Edit 20 | Batch Edit 17 |
| 91       | Batch Edit 01 | Batch Edit 24 |
| 92       | Batch Edit 02 | Batch Edit 25 |
| 93       | Batch Edit 03 | Batch Edit 26 |
| 94       | Batch Edit 04 | Batch Edit 27 |
| 99       | OBJECT TITLE  | Batch Edit 18 |
| 108      | OBJECT TITLE  | Batch Edit 19 |

### Sample Workflow
- Export metadata from CONTENTdm.
- Work in Excel or Open Refine and batch edit.
- Remove fields/columns with no changes.
- Remove rows with no changes. (This isn't critical, but good practice.)
- Rename fields/columns with field nickname as indicated above.
  - The CONTENTdm record number must always be included with the name `dmrecord`, as the first column in the CSV.
- Note field property configurations and disable required fields and controlled vocabulary in Admin GUI.
- Export UTF-8 CSV called metadata.csv and save it in the directory where `batchEdit.ps1` is saved.
  - You can pass any CSV with `-csv path.csv` as the first parameter when executing the script.
- Run `batchEdit.ps1 -csv path\metadata.csv -collection collectionAlias -server https://URLforAdminUI -user CONTENTdmUserName` in a PowerShell window.
- Index the collection.
- Re-configure field properties.
- Review log for any errors.