# Re-OCRing Old Collections using ABBYY OCR Recognition Server

ABBYY Recognition Server, used in workflows for building new digital collections, is much more accurate than the version of ABBYY included in Project Client. Curators may ask that older collection be re-OCRed to take advantage of the more accurate OCRing. The process and tools outlined here are one strategy for achieving this, using [Pitcher](https://github.com/little9/pitcher) (see [Batch Editing](https://git.psu.edu/digipres/contentdm/tree/master/batchEdit).) 

This process is both manual and automated. It may be easier to batch for large collections.

**Caveat: OCR is only as good as the files. If the original files are poor quality or low-resolution, rerunning may not show many improvements to the OCR quality (or none).**

Starting with files or metadata can be a bit of a chicken and egg problem. Sometimes, it's very easy to tell how the metadata relates to the files we have stored on Isilon, othertimes it is very difficult to match them and is actually easier to pull the files from old self-hosted CONTENTdm files.*

1. Export collection metadata from CONTENTdm and isolate items being re-OCRed.
2. Stage the OCR files.
  * Assemble all the files necessary and run them through ABBYY. You want a single text file per image file.
  * Create a project directory somewhere on your computer. Within this directory, create a subdirectory called `text`. Move all the text files into this directory.
2. Create `metadata_preOcr.csv`
  * In the root of the project directory, create a CSV with the following columns and populate the data:
    * `cdmnumber`: ID of the item being updated.
    * `field`: Nickname of the metadata field being updated.
    * `collection`: Alias of the collection the items belong to.
    * `action`: Should always equal `edit`.
    * `file` : Relative path to the text file. E.g. `text\file.txt`.
3. On a Windows computer, in PowerShell, run `.\batchReOCR.ps1`. This will create a `|` delimited text file in your project folder called `metadata_pitcher_pipe.txt`. Open Excel or another spreadsheet program and import this data. Check the spreadsheet to see if any files were missed or if any fields need to be recopied. (Sometimes `collection` and `action` need to be copied down again.) If you do not have any files with OCR text, delete them from the spreadsheet -- do not leave any rows with blank `value` fields or they will be wiped out when updating CONTENTdm. Once everything is set, delete the `file` column and save the file as `metadata.csv`.
4. Run `pitcher --csv metadata.csv --settings settings.yml`. There are some dependencies if you haven't used Pitcher before, see [Batch Editing](https://git.psu.edu/digipres/contentdm/tree/master/batchEdit)
5. Index the collection in the CONTENTdm Admin UI. 
6. Unlock all the items in the CONTENTdm Admin UI.

*This can take some wrangling and sometimes a bit of command line magic can help. Using the CONTENTdm API can be helpful for determining the IDs contained within a Compound Object; e.g. https://digital.libraries.psu.edu/digital/bl/dmwebservices/index.php?q=dmGetCompoundObjectInfo/pageol/3862/json [JSON is ouput, but can be converted to CSV](http://www.convertcsv.com/json-to-csv.htm).  See Nathan for assistance.