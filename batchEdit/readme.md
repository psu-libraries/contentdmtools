## Batch Editing Items
The `batchEdit.ps1` script can be used to process `metadata.csv`, **include changed values only**, into a csv of change records that can be fed into [CONTENTdm Catcher](https://www.oclc.org/support/services/contentdm/help/add-ons-help/contentdm-catcher.en.html) via [Pitcher](https://github.com/little9/pitcher). If successfully loaded from catcher, they need to be indexed in the Administrative GUI.

### Ruby and Pitcher
You will need to have [ruby installed](https://rubyinstaller.org/downloads/) and the [pitcher gem installed](https://github.com/little9/pitcher). You will need to have a `settings.yml` file in the same directory as `batchEdit.ps1`. A sample is in this repository, see Nathan Tallman (or CDM admin notebook) for the password to the `psucdmcatcher` worldcat user. You can use your own user credentials, however, be warned the logs will contain your password in plaintext.

### Usage
Run `.\batchEdit.ps1 -alias collecitonAlias` to kick off the script. The data table of metadata changes should be in the in the same directory as the script and named `metadata.csv`.

#### WARNINGS
  * **Controlled vocabularies and required fields (other than title) must be turned off before pitching metadata to catcher**. Make note of the settings and turn them back on after done batch editing.
  * **Field names used as headers are not the same as the field name labels in CONTENTdm**. Look at the `CISONICK` value in the Field Properties in the Admin Gui for the correct field name to use as the CSV header.
  * **Log directories need to be created** or pitcher will throw an error. You may have to create `logs` subdirectories in **both** your home directory and the active directory the `batchEdit.ps1` script is running from, if it does not already exist.