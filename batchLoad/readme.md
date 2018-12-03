# Creating Batch Loads for CONTENTdm
For batch-loading like compound objects into CONTENTdm, University Libraries uses the [Directory Structure](https://www.oclc.org/support/services/contentdm/help/compound-objects-help/adding-multiple-compound-objects/directory-structure.en.html) specification. When loading batches of compound objects, they must all be the same type of compound object: document or monograph (2-levels only). If both types are used in a collection, they will have to be uploaded in separate batches. This script uses PowerShell and is designed to run in Windows workstations.

This script will take
  * a directory containing subdirectories for each compound object, each containing TIF images,
  * a master metadata file in tab-delimited text format called `metadata.txt`,

and process out

  * individual tab-delimited text format metadata files, saved in the appropriate compound object subdirectory

with the correct switches, the script can also
  * run the TIF images through ABBYY Recognition Server to generate TXT and JP2 derivatives and save them in the correct compound object subdirectory for Project Client, and
  * delete the TIF images from the upload package.

## Usage
1. Create a directory to stage your batch of compound objects for CONTENTdm.
2. Within this directory, create subdirectories for each compound object and copy TIF files for each object.
    * Best practice is to use the digital object identifier for the subdirectory name.
3. Save metadata for all compound objects in the batch as a tab-delimited text file named `metadata.txt`.
    * Metadata may first be created using the Excel template and converted to a tab-delimited text file. 
    * To easily add filenames to Excel
       * Open a compound object subdirectory in Windows Explorer and view it as a list
       * Select all files and right-click while holding down the shift key
       * Choose `Copy as path`
       * In a new Excel sheet, click into the A1 cell and paste in the file paths
       * From the Data ribbon, use Text to Columns in the Data Tools section to split the cells (use a custom delimiter `\`) and the filenames should be in the last cell on the right
       * After pasting the filenames into the master sheet for all compound objects, delete the extra sheet, you should have only one sheet before you save as a tab-delimited text file.
    * Before converting, please make the following adjustments.
       * Move `File Name` to penultimate field
       * Move `Directory` to last field
       * Delete the `Level` field
       * Find/Replace `.tif` to `.jp2` in `File Name` field
       * Ensure that date fields are in YYYY-MM-DD format
4. Copy the script to the root of the batch directory.
5. Open PowerShell and navigate to the root of the batch directory.
6. Type the following command and press enter to process metadata only: `.\batchLoadCreate.ps1 `
    * To also run the images ABBYY for TXT and JP2 derivatives: `.\batchLoadCreate.ps1 -abbyy`
      * To also delete TIFs `.\batchLoadCreate.ps1 -abbyy -deltif`
    * To also convert TIF to JP2 using ImageMagick: `.\batchLoadCreate.ps1  -im`
      * To also delete TIFs `.\batchLoadCreate.ps1 -im -deltif`
      * Note, this will not generate text transcripts.

### Adding batches to CONTENTdm
1. Open CONTENTdm Project Client and open a project pre-configured for the collection to which you are uploading.
2. Add Compound Objects, choose the Directory Structure and click Add.
3. Choose the compound object type from the drop down and select the directory containing the batch.
4. Confirm that images are saved in a `scans` subdirectory.
5. Do NOT have CONTENTdm generate display images by choosing No.
6. Label pages using a tab-delimited file and import transcripts from a directory (if using), and check the box to create a print PDF.
7. Always check the field mappings. Most of the initial fields should be in order, the later fields, starting with Notes may be misaligned and need re-mapping. For File Name and Directory, choose None.
8. Upload, approve, and index to add the compound objects to the collection.

### Metadata and Batch Examples
  * [batchLoad_metadataExample](https://psu.box.com/s/zuulqnvhd7d11xqs8j586403zrycy5sv)
     * This metadata Excel spreadsheet shows the three extra columns (Level, Directory, and File Name) used in this process. The rest of the columns are determined the collection fields and may not match this example. If all the records are blank for a particular column, it may be deleted before being converted to a tab-delimited text file.
  * [batchLoad-preProcessingExample.zip](https://psu.box.com/s/f8o8g9zhek5p09oam2hq0fpmyilse9vz)
       * Shows the TIF images organized into subdirectories by compound object and the master Excel metadata spreadsheet before being saved as a tab-delimited text file.
  * [batchLoad-postProcessingExample.zip](https://psu.box.com/s/y8hfouij1ueh2tyyhsl74995zjhbow0k)
       * Shows the master metadata in tab-delimited text format with subdirectories by compound object. Each subdirectory contains a metadata for the object and items in tab-delimited text format and two additional subdirectories: `scans` and `transcripts`. Scans includes JP2 files and transcripts includes TXT files.

## Dependencies
### PowerShell Execution Policy
To run Powershell scripts, you need to first run a command to allow them. To do this, you will need to open Powershell with Privilege Guard and run the following command: `Set-ExecutionPolicy RemoteSigned`.

### ABBYY Recognition Server
This script expects users to have the ABBYY Recognition Server storage share mapped to the `O:` drive. The network path for the storage share is `l5abbyy01.psul.psu.edu\Abbyy_OCR`. Contact [Beth Rea](mailto:baz5008@psu.edu) if you need authorization to access the share.

### ImageMagick
If choosing to convert TIF to JP2 using ImageMagick instead of ABBYY, [ImageMagick for Windows](https://www.imagemagick.org/script/download.php#windows) must be installed on the workstation.

### UTF-8 Encoding
When ever the end product is intended for digital collections, please ensure that [character encoding is set to UTF-8 when you are working with tabular data, whether in Excel, OpenOffice, or LibreOffice](https://psu.box.com/s/v9glyv724f9g3d1ko2wz6on8l76jiybq).

## To Do
  - [ ] Hierarchical Monograph Compound Objects
  - [ ] Refactor to use the identifier field and get rid of the directory field