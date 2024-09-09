param (
    [string]$directory
)

if (-not (Test-Path $directory)) {
    Write-Host "Error: Directory does not exist: $directory"
    exit 1
}

# Get all .mkv files in the directory and its subdirectories
$files = Get-ChildItem -Path $directory -Recurse -Include *.mkv, *.MKV

if ($files.Count -eq 0) {
    Write-Host "No MKV files found in the directory: $directory"
    exit 1
}

# Function to clean up file name (remove non-ASCII characters and everything after first '(')
function CleanFileName {
    param (
        [string]$fileName
    )
    # Remove non-ASCII characters and everything after the first '('
    $cleanName = $fileName -replace '[^\x00-\x7F]', '' -replace '\(.*', ''
    return $cleanName.Trim()
}

# Function to extract English track IDs for audio and subtitles using FFmpeg
function GetEnglishTracks {
    param (
        [string]$filePath
    )

    # Run FFmpeg to get the metadata of the file
    $ffmpegOutput = & "ffmpeg" -i $filePath 2>&1 | Out-String

    # Extract audio and subtitle streams with 'eng' language tag
    $audioTrack = ""
    $subtitleTrack = ""

    # Check for audio and subtitle streams with 'eng' language tag
    $audioMatches = [regex]::Matches($ffmpegOutput, "Stream #(\d+):(\d+)\(eng\): Audio")
    $subtitleMatches = [regex]::Matches($ffmpegOutput, "Stream #(\d+):(\d+)\(eng\): Subtitle")

    if ($audioMatches.Count -gt 0) {
        # Use the first match for the audio stream
        $audioStream = $audioMatches[0].Groups
        $audioTrack = "$($audioStream[1].Value):$($audioStream[2].Value)"
    }

    if ($subtitleMatches.Count -gt 0) {
        # Use the first match for the subtitle stream
        $subtitleStream = $subtitleMatches[0].Groups
        $subtitleTrack = "$($subtitleStream[1].Value):$($subtitleStream[2].Value)"
    }

    return @{ 'audio' = $audioTrack; 'subtitle' = $subtitleTrack }
}

# Loop through each file and process them
foreach ($file in $files) {
    $videoName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $cleanVideoName = CleanFileName $videoName
    $outputFile = [System.IO.Path]::Combine($file.DirectoryName, "$cleanVideoName.mov")

    # Check if the MOV already exists
    if (Test-Path $outputFile) {
        Write-Host "MOV already exists for video: $videoName"
        continue
    }

    # Get the English audio and subtitle tracks
    $tracks = GetEnglishTracks $file.FullName

    # Validate that we found English tracks
    if (-not $tracks['audio']) {
        Write-Host "No English audio track found for $videoName"
        continue
    }
    if (-not $tracks['subtitle']) {
        Write-Host "No English subtitle track found for $videoName"
        continue
    }

    $audioTrack = $tracks['audio']
    $subtitleTrack = $tracks['subtitle']

    # Convert the MKV to MOV using the identified English audio and subtitle tracks
    # Remap the selected tracks to Stream 0 during conversion
    & "ffmpeg" -i $file.FullName -map 0:v -map $audioTrack -map $subtitleTrack -c:v libx264 -profile:v high -level:v 4.0 -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 192k -ac 2 -c:s mov_text $outputFile
    Write-Host "Converted $file.FullName to MOV: $outputFile"
}

Write-Host "Conversion process completed."
