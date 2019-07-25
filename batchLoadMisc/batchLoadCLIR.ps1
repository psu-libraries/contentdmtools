# batchLoadCLIR.ps1 
# Nathan Tallman, Created in August 2018
# Modified in April 2019 for CLIR grant; updated 25 July 2019.
# https://git.psu.edu/digipres/contentdm/blob/master/batchLoadMisc/
# this is fragile, only works for this collection as of this date, will break if the number of fields change. This could probably be refactored to read number of fields and generate stuff as needed?

## Dependencies
# pdftk needs to be installed locally to split pdfs
# XPDF CLI (pdf2text.exe specficially) is needed for text extraction https://xpdfreader-dl.s3.amazonaws.com/xpdf-tools-win-4.01.01.zip, extract and move/copy bin64\pdf2text.exe to the same directory as this script.

# Setup timestamps and global variables
function Get-TimeStamp { return "[{0:yyyy-MM-dd} {0:HH:mm:ss}]" -f (Get-Date) }
$batch = $PSScriptRoot | Split-Path -Leaf
$log = ($batch + "_batchLoadCLIR_log.txt")
Write-Output "$(Get-Timestamp) CLIR CONTENTdm Prep Starting." | Tee-Object -file $log
Write-Output "----------------------------------------------" | Tee-Object -file $log -Append

# Read in the metadata and setup array for each object
$metadata = Import-Csv -Path metadata.csv
$objects = $metadata | Group-Object -AsHashTable -AsString -Property Directory

# Establish loop for each object directory
$o=0 
ForEach ($object in $objects.keys)
{
  # Create object metadata txt in each object directory
  Write-Output "$(Get-Timestamp) $object processing starting." | Tee-Object -file $log -Append
  $objects.$object | Select-Object Title,"Alternative Title",Creator,Recipient,"Date Created",Genre,"Physical Description",Subject,Location,"Time Period",Notes,Language,Identifier,"Box and Folder",Collection,Series,Repository,"Finding Aid","Rights Statement","Resource Type",Cataloger,"Date Cataloged","File Name" -ExcludeProperty Level,Directory | Export-Csv -Delimiter "`t" -Path $object\$object.txt -NoTypeInformation | Tee-Object -file $log -Append
  Write-Output "    Object metadata has been broken up into the the Directory Structure." | Tee-Object -file $log -Append

  # split object PDFs and move complete PDF to tmp directory
  pdftk $object\$object.pdf burst output $object\$object-%02d.pdf | Tee-Object -file $log -Append
  Remove-Item $object\doc_data.txt | Tee-Object -file $log -Append
  if(!(Test-Path $object\tmp)) { New-Item -ItemType Directory -Path $object\tmp | Out-Null }
  Move-Item $object\$object.pdf -Destination $object\tmp | Tee-Object -file $log -Append
  Write-Output "    PDF split into pages." | Tee-Object -file $log -Append
     
  # Add item metadata to metadata txt, including file names and seqential titles (Item 1 of X, Item 2 of X, etc.)
  # Refactor to dynamically read headers and generate row 
  $i=1
  $count = (Get-ChildItem *.jp2 -File -Force -Path $object).Count
  Get-ChildItem *.jp2 -Path $object | ForEach-Object {
    $row = "{0}`t{1}`t{2}`t{3}`t{4}`t{5}`t{6}`t{7}`t{8}`t{9}`t{10}`t{11}`t{12}`t{13}`t{14}`t{15}`t{16}`t{17}`t{18}`t{19}`t{20}`t{21}`t{22}" -f """Item $i of $count""", """""", """""", """""", """""", """""", """""", """""", """""", """""", """""", """""", """""" ,"""""", """""", """""", """""", """""", """""", """""", """""", """""", $_
    [array]$item = $row
    $item | Out-File $object\$object.txt -Append -Encoding UTF8
    $i++
  }
  Write-Output "    Item metadata has been added." | Tee-Object -file $log -Append

  # Move JP2 to scans directory
  if(!(Test-Path $object\scans)) { New-Item -ItemType Directory -Path $object\scans | Out-Null }
  Get-ChildItem *.jp2 -Path $object | ForEach-Object { Move-Item $object\$_ -Destination $object\scans | Tee-Object -file $log -Append } 
  Write-Output "    JP2 files have been moved to the scans directory." | Tee-Object -file $log -Append

  # Move PDFs to transcripts directory because we won't be able to distinguish metadata from text otherwise
  if(!(Test-Path $object\transcripts)) { New-Item -ItemType Directory -Path $object\transcripts | Out-Null }
  Get-ChildItem *.pdf -Path $object | ForEach-Object { Move-Item $object\$_ -Destination $object\transcripts | Tee-Object -file $log -Append }

  #Extract text and delete item PDF
  Get-ChildItem *.pdf -Path $object\transcripts | ForEach-Object {
    .\pdftotext.exe -raw -nopgbrk $object\transcripts\$_ | Tee-Object -file $log -Append
    Remove-Item $object\transcripts\$_ | Tee-Object -file $log -Append
  }

  #rename TXT to match jp2
  $jp2s = @(Get-ChildItem *.jp2 -Path $object\scans -Name | Sort-Object)
  $txts = @(Get-ChildItem *.txt -Path $object\transcripts -Name | Sort-Object)
  $i=0
  Get-ChildItem -Path $object\transcripts\*.txt -Name | Sort-Object | ForEach-Object {
    $name = $jp2s[$i]
    $name = $name.Substring(0,$name.Length-4)
    $txt = $txts[$i]
    Rename-Item $object\transcripts\$txt "$name.txt" | Tee-Object -file $log -Append
    $i++
  }
  Write-Output "    PDF has been split, text extracted, files renamed to match JP2s, and TXT moved to transcripts directory." | Tee-Object -file $log -Append

  # Find the tif files and delete them.
  Get-ChildItem *.tif* -Path $object | ForEach-Object { Remove-Item -Path $_.FullName | Tee-Object -file $log -Append }
  Write-Output "    TIF files have been deleted." | Tee-Object -file $log -Append

  # Delete the tmp directory and complete PDF.
  Remove-Item -Recurse $object\tmp | Tee-Object -file $log -Append

  Write-Output "$(Get-Timestamp) $object processing complete." | Tee-Object -file $log -Append
  $o++
}
Write-Output "----------------------------------------------" | Tee-Object -file $log -Append
$objectCount = (Get-ChildItem pst* -Directory -Path $PSScriptRoot).Count
Write-Output "$(Get-Timestamp) CLIR CONTENTdm Prep Complete." | Tee-Object -file $log -Append
Write-Output "Number of objects processed:  $o" | Tee-Object -file $log -Append
Write-Output "Number of object directories: $objectCount" | Tee-Object -file $log -Append