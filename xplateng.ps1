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
    
    $ffmpegOutput = & "ffmpeg" -i $filePath 2>&1 | Out-String

    # Extract audio tracks
    $audioTracks = @()
    if ($ffmpegOutput -match "(Stream #0:(\d+)\(\w+\): Audio:.*\benglish\b)") {
        $matches = [regex]::Matches($ffmpegOutput, "(Stream #0:(\d+)\(\w+\): Audio:.*\benglish\b)")
        foreach ($match in $matches) {
            $audioTracks += $match.Groups[2].Value
        }
    }

    # Extract subtitle tracks
    $subtitleTracks = @()
    if ($ffmpegOutput -match "(Stream #0:(\d+)\(\w+\): Subtitle:.*\benglish\b)") {
        $matches = [regex]::Matches($ffmpegOutput, "(Stream #0:(\d+)\(\w+\): Subtitle:.*\benglish\b)")
        foreach ($match in $matches) {
            $subtitleTracks += $match.Groups[2].Value
        }
    }

    return @{ 'audio' = $audioTracks; 'subtitle' = $subtitleTracks }
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
    if ($tracks['audio'].Count -eq 0) {
        Write-Host "No English audio track found for $videoName"
        continue
    }
    if ($tracks['subtitle'].Count -eq 0) {
        Write-Host "No English subtitle track found for $videoName"
        continue
    }

    $audioTrack = $tracks['audio'][0]
    $subtitleTrack = $tracks['subtitle'][0]

    # Convert the MKV to MOV using the identified English audio and subtitle tracks
    & "ffmpeg" -i $file.FullName -map 0:v -map 0:a:$audioTrack -map 0:s:$subtitleTrack -c:v libx264 -profile:v high -level:v 4.0 -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 192k -ac 2 -c:s mov_text $outputFile
    Write-Host "Converted $file.FullName to MOV: $outputFile"
}

Write-Host "Conversion process completed."
