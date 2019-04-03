# Miscellaneous Batch Loading Scripts

## batchLoadCLIR.ps1

The end result of this script is the same as `batchLoadCreate.ps1`, but it creates that output differently. This script was written to prepare files for OCLC to load into CONTENTdm, but with some refactoring, could be used to improve the default script. Below is a summary of the differences.

- Processing loops over each object directory and performs all the necessary actions instead of acting on all the files accross all objects at once.
- Item metadata is added to the individual object metadata TXT files. Because this is automated, the only information that is added is the file name and a title. Titles are a sequential page number (e.g. Page 1, Page 2, etc.).
- JP2 files are expected to be supplied, not generated.
- A complete, searchable PDF is expected to be supplied and is used to generate TXT transcripts.
- TIF files are deleted automatically

### Dependencies
- [PDFtk](https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/) is required to split PDFs into separate pages. PDFtk Free for Windows includes the necessary command line tool.
- [XPDF Command Line Tools](https://www.xpdfreader.com/download.html) are required to extract text from PDF pages. You will need to copy or move the `pdftotext.exe` file to the same directory that `batchLoadCLIR.ps1` runs from.