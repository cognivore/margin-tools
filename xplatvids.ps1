param (
    [string]$directory
)

if (-not (Test-Path $directory)) {
    Write-Host "Directory does not exist: $directory"
    exit 1
}

# Get all .mkv files in the directory and its subdirectories
$files = Get-ChildItem -Path $directory -Recurse -Include *.mkv, *.MKV

if ($files.Count -eq 0) {
    Write-Host "No MKV files found in the directory: $directory"
    exit 1
}

# Dictionary to keep track of videos that have already been checked
$checkedVideos = @{}

# Loop through each file and process them
foreach ($file in $files) {
    $videoName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $outputFile = [System.IO.Path]::Combine($file.DirectoryName, "$videoName.mov")
    
    # Check if we've already processed this video
    if ($checkedVideos.ContainsKey($videoName)) {
        Write-Host "Skipping already checked video: $videoName"
        continue
    }
    
    # Check if the MOV already exists
    if (Test-Path $outputFile) {
        Write-Host "MOV already exists for video: $videoName"
        $checkedVideos[$videoName] = $true
        continue
    }
    
    # Mark this video as checked to avoid redundant checks
    $checkedVideos[$videoName] = $true

    # Convert the MKV to MOV using FFmpeg
    & "ffmpeg" -i $file.FullName -c:v libx264 -profile:v high -level:v 4.0 -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 192k -ac 2 $outputFile
    Write-Host "Converted $file.FullName to MOV."
}

Write-Host "Conversion process completed."
