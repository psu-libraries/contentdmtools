# Creating Batch Loads for CONTENTdm

For batch-loading like compound objects into CONTENTdm, University Libraries uses the [Directory Structure](https://www.oclc.org/support/services/contentdm/help/compound-objects-help/adding-multiple-compound-objects/directory-structure.en.html) specification. When loading batches of compound objects, they must all be the same type of compound object: document or monograph (2-levels only). If both types are used in a collection, they will have to be uploaded in separate batches. This script uses PowerShell and is designed to run in Windows workstations.

This script will take: 
  * a directory containing subdirectories for each compound object, each containing TIF images
  * a master metadata file in tab-delimited text format called `metadata.txt`

and process out:

  * individual tab-delimited text format metadata files, saved in the appropriate compound object subdirectory

with the correct switches, the script can also:
  * run the TIF images through ABBYY Recognition Server to generate TXT and JP2 derivatives and save them in the correct compound object subdirectory for Project Client
  * delete the TIF images from the upload package.

## Usage

1. Create a directory to stage your batch of compound objects for CONTENTdm.
2. Within this directory, create subdirectories for each compound object and copy TIF files for each object.
    * Best practice is to use the digital object identifier for the subdirectory name.
3. Save metadata for all compound objects in the batch as a tab-delimited text file named `metadata.txt`.
    * Metadata may first be created using the Excel template and converted to a tab-delimited text file. Before converting, please make the following adjustments.
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

## Adding batch to CONTENTdm

1. Open CONTENTdm Project Client and open a project pre-configured for the collection to which you are uploading.
2. Add Compound Objects, choose the Directory Structure and click Add.
3. Choose the compound object type from the drop down and select the directory containing the batch.
4. Confirm that images are saved in a `scans` subdirectory.
5. Do NOT have CONTENTdm generate display images by choosing No.
6. Label pages using a tab-delimited file and import transcripts from a directory (if using), and check the box to create a print PDF.
7. Always check the field mappings. Most of the initial fields should be in order, the later fields, starting with Notes may be misaligned and need re-mapping. For File Name and Directory, choose None.
8. Upload, approve, and index to add the compound objects to the collection.

## Dependencies

### ABBYY Recognition Server

This script expects users to have the ABBYY Recognition server storage mapped to their `O:` drive.

### ImageMagick

The CONTENTdm packging script requires [ImageMagick for Windows](https://www.imagemagick.org/script/download.php#windows) to be installed if you plan to convert TIF images to JP2.

## ToDo
  - [ ] Hierarchical Monograph Compound Objects