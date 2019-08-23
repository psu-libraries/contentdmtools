# Batch OCR/Re-OCRing a CONTENTdm Collection
As OCR technology has improved, it is sometimes beneficial to re-run collection objects through OCR for improved transcripts. The `batchOCR.ps1` script will find all the JP2 or JPG images in a collection, including from within Document or Monograph Compound Objects, and run them through Tesseract OCR engine, then send the new OCR data back to CONTENTdm. It can also be useful for adding OCR transcripts to collections that didn't previously have them.

This script uses the [Batch Editing](batchEdit.md) script at the end to send the new transcripts to CONTENTdm. If you haven't used `batchEdit.ps1` before, you should save your CONTENTdm user credentials into CONTENTdm Tools using the dashboard, or you will be prompted to enter your password, and possibly a server URL and license.

**The collection field you specify must be a field with the data type `Full Text Search`**. This field doesn't have to be displayed, but it should be searched. You will need to know this field's nickname (not the same as the field name) to pass as a parameter. You can look these up in the dashboard.

**Controlled vocabularies and required fields (other than title) must be turned off before running batchEdit** or CONTENTdm Catcher will throw an error. Make note of the settings and turn them back on when done indexing the changes.

A temporary subdirectory will be created in your CONTENTdm Tools directory where images will be downloaded and processed. Depending on the size of the collection, *this could take up a large amount of disk space*. You can also specify a temporary staging location with the `-path` parameter.

### Caveats:
  * OCR performance is only as good as the quality of the files. If the original files are poor quality or low-resolution, re-running may not show many (or any) improvements to the OCR quality.
  * Only alpha-numeric characters, some punctuation, and a couple of special characters are retained in the OCR output; all other characters are stripped out. This helps prevent problems down the road. The characters retained are in this list of ranges/characters: `a-zA-Z0-9_.,!?$%#@`.
  * Line breaks are removed from the OCRed text before it's added to the CSV because they tend to cause problems. This doesn't affect searching.

## Usage
1. Open a PowerShell window and navigate to your CONTENTdm Tools root directory.
2. Enter the following command to begin: `.\batchOCR.ps1 -collection collectionAlias -field transcriptFieldNickname -path "C:\path\to\staging" -public https://urlToPublicCONTENTDM.edu -server https://urlToAdministrativeServer.edu`
     * `-path` -- Path to a directory to stage tempory files generated during OCR process. Should have ample free disk space! (Defaults to CONTENTdm Tools subdirectory if left out.)
     * `-collection` -- Collection alias for the CONTENTdm collection you wish to re-OCR. REQUIRED
     * `-field` -- Collection field configured with the data type `Full Text Search`. REQUIRED
     * `-user` -- Username for a CONTENTdm user. REQUIRED
     * `-throttle` specifies the number of CPU cores to use for parallel processing (image downloading and OCR).
     * `-public` -- URL to the Public UI CONTENTdm website. (Defaults to stored settings is left out.)
     * `-server` -- URL to the Administrative UI. This may include a port number for self-hosted instances. (Defaults to stored settings is left out.)
     * `-license` -- CONTENTdm License. (Defaults to stored settings is left out.)
3. Depending on the size of the collection, this could take a long time to run. You can watch the terminal output as it progresses or review the log afterwards. It will end with a (very) brief report on the results.
4. Log into the Administrative UI and index the collection to complete the process. Approving is not necessary for items uploaded through CONTENTdm Catcher.
5. After indexing, be sure to return field properties back to their original setting, if needed.