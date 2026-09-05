$ErrorActionPreference = 'Stop'

$toolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$rclone = Join-Path $toolRoot 'bin\rclone.exe'
$privateFolder = Join-Path $toolRoot 'private'
$config = Join-Path $privateFolder 'rclone.conf'
$remote = 'my-drive'

function Select-OAuthJson {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = 'Select your Google OAuth client JSON file'
        $dialog.Filter = 'Google OAuth JSON (*.json)|*.json|All files (*.*)|*.*'
        $dialog.Multiselect = $false
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return $dialog.FileName
        }
    } catch {
        # Fall back to a typed path if the file picker is unavailable.
    }
    return (Read-Host 'Paste the full path to your OAuth client JSON file').Trim().Trim('"')
}

if (-not (Test-Path -LiteralPath $rclone)) {
    throw "Missing copier engine: $rclone"
}

Write-Host ''
Write-Host 'Google Drive Copier - Account Setup' -ForegroundColor Cyan
Write-Host 'Each person must use their own Desktop OAuth client JSON.'
Write-Host 'Nothing from another user is included in this package.' -ForegroundColor Green
Write-Host ''

$jsonPath = Select-OAuthJson
if ([string]::IsNullOrWhiteSpace($jsonPath) -or -not (Test-Path -LiteralPath $jsonPath)) {
    throw 'The selected JSON file does not exist.'
}

$oauth = Get-Content -Raw -LiteralPath $jsonPath | ConvertFrom-Json
if (-not $oauth.installed) {
    throw 'This is not a Desktop OAuth client JSON. In Google Cloud, create an OAuth client with application type Desktop app.'
}

$clientId = [string]$oauth.installed.client_id
$clientSecret = [string]$oauth.installed.client_secret
if ([string]::IsNullOrWhiteSpace($clientId) -or [string]::IsNullOrWhiteSpace($clientSecret)) {
    throw 'The JSON does not contain a client ID and client secret.'
}

New-Item -ItemType Directory -Path $privateFolder -Force | Out-Null
if (Test-Path -LiteralPath $config) {
    $backup = Join-Path $privateFolder ('rclone-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.conf')
    Copy-Item -LiteralPath $config -Destination $backup
}

Write-Host 'Opening Google authorization. Sign in with the Drive account that will own the copies.' -ForegroundColor Cyan
& $rclone config create $remote drive `
    client_id $clientId `
    client_secret $clientSecret `
    scope drive `
    config_is_local true `
    --config $config | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw 'Google authorization did not complete.'
}

Write-Host 'Testing the connection...' -ForegroundColor Cyan
& $rclone lsd "${remote}:" --config $config --max-depth 1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'Authorization was saved, but the Drive connection test failed.'
}

$clientId = $null
$clientSecret = $null
$oauth = $null
Write-Host ''
Write-Host 'SUCCESS: This computer is connected to your Google Drive.' -ForegroundColor Green
Write-Host 'You can now open Google Drive Copier.cmd.'
Write-Host ''
Read-Host 'Press Enter to close' | Out-Null
