param (
    [string]$directory,
    [int]$audioTrack,  # Mandatory audio track number
    [int]$subtitleTrack  # Mandatory subtitle track number
)

# Check if required parameters are set
if (-not $directory) {
    Write-Host "Error: Directory parameter is required."
    exit 1
}

if (-not (Test-Path $directory)) {
    Write-Host "Error: Directory does not exist: $directory"
    exit 1
}

if (-not $audioTrack) {
    Write-Host "Error: Audio track parameter is required."
    exit 1
}

if (-not $subtitleTrack) {
    Write-Host "Error: Subtitle track parameter is required."
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

# Function to clean up file name (remove non-ASCII characters and everything after first '(')
function CleanFileName {
    param (
        [string]$fileName
    )
    # Remove non-ASCII characters and everything after the first '('
    $cleanName = $fileName -replace '[^\x00-\x7F]', '' -replace '\(.*', ''
    return $cleanName.Trim()
}

# Loop through each file and process them
foreach ($file in $files) {
    $videoName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $cleanVideoName = CleanFileName $videoName
    $outputFile = [System.IO.Path]::Combine($file.DirectoryName, "$cleanVideoName.mov")
    
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

    # Convert the MKV to MOV using FFmpeg with specific audio and subtitle tracks passed as arguments
    & "ffmpeg" -i $file.FullName -map 0:v -map 0:a:$audioTrack -map 0:s:$subtitleTrack -c:v libx264 -profile:v high -level:v 4.0 -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 192k -ac 2 -c:s mov_text $outputFile
    Write-Host "Converted $file.FullName to MOV: $outputFile"
}

Write-Host "Conversion process completed."
