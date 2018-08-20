## Creating Batch Loads for CONTENTdm

For batch-loading like compound objects into CONTENTdm, University Libraries uses the [Directory Structure](https://www.oclc.org/support/services/contentdm/help/compound-objects-help/adding-multiple-compound-objects/directory-structure.en.html) specification. When loading batches of compound objects, they must all be the same type of compund object: document or monograph. If both types are used in a collection, they will have to be uploaded in separate batches.

This script will take: 
  * a directory containing subdirectories for each compound object, each contaning a subdirectory called "scans" with TIF images
     * this directory should be named with the local digital object identifier, the directory name MUST be in the metadata spreadsheet.
  * a master metadata spreadsheet in tab-delimited text format
   
and process out:

  * individual tab-delimited text format metadata spreadsheets, saved in the appropriate compund object subdirectory

with the correct switches, the script can also:
  * run the TIF images through ABBYY Recognition Server and save text output in a subdirectory called transcripts in the compound object subdirectory
  * convert the TIF images to JP2 for CONTENTdm
  * delete the TIF images from the upload package.

This script uses PowerShell and is designed to run in Windows workstations.

### ABBYY Recognition Server
This script expects users to have the ABBYY Recognition server storage mapped to their `O:` drive.

### ImageMagick
The CONTENTdm packging script requires [ImageMagick for Windows](https://www.imagemagick.org/script/download.php#windows) to be installed if you plan to convert TIF images to JP2.

### Usage

1. Create a directory to stage your batch of compound objects for CONTENTdm.
2. Within this directory, create subdirectories for each compound object and copy TIF files for each object.
    * (Best practice is to use the digital object identifier for the subdirectory name.)
3. Save metadata for objects in the batch as a tab-delimited text file named `metadata.txt`.
    * Metadata may be created in an Excel Spreadsheet and need some work to become a tab-delimited text file. Some possible work includes:
       * Moving `File Name` to penultimate field
       * Moving `Directory` to last field
       * Removing `Level` field
       * Find/Replace in `File Name` field `.tif` to `.jp2`
       * Ensuring Date fields are text fields and in YYYY-MM-DD format
       * Saving as a tab-delimited text file, being sure that date fields are saved as text.
4. Copy the script to the root of the batch directory.
5. Open PowerShell and navigate to the root of the batch directory.
6. Type the following command and press enter to process metadata only: `.\batchLoadCreate.ps1 `
    * To also OCR images: `.\batchLoadCreate.ps1 -ocr`
    * To also convert TIF to JP2: `.\batchLoadCreate.ps1  -ocr -deriv`
    * To also delete TIFs `.\batchLoadCreate.ps1 -ocr -deriv -deltif`
    * The script has only been tested to work in this order.

### Adding batch to CONTENTdm

1. Open CONTENTdm Project Client and open a project pre-configured for the collection to which you are uploading.
2. Add Compound Objects, Add using Directory Structure.
3. Choose the compound object type and select the directory containing the batch.
4. Confirm that images are saved in a scans subdirectory.
5. If you are uploading JP2 images, choose No, do NOT have CONTENTdm generate display images.
6. Label pages using a tab-delimited file, import transcripts form a directory (if using), create a print PDF (if using).
7. Map fields. Most of the initial fields should be in order, the later fields, starting with Notes will be mis-alligned and need maping. For Directory, choose None.
8. Upload, approve, and index to add the compound objects to the collection.

### CONTENTdm Directory Structure Batches
Batches should look like this, *before processing*. Place a copy of the `batchLoadCreate.ps1` script in the root of the batch directory, `kirschner_2018-08-10` in this example.

```
|-- kirschner_2018-08-10\ 
  |-- pstsc_09844_e15ca556987b120ed80a50444194464a\ 
    |-- scans\ 
      |-- pstsc_09844_e15ca556987b120ed80a50444194464a_00001_001.tif 
      |-- pstsc_09844_e15ca556987b120ed80a50444194464a_00001_002.tif 
  |-- pstsc_09844_f7ae89ead71bbef39f250bf73e76e550\ 
    |-- scans\ 
      |-- pstsc_09844_f7ae89ead71bbef39f250bf73e76e550_00001_001.tif 
      |-- pstsc_09844_f7ae89ead71bbef39f250bf73e76e550_00001_002.tif 
  |-- metadata.txt (or metadata.xslx) 
```

### ToDo
  - [ ] Monograph Compound Objects