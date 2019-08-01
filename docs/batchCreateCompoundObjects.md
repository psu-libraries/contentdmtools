# Creating a Batch of CONTENTdm Compound Objects (Document Type)
CONTENTdm's [Directory Structure](https://help.oclc.org/Metadata_Services/CONTENTdm/Compound_objects/Add_multiple_compound_objects/Directory_structure) specification gives flexibility for supplying files and metadata for a batch of compound objects that are being loaded to the same collection. Files arranged in the Directory Structure can be efficiently loaded using Project Client and avoid some of its limitations.

This script will take
* a directory containing subdirectories for each document-type compound object, each containing TIF images,
* a metadata CSV file called `metadata.csv` that contains compound object-level metadata,

and create within each compound object subdirectory
* a tab-delimited text file of compound object-level metadata and item-level metadata for each image, and
* JP2 images for every TIF image using [GraphicsMagick](http://www.graphicsmagick.org/), saved in a `scans` subdirectory.
* run [Tesseract OCR](https://github.com/tesseract-ocr/tesseract) to
  * create TXT transcripts for every TIF image, saved in a `transcripts` subdirectory, and
  * create a 200 ppi searchable PDF for the entire compound object, saved in the compound object subdirectory; and
* move TIF images into an `originals` subdirectory.

## Usage
1. Create a batch directory to stage your batch of compound objects for CONTENTdm.
2. Within this batch directory, create subdirectories for each compound object and copy TIF files for each object.
    * Best practice is to use the digital object identifier for the subdirectory name.
3. Save metadata for all compound objects in the batch as a CSV file named `metadata.csv` in the root the batch directory.
    * Metadata may first be created using Excel or another progam and converted to CSV.
    * Always use UTF-8 character encoding when editing and saving.
    * All fields from the collections Field Properties need to be present and conform to any data types or other validations.
      * `Title` should always be the first column. It will soon be the second when you add `Directory`.
    * **Two additional fields will needed**
      * `Directory` as the first column, followed by `Title`. This should contain the name of the subdirectory where the compound object files are stored in the batch directory.
      * `File Name` as the last column.
4. Open PowerShell and navigate to where [contentdm-tools](https://github.com/psu-libraries/contentdmtools) are saved. It may be easier to navigate to this folder using Windows File Explorer and hold the shift key while right-clicking to select "Open PowerShell window here."
5. Use the command `batchCreateCompoundObjects.ps1 -path C:\path\to\batch` to process batch of compound objects as described above. The outputs can be customized by using the following parameters:
     * `-metadata` specifies the path and filename for a CSV of metadata.
       * DEFAULT value is `metadata.csv`. Any file is assumed to be in the root directory of `-path`.
     * `-jp2` indicates whether you or not you need to generate JP2 images. This is useful for vended digization. (PDFs can also be passed through, just use the appropriate `-ocr` option.)
       * `true` if you are starting with only TIF images and need to generate JP2 images. DEFAULT.
       * `false` if you are starting with TIF and JP2 images and only need to organize them.
       * `skip` to bypass any JP2 actions.
     * `-ocr` will set the TXT and PDF outputs from Tesseract and Ghostscript
       * `text` to only generate TXT transcripts.
       * `PDF` to only generate a 200 ppi searchable PDF.
       * `both` to generate both TXT transcripts and a searchable PDF. DEFAULT.
       * `skip` to bypass any OCR actions.
     * `-originals`  will specify what to do with the original TIF images
       * `keep` to save the originals. DEFAULT.
       * `discard` to delete them.
       * `skip` to bypass any action regarding originals.
     * Example: `batchCreateCompoundObjects.ps1 -ocr text -originals discard -path G:\pstsc_01822\2019-07\` will only create TXT transcripts (no PDF) and discard the original TIF images.
     * Example: `batchCreateCompoundObjects.ps1 -jp2 skip -ocr skip -originals skip -path G:\pstsc_01822\2019-07\` will only generate metadata files. This is useful if you have already processed batches, but had last minute metadata changes. You can run this over a already processed batch and it will save over the existing metadata.
   
### Adding batches to CONTENTdm
1. Open CONTENTdm Project Client and open a project pre-configured for the collection to which you are uploading.
2. From the Add menu, select Compound Objects, then choose the Directory Structure from the drop down and click Add.
3. Choose the appropriate compound object type and browse to select the directory containing the batch.
4. Confirm that images are saved in a `scans` subdirectory.
5. **Do NOT have CONTENTdm generate display images** by choosing No.
6. Label pages using a tab-delimited text file and import `transcripts` from a directory (if using), and check the box to create a Print PDF if desired*.
7. Always check the field mappings for correctness!
8. Upload the compound objects through Project Client.
9. Approve and index the compound objects through the Administrative User Interface to add the compound objects to the collection.

&ast; There is no way to upload the generated searchable PDF as the Print PDF that Project Client generates here. Depending on your volume, OCLC is able to load customer created PDFs as the Print PDF on a consultant basis.

## Gotchas and Limitations
### PowerShell and the PowerShell Execution Policy
This script was written using Windows PowerShell 5.1, which is installed on almost every Windows computer. To run PowerShell scripts, you need to first run a command that allows them. To do this, open PowerShell with Administrative Rights and run the following command: `Set-ExecutionPolicy Unrestricted`.

If you are unable to run PowerShell with Administrative Rights, you should be able to run the following command, but it may need to be in every session. `powershell.exe -ExecutionPolicy bypass`

### Limitations
* [Monograph compound objects](https://help.oclc.org/Metadata_Services/CONTENTdm/Compound_objects/Add_multiple_compound_objects/Directory_structure#Monographs), or compound objects with defined structure, such as Sections or Chapters, have not been tested, but should work.
* Picture Cube and Postcard compound objects have not been tested.
* This script has only been tested on Windows Powershell 5.1, but might work on other platforms with Powershell Core 6+.

## Dependencies
CONTENTdm Tools uses openly-licensed tools to process images. These tools are already included, so you don't need to install anything. They are listed here to credit the original projects and their contributors.
* [Ghostscript](https://ghostscript.com/) -- A tool for processing PDF files, used here to merge PDFs and downsample image resolution within PDFs.
* [GraphicsMagick](http://www.graphicsmagick.org/) -- "The swiss army knife of image processing", used here to convert TIF to JP2, while ensuring JP2 compliance and color management.
  * [ImageMagick](https://imagemagick.org/index.php) -- GraphicsMagick itself is based on an earlier project called ImageMagick.
* [Tesseract OCR](https://github.com/tesseract-ocr/tesseract) -- Tesseract is the leading open-source OCR package and currently developed by Google. Used here to convert TIF to TXT and generate searchable PDFs.
