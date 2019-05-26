# batchLoadCreate.ps1
# Nathan Tallman, Created in August 2018, updated in November 2018
# Modified in April 2019 for CLIR grant, updated 10 May 2019
# https://git.psu.edu/digipres/contentdm/edit/master/batchLoad
# this is fragile, only works for this collection as of this date, will break if the number of fields change. This could probably be refactored to read number of fields and generate stuff as needed?

## Dependencies
# pdftk is needed to split pdfs
# XPDF CLI needed for text extraction https://xpdfreader-dl.s3.amazonaws.com/xpdf-tools-win-4.01.01.zip

# Read in arguments
[cmdletbinding()]
Param(
  [string]$source = $(Throw "Use -source to specify a path for the batch.")
)

# Setup timestamps and global variables
function Get-TimeStamp { return "[{0:yyyy-MM-dd} {0:HH:mm:ss}]" -f (Get-Date) }
$batch = $source | Split-Path -Leaf
$log = ($source\$batch + "_cdmPrepCLIR_log.txt")
Write-Output "$(Get-Timestamp) CLIR CONTENTdm Prep Starting." | Tee-Object -file $log

# Read in the metadata and setup array for each object
$metadata = Import-Csv -Path "$source\metadata.csv"
$directories = $metadata | Group-Object -AsHashTable -AsString -Property Directory

# Establish loop for each object directory
ForEach ($directory in $directories.keys)
{
  # Create object metadata txt in each object directory
  Write-Output "Entering $directory for processing." | Tee-Object -file $log -Append
  $directories.$directory |Export-Csv -Delimiter "`t" -Path $source\$directory\$directory.txt -NoTypeInformation  | Tee-Object -file $log -Append
  Write-Output "    $(Get-Timestamp) Object metadata has been broken up into the the Directory Structure." | Tee-Object -file $log -Append

  # split object PDFs and move complete PDF to tmp directory
  pdftk $source\$directory\$directory.pdf burst output $source\$directory\$directory-%02d.pdf | Tee-Object -file $log -Append
  Remove-Item $source\$directory\doc_data.txt | Tee-Object -file $log -Append
  if(!(Test-Path $source\$directory\tmp)) { New-Item -ItemType Directory -Path $source\$directory\tmp | Out-Null }
  Move-Item $source\$directory\$directory.pdf -Destination $source\$directory\tmp | Tee-Object -file $log -Append
  Write-Output "    $(Get-Timestamp) PDF split into pages." | Tee-Object -file $log -Append

  # Add PDF to item metadata
  $pdfrow = "{0}`t{1}`t{2}`t{3}`t{4}`t{5}`t{6}`t{7}`t{8}`t{9}`t{10}`t{11}`t{12}`t{13}`t{14}`t{15}`t{16}`t{17}`t{18}`t{19}`t{20}`t{21}`t{22}`t{23}`t{24}`t{25}" -f """""", """""", """$directory.pdf""", """Complete PDF""", """""", """""", """""", """""", """""", """""", """""", """""", """""", """""", """""", """""" ,"""""", """""", """""", """""", """""", """""", """""", """""", """""", """""", """"""
  $pdfrow | Out-File $source\$directory\$directory.txt -Append -Encoding ASCII
  Write-Output "    $(Get-Timestamp) PDF item metadata has been added." | Tee-Object -file $log -Append

  # Add item metadata to metadata txt, including file names and seqential titles (Page 1, Page 2, etc.)
  # Refactor to dynamically read headers and generate row
  $i=1
  Get-ChildItem *.jp2 -Path $source\$directory | ForEach-Object {
    $row = "{0}`t{1}`t{2}`t{3}`t{4}`t{5}`t{6}`t{7}`t{8}`t{9}`t{10}`t{11}`t{12}`t{13}`t{14}`t{15}`t{16}`t{17}`t{18}`t{19}`t{20}`t{21}`t{22}`t{23}`t{24}`t{25}" -f """""", """""", $_, """Page $i""", """""", """""", """""", """""", """""", """""", """""", """""", """""", """""", """""", """""" ,"""""", """""", """""", """""", """""", """""", """""", """""", """""", """""", """"""
    [array]$item = $row
    $item | Out-File $source\$directory\$directory.txt -Append -Encoding ASCII
    $i++
  }
  Write-Output "    $(Get-Timestamp) Page item metadata has been added." | Tee-Object -file $log -Append

  # Move JP2 to scans directory
  if(!(Test-Path $source\$directory\scans)) { New-Item -ItemType Directory -Path $source\$directory\scans | Out-Null }
  Get-ChildItem *.jp2 -Path $source\$directory | ForEach-Object { Move-Item $source\$directory\$_ -Destination $source\$directory\scans | Tee-Object -file $log -Append }
  Write-Output "    $(Get-Timestamp) JP2 files have been moved to the scans directory." | Tee-Object -file $log -Append

  # Move PDFs to transcripts directory because we won't be able to distinguish metadata from text otherwise
  if(!(Test-Path $source\$directory\transcripts)) { New-Item -ItemType Directory -Path $source\$directory\transcripts | Out-Null }
  Get-ChildItem *.pdf -Path $source\$directory | ForEach-Object { Move-Item $source\$directory\$_ -Destination $source\$directory\transcripts | Tee-Object -file $log -Append }

  #Extract text and delete item PDF
  Get-ChildItem *.pdf -Path $source\$directory\transcripts | ForEach-Object {
    .\pdftotext.exe -raw -nopgbrk $source\$directory\transcripts\$_ | Tee-Object -file $log -Append
    Remove-Item $source\$directory\transcripts\$_ | Tee-Object -file $log -Append
  }

  #rename TXT to match jp2
  $jp2s = @(Get-ChildItem *.jp2 -Path $source\$directory\scans -Name | Sort-Object)
  $txts = @(Get-ChildItem *.txt -Path $source\$directory\transcripts -Name | Sort-Object)
  $i=0
  Get-ChildItem -Path $source\$directory\transcripts\*.txt -Name | Sort-Object | ForEach-Object {
    $name = $jp2s[$i]
    $name = $name.Substring(0,$name.Length-4)
    $txt = $txts[$i]
    Rename-Item $source\$directory\transcripts\$txt "$name.txt" | Tee-Object -file $log -Append
    $i++
  }
  Write-Output "    $(Get-Timestamp) PDF has been split, text extracted, files renamed to match JP2s, and TXT moved to transcripts directory." | Tee-Object -file $log -Append

  # Find the tif files and delete them.
  Get-ChildItem *.tif* -Path $source\$directory | ForEach-Object { Remove-Item -Path $_.FullName | Tee-Object -file $log -Append }
  Write-Output "    $(Get-Timestamp) TIF files have been deleted." | Tee-Object -file $log -Append

  # Move the complete PDF to the scans directory and delete the tmp directory.
  Move-Item $source\$directory\tmp\$directory.pdf -Destination $source\$directory\scans | Tee-Object -file $log -Append
  Remove-Item $source\$directory\tmp | Tee-Object -file $log -Append
}
Write-Output "$(Get-Timestamp) CLIR CONTENTdm Prep Complete." | Tee-Object -file $log -Append