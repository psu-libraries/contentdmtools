## Batch Editing Items
The `batchEdit.ps1` script can be used to process `metadata.csv` into SOAP XML that can be fed into [CONTENTdm Catcher](https://www.oclc.org/support/services/contentdm/help/add-ons-help/contentdm-catcher.en.html). If successfully loaded from catcher, they need to be indexed in the Administrative GUI.

### Usage
Run `.\batchEdit.ps1 -alias collectionAlias` to kick off the script. The data table of metadata changes should be in the in the same directory as the script and named `metadata.csv`. You can pass any CSV by using inserting `-csv path` before the `-alias` parameter when running the script.

You will be prompted to enter your CONTENTdm username and password, as well as the PSU License. These will be securely stored on your workstation and you wouldn't need to enter them again. If they are lost, you will be prompted to enter them again.

#### WARNINGS
  * **Controlled vocabularies and required fields (other than title) must be turned off before pitching metadata to catcher**. Make note of the settings and turn them back on after done batch editing.
  * **Field names used as headers are not the same as the field name labels in CONTENTdm**. Look at the `CISONICK` value in the Field Properties in the Admin Gui for the correct field name to use as the CSV header.
  * **Log directories need to be created** or pitcher will throw an error. You may have to create `logs` subdirectories in **both** your home directory and the active directory the `batchEdit.ps1` script is running from, if it does not already exist.