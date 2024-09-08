param (
    [string]$directory
)

if (-not (Test-Path $directory)) {
    Write-Host "Directory does not exist: $directory"
    exit 1
}

# Get all .epub, .mobi, .azw3, and .html files in the directory and its subdirectories
$files = Get-ChildItem -Path $directory -Recurse -Include *.epub, *.EPUB, *.mobi, *.MOBI, *.azw3, *.AZW3, *.html, *.HTML, *.rtf, *.RTF

if ($files.Count -eq 0) {
    Write-Host "No eBook files found in the directory: $directory"
    exit 1
}

# Dictionary to keep track of books that have already been checked
$checkedBooks = @{}

# Loop through each file and process them
foreach ($file in $files) {
    $bookName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $outputFile = [System.IO.Path]::Combine($file.DirectoryName, "$bookName.pdf")
    
    # Check if we've already processed this book
    if ($checkedBooks.ContainsKey($bookName)) {
        Write-Host "Skipping already checked book: $bookName"
        continue
    }
    
    # Check if the PDF already exists
    if (Test-Path $outputFile) {
        Write-Host "PDF already exists for book: $bookName"
        $checkedBooks[$bookName] = $true
        continue
    }
    
    # Mark this book as checked to avoid redundant checks
    $checkedBooks[$bookName] = $true

    # Convert the book to PDF
    & "ebook-convert.exe" $file.FullName $outputFile --embed-all-fonts
    Write-Host "Converted $file.FullName to PDF."
}

Write-Host "Conversion process completed."
