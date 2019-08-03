# Batch Re-OCRing a CONTENTdm Collection
As OCR technology has improved, it is sometimes beneficial to re-run collection objects through OCR for improved transcripts. This script can also be useful to add OCR transcripts to collections that didn't previously have them. This script uses the [Batch Editing](batchEdit.md) script at the end to send the new transcripts to CONTENTdm, if you haven't used batchEdit.ps1 before, you will be prompted to enter a credentials for CONTENTdm and a License number.

**The collection must have a field with the data type `Full Text Search`**. This field doesn't have to be displayed, but it should be searched. You will need to know this field's nickname (not the same as the field name) to pass as a parameter. 

**Controlled vocabularies and required fields (other than title) must be turned off before running batchEdit** or CONTENTdm Catcher will throw an error. Make note of the settings and turn them back on indexing the changes.

A temporary subdirectory will be created in your CONTENTdm Tools directory where images will be downloaded and processed. Depending on the size of the collection, **this could take up a large amount of disk space*.

### Caveats:
  * OCR is only as good as the files. If the original files are poor quality or low-resolution, rerunning may not show many improvements to the OCR quality (or none).
  * Only alpha-numeric characters, some punctuation, and a couple special characters are retained in the OCR output, all other characters are stripped out. This helps prevent problems down the road. The characters retained are in this list of ranges/characters: `a-zA-Z0-9_.,!?$%#@`.
  * Line breaks are removed from the OCRed text before it's added to the CSV because they tend to cause problems. This doesn't affect searching.

## Usage
1. Open a PowerShell window and navigate to your CONTENTdm Tools root directory.
2. Enter the following command to begin: `.\batchReOCR.ps1 -collection collectionAlias -field transcriptFieldNickname -path "C:\path\to\staging" -public https://urlToPublicCONTENTDM.edu -server https://urlToAdministrativeServer.edu`
     * `-collection` -- Collection alias for the CONTENTdm collection you wish to re-OCR.
     * `-field` -- Collection field configured with the data type `Full Text Search`.
     * `-path` -- Path to a directory to stage tempory files generated during OCR process. Should have ample free disk space!
     * `-public` -- URL to the Public UI CONTENTdm website. *No trailing slash*.
     * `-server` -- URL to the Administrative UI. This may include a port number for self-hosted instances. *No trailing slash*.
3. Depending on the size of the collection, this could take a long time to run. You can watch the terminal output as it goes or review the log afterwards. It will end with a (very) brief report on the results.
4. Log into the Administrative UI and index the collection to complete the process. Approving is not necessary for items uploaded through CONTENTdm Catcher.
5. After indexing, be sure to return field properties back to their original setting, if needed.