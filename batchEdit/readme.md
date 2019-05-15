## Batch Editing Metadata
The `batchEdit.ps1` script can be used to process `metadata.csv` into SOAP XML that can be fed into [CONTENTdm Catcher](https://www.oclc.org/support/services/contentdm/help/add-ons-help/contentdm-catcher.en.html). If successfully loaded from catcher, they need to be indexed in the Administrative GUI.

A [screencast demonstration](https://psu.box.com/s/4fgdgme1d4df3z6vz6gz68jdgs4bu2rt) is available. It is recommended to use the script in the directory is is created in when you save the script to your computer, just move metadata CSV files into the directory as you need to.

## Usage
Run `.\batchEdit.ps1 -alias collectionAlias` to kick off the script. The data table of metadata changes should be in the in the same directory as the script and named `metadata.csv`. You can pass any CSV by using inserting `-csv path` before the `-alias` parameter when running the script.

You will be prompted to enter your CONTENTdm username and password, as well as the PSU License. These will be securely stored on your workstation in a subdirectory called settings; you wouldn't need to enter them again. If they are lost, you will be prompted to enter them again.

  * **Put object level metadata first in the metadata csv**. If items metadata appears before the parent object, the obect metadata won't get updated. [Working to remove the requirement by filtering and sorting the CSV data with an extra column.] You should still watch the output or look at the logs for any errors.
  * **Controlled vocabularies and required fields (other than title) must be turned off before pitching metadata to catcher**. Make note of the settings and turn them back on after done batch editing.
  * **Field names used as headers are not the same as the field name labels in CONTENTdm**. Look at the `CISONICK` value in the Field Properties in the Admin Gui for the correct field name to use as the CSV header.
  * **Log directories need to be created** or pitcher will throw an error. You may have to create `logs` subdirectories in **both** your home directory and the active directory the `batchEdit.ps1` script is running from, if it does not already exist.

### Sample metadata.csv

| dmrecord | title         | subjec        |
| -------- | ------------- | ------------- |
| 108      | OBJECT TITLE  | Batch Edit 19 |
| 99       | OBJECT TITLE  | Batch Edit 18 |
| 90       | Batch Edit 20 | Batch Edit 17 |
| 91       | Batch Edit 01 | Batch Edit 24 |
| 92       | Batch Edit 02 | Batch Edit 25 |
| 93       | Batch Edit 03 | Batch Edit 26 |
| 94       | Batch Edit 04 | Batch Edit 27 |

### Sample Workflow
- Export metadata from CONTENTdm
- Work in Excel or Open Refine and batch edit.
- Remove fields/columns with no changes.
- Remove rows with no changes. (This isn't critical, but good practice.)
- Place all compound object-level metadata at the beginning of the spreadsheet.
- Rename fields/columns with CONTENTdm `CISONICK` field name as indicated above.
  - The CONTENTdm record number must always be included with the name `dmrecord`.
- Note field property configurations and disable required fields and controlled vocabulary in Admin GUI.
- Export UTF-8 CSV called metadata.csv and save it in the directory where `batchEdit.ps1` is saved.
  - You can pass any CSV with `-csv path.csv` as the first parameter when executing the script.
- Run `batchEdit.ps1` in a PowerShell window.
- Index the collection.
- Re-configure field properties.
- Review log for any errors.

## Future Development
 - Combine settings for Cather into one file [1](https://git.psu.edu/digipres/contentdm/issues/1)
 - Sort metadata and send object metadata first [2](https://git.psu.edu/digipres/contentdm/issues/2)
 - Search log for errors and report back when ending script [3](https://git.psu.edu/digipres/contentdm/issues/3)