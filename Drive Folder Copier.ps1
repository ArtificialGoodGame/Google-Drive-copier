$ErrorActionPreference = 'Stop'

$toolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$rclone = Join-Path $toolRoot 'bin\rclone.exe'
$config = Join-Path $toolRoot 'private\rclone.conf'
$setup = Join-Path $toolRoot 'Setup Google Account.ps1'
$logs = Join-Path $toolRoot 'logs'
$remote = 'my-drive'

function Pause-Tool {
    Write-Host ''
    Read-Host 'Press Enter to continue' | Out-Null
}

function Ensure-Connection {
    if (-not (Test-Path -LiteralPath $rclone)) {
        throw "Missing copier engine: $rclone"
    }
    if (-not (Test-Path -LiteralPath $config)) {
        Write-Host 'No Google account is connected yet. Starting setup...' -ForegroundColor Yellow
        & $setup
    }
    if (-not (Test-Path -LiteralPath $config)) {
        throw 'Google account setup is required before copying.'
    }
    New-Item -ItemType Directory -Path $logs -Force | Out-Null
}

function Normalize-DrivePath([string]$path) {
    $clean = $path.Trim().Trim('"').Trim('/')
    if ($clean.StartsWith($remote + ':')) {
        $clean = $clean.Substring(($remote + ':').Length).TrimStart('/')
    }
    return $clean
}

function Read-JobPaths {
    Write-Host ''
    Write-Host 'Enter paths as they appear inside My Drive.' -ForegroundColor Cyan
    Write-Host 'Source example:      School/Shared collection'
    Write-Host 'Destination example: School/Owned collection'
    $source = Normalize-DrivePath (Read-Host 'Source folder')
    $destination = Normalize-DrivePath (Read-Host 'Owned destination folder')
    if ([string]::IsNullOrWhiteSpace($source) -or [string]::IsNullOrWhiteSpace($destination)) {
        throw 'Both folder paths are required.'
    }
    if ($source -eq $destination -or
        $source.StartsWith($destination + '/', [System.StringComparison]::OrdinalIgnoreCase) -or
        $destination.StartsWith($source + '/', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Use separate source and destination folders. Neither may contain the other.'
    }
    return @($source, $destination)
}

function Invoke-VerifiedCopy([string]$source, [string]$destination) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $copyLog = Join-Path $logs "copy-$stamp.log"
    $checkLog = Join-Path $logs "verify-$stamp.log"
    $sourceRemote = "${remote}:$source"
    $destinationRemote = "${remote}:$destination"

    Write-Host ''
    Write-Host 'Starting cloud-side copy. Keep this window open.' -ForegroundColor Green
    Write-Host "Source:      $source"
    Write-Host "Destination: $destination"

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        Write-Host ''
        Write-Host "Copy pass $attempt of 3..." -ForegroundColor Cyan
        & $rclone copy $sourceRemote $destinationRemote `
            --config $config `
            --drive-copy-shortcut-content `
            --transfers 8 `
            --checkers 16 `
            --stats 30s `
            --stats-one-line `
            --progress `
            --log-level INFO `
            --log-file $copyLog

        Write-Host 'Verifying every source file...' -ForegroundColor Cyan
        & $rclone check $sourceRemote $destinationRemote `
            --config $config `
            --drive-copy-shortcut-content `
            --one-way `
            --size-only `
            --checkers 16 `
            --log-level INFO `
            --log-file $checkLog

        if ($LASTEXITCODE -eq 0) {
            Write-Host ''
            Write-Host 'SUCCESS: Every source file has a destination file of the same size.' -ForegroundColor Green
            Write-Host "Logs: $logs"
            return
        }

        if ($attempt -lt 3) {
            Write-Host 'Verification found gaps. Repairing them automatically...' -ForegroundColor Yellow
        }
    }

    Write-Host ''
    Write-Host 'The copy could not be fully verified after three passes.' -ForegroundColor Red
    Write-Host "Review the logs in: $logs"
}

function Invoke-Verification([string]$source, [string]$destination) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $checkLog = Join-Path $logs "verify-only-$stamp.log"
    & $rclone check "${remote}:$source" "${remote}:$destination" `
        --config $config `
        --drive-copy-shortcut-content `
        --one-way `
        --size-only `
        --checkers 16 `
        --log-level INFO `
        --log-file $checkLog
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'SUCCESS: Every source file has a destination file of the same size.' -ForegroundColor Green
    } else {
        Write-Host "Differences were found. See: $checkLog" -ForegroundColor Yellow
    }
}

Ensure-Connection

while ($true) {
    Write-Host ''
    Write-Host 'Google Drive Folder Copier' -ForegroundColor Cyan
    Write-Host '==========================='
    Write-Host '1. Copy a folder and verify it'
    Write-Host '2. Verify an existing copy'
    Write-Host '3. Reconnect or change Google account'
    Write-Host '4. Exit'
    Write-Host ''
    $choice = Read-Host 'Choose 1-4'

    try {
        switch ($choice) {
            '1' {
                $paths = Read-JobPaths
                Invoke-VerifiedCopy $paths[0] $paths[1]
                Pause-Tool
            }
            '2' {
                $paths = Read-JobPaths
                Invoke-Verification $paths[0] $paths[1]
                Pause-Tool
            }
            '3' {
                & $setup
            }
            '4' { return }
            default {
                Write-Host 'Please choose 1, 2, 3, or 4.' -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
        }
    } catch {
        Write-Host ''
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        Pause-Tool
    }
}
