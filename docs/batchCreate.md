# Batch Create Items and Compound Objects
CONTENTdm's [Directory Structure](https://help.oclc.org/Metadata_Services/CONTENTdm/Compound_objects/Add_multiple_compound_objects/Directory_structure) specification gives flexibility for supplying files and metadata to batch load resources to digital collections. Files pre-arranged in the Directory Structure can be more efficiently loaded using Project Client. CONTENTdm Tools Batch Create is an easy way to process metadata and TIF images into the CONTENTdm Directory Strucure, ready for upload.

By combining parameters, you can create different types of batches based on your need. E.g.
* Create JP2 images and TXT transcript for every TIF and searchable PDF, with metadata in CONTENTdm tab-d format (derived item-level titles within compound objects)
* Metadata only output (skip JP2 and OCR outputs, skip originals handling)
* Processes existing TIF and JP2s into CONTENTdm load packages

## Inputs
* A directory containing subdirectories for each resource, an item or compound object, containing one or more TIF images.
* A CSV file called `metadata.csv` that contains values for the field properties for each resource.

## Outputs
### Batch of Compound Objects (Default)
Within each compound object subdirectory:
* A tab-delimited text file of compound object-level metadata and item-level metadata for each image.
* JP2 images for every TIF image using [GraphicsMagick](http://www.graphicsmagick.org/), saved in a `scans` subdirectory.
  * If necessary, TIFs will be converted so that the longest edge has 8000 pixels to prevent errors with the JP2 conversion. The original TIF is retained per `originals` parameter.
* TXT transcripts for every TIF image using [Tesseract OCR](https://github.com/tesseract-ocr/tesseract), saved in a `transcripts` subdirectory.
* PDF of the entire compound object (searchable, 200 PPI), saved in the compound object subdirectory (also using Tesseract).
* TIF images moved into an `originals` subdirectory.

### Batch of Items
Within the batch directory:
* a tab-delimited text file of item-level metadata for each image
* JP2 image for each item TIF using [GraphicsMagick](http://www.graphicsmagick.org/)

### Batch of Items and Compound Objects
Items and objects need to be loaded separately using Project Client, so Batch Create will create two subdirectories in the batch root directory: items and objects.
  * The items subdirectory contains the above description.
  * The objects subdirectory contains the above description.

## Usage
1. Create a batch directory to stage your batch of resources for CONTENTdm.
2. Within this batch directory, create subdirectories for each item or compound object and copy TIF files for each resource.
    * Best practice is to use the digital object identifier for the subdirectory name.
    * Supports redacted filesets. If `file.tif` and `file_redacted.tif` are present, `file_redacted.tif` will be used for creating all derivatives. The undredacted `file.tif` will be handled in accordance to the `-originals` parameter.
3. Save descriptive metadata for all resources as a CSV file named `metadata.csv` in the root directory of the batch.
    * Metadata may first be created using Excel or another progam and converted to CSV.
    * Always use UTF-8 character encoding when editing and saving.
    * All required fields (as configured in Field Properties) must to be present and conform to any data types or other validations. Other fields may be included or excluded as desired.
    * Supports access restrictions for object-only batches, *not supported for item or mixed item and object batches*. Include a metadata field called `Restriction Type` that includes one of the following values:
      * `none` -- open-access, normal
      * `local` -- PSU-access only
      * `total` -- total restriction, not to be loaded into CONTENTdm
        * If large swaths of content fall into this category, it is generally more efficient to exclude them from batches. But if it's one object within a larger batch, this works well.
    * **Add CONTENTdm Tools Required Fields**. CONTENTdm Tools needs some additional information to function.
      * `Directory` must be the first field/column in the CSV and contain the name of the subdirectory where the item/compound object files are saved.
      * `Level` is required as necessary and can optionaly be added as the second field/column to specify a resources type, item or compound object. If the field is omitted, all resources are assumed to be compound objects. **If batch only includes items, field is required.** Valid values for: `Item` and `Object`, case-sensitive.
    * `Title` should always be the first field after CONTENTdm Tools required fields.
4. Use CONTENTdm Tools Dashboard to start Batch Create or open PowerShell and navigate to where [contentdm-tools](https://github.com/psu-libraries/contentdmtools) is saved. It may be easier to navigate to this folder using Windows File Explorer and holding the shift key while right-clicking to select "Open PowerShell window here."
5. Use the command `batchCreate.ps1 -path C:\path\to\batch` to process batch of compound objects using all defaults. The outputs can be customized by using the following parameters:
     * `-path` specifies an absolute path to the batch directory.
     * `-metadata` specifies the filename for a CSV of metadata in the batch directory. DEFAULT value is `metadata.csv`.
     * `-jp2` indicates whether or not you need to generate JP2 images. This is useful for vended digization. (PDFs can also be passed through, just use the appropriate `-ocr` option.)
       * `true` if you are starting with only TIF images and need to generate JP2 images. DEFAULT.
       * `false` if you are starting with TIF and JP2 images and only need to organize them.
       * `skip` to bypass any JP2 actions.
     * `-ocr` will set the TXT and PDF outputs from Tesseract and Ghostscript. Ignored for item processing, only invoked for compound objects.
       * `text` to only generate TXT transcripts.
       * `PDF` to only generate a 200 ppi searchable PDF.
       * `both` to generate both TXT transcripts and a searchable PDF. DEFAULT.
       * `extract` to extract a TXT file from an existing PDF included in the object subdirectory.
       * `skip` to bypass any OCR actions.
     * `-ocrengine` will specify the OCR software to use.
       * `ABBYY` for ABBYY Recognition Server, expected to be [mapped to O: drive](https://git.psu.edu/digipres/documentation/wikis/Network-Drives-and-Shares). DEFAULT.
       * `tesseract` for Tesseract OCR.
     * `-originals`  will specify what to do with the original TIF images.
       * `keep` to save the originals. DEFAULT.
       * `discard` to delete them.
       * `skip` to bypass any action regarding originals.
     * `-throttle` specifies the number of CPU cores to use for parallel processing (JP2 conversion and OCR). DEFAULT value is 4.
     * `-verbose`  optional parameter to increase logging output.
     * Example: `batchCreate.ps1 -ocr text -ocrengine ABBYY -originals discard -path G:\pstsc_01822\2019-07\` will only create TXT transcripts (no PDF) and discard the original TIF images.
     * Example: `batchCreate.ps1 -jp2 skip -ocr skip -originals skip -path G:\pstsc_01822\2019-07\` will only generate metadata files. This is useful if you have already processed batches but had last minute metadata changes. You can run this over an already processed batch and it will save over the existing metadata.

## Adding batches to CONTENTdm
1. Open CONTENTdm Project Client and open a project pre-configured for the collection to which you are uploading.
1. Items and Compound Objects in different ways. If you batch has both, the files will be split into two easy to load subdirectories.
    * Items
      1. From the Add menu, select Multiple Items.
      1. Choose to import using a tab-delimited text file and paste in the filepath to `metadata.txt` created by Batch Create. (Don't include quotes/doublequotes in the filepath)
      1. Choose to import files from a directory and paste in the filepath to either the batch directory or items subdirectory (within the batch directory). This will be the same directory where `metadata.txt` is saved.
      1. **Do NOT have CONTENTdm generate display images** by choosing No.
      1. Always check the field mappings for correctness!
      1. Add the items and Q/C them in Project Client.
      1. Upload the items to CONTENTdm through Project Client.
    * Compound Objects
      1. If access restrictions have been applied to the batches, the batch directory may be organized into two or more subdirectories: `none`, `local`, and `total`. `none` will be loaded as described below. `total` *should NOT BE LOADED into CONTENTdm*. `local` will need to have item-permissions applied within Project Client.
      1. From the Add menu, select Compound Objects, then choose the Directory Structure from the drop down and click Add.
      1. Choose the appropriate compound object type and browse to select the directory containing the batch.
      1. Confirm that images are saved in a `scans` subdirectory.
      1. **Do NOT have CONTENTdm generate display images** by choosing No.
      1. Label pages using a tab-delimited text file and import `transcripts` from a directory (if using), and check the box to create a Print PDF if desired*.
      1. Always check the field mappings for correctness! If the fields metadata.csv are in the same order as the field properties for the collection, they *should* be correctly mapped.
      1. Add the compound objects and Q/C them using Project Client.
      1. If this is a batch with `local` access restrictions, perform the following steps for each compound object:
         1. Open the compound object in a tab.
         1. In the structure panel, click on the object-level node, represented with a folder icon. (This will apply the restrictions on the items within the compound object.)
         1. From the left-side panel, click on Permissions, under Item Editing Tasks.
         1. Click the Add button next to "All IP Addresses" and paste in a semicolon separated list of IP addresses for the PSU Network. (See a CONTENTdm Administrator if you need this list.)
         1. If appropriate, check the box for "Only require permission for the image. Metadata is open to public."
         1. Click OK.
      1. Upload the compound objects through Project Client.
2. Approve and index the compound objects through the Administrative User Interface to add the compound objects to the collection.

&ast; There is no way to upload the generated searchable PDF as the Print PDF that Project Client generates here. Depending on your volume, OCLC is able to load customer created PDFs as the Print PDF on a consultant basis.

## Limitations
* [Monograph compound objects](https://help.oclc.org/Metadata_Services/CONTENTdm/Compound_objects/Add_multiple_compound_objects/Directory_structure#Monographs)  (hierarchical compound objects with defined structure) such as Sections or Chapters, have not been tested but should work.
* Picture Cube and Postcard compound objects have not been tested.
* Item-level metadata is derived using JP2 files. If you are not generating or including JP2 files, item-level metadata will not be generated.