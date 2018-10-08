# batchReOCR.ps1 
# Nathan Tallman, October 2018
# https://git.psu.edu/digipres/scripts/tree/master/conversions/CONTENTdm

# Import CSV with text filenames for each record.
$works = Import-Csv metadata_preOCR.csv

# Create the field to store the OCR text.
$works | Add-Member -MemberType NoteProperty -Name 'value' -Value $null

# Extract the text from the file and store it in the value field for each record.
ForEach ($work in $works) {
  $text = (Get-Content -Path $work.file) -join " "
  $text | Out-String | Out-Null
  $work.value = $text
}

# Export pipe-delimted CSV with OCR Text, including file field for debugging.
$works  | select file,cdmnumber,field,value,collection,action | Export-Csv -Delimiter "|" metadata_pitcher_pipe.txt -NoType