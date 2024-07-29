param (
    [string]$directory
)

# Check if the directory variable is empty
if ([string]::IsNullOrWhiteSpace($directory)) {
    Write-Host "No directory specified. Please provide a valid directory."
    exit 1
}

# Check if the directory exists
if (-not (Test-Path $directory)) {
    Write-Host "Directory does not exist: $directory"
    exit 1
}

# Get all .mobi, .MOBI, .epub, and .EPUB files in the directory and its subdirectories
$files = Get-ChildItem -Path $directory -Recurse -Include *.mobi, *.MOBI, *.epub, *.EPUB

if ($files.Count -eq 0) {
    Write-Host "No eBook files found in the directory: $directory"
    exit 1
}

# Loop through each file and run the ebook-convert command
foreach ($file in $files) {
    $inputFile = $file.FullName
    $outputFile = [System.IO.Path]::ChangeExtension($inputFile, ".pdf")

    # Run the ebook-convert command
    & "ebook-convert.exe" $inputFile $outputFile --embed-all-fonts
}
