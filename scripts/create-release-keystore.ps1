# Creates release keystore OUTSIDE the repo (safer backups / less risk of commit).
# Default: %USERPROFILE%\Documents\keys\crickflow\crickflow-release.keystore
# Override: $env:CRICKFLOW_KEYSTORE_PATH = "D:\secure\crickflow-release.keystore"
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$keyProps = Join-Path $root "android\key.properties"
$example = Join-Path $root "android\key.properties.example"

if ($env:CRICKFLOW_KEYSTORE_PATH -and $env:CRICKFLOW_KEYSTORE_PATH.Trim().Length -gt 0) {
    $keystore = $env:CRICKFLOW_KEYSTORE_PATH.Trim()
} else {
    $keystore = Join-Path $env:USERPROFILE "Documents\keys\crickflow\crickflow-release.keystore"
}

$keystoreDir = Split-Path -Parent $keystore
if (-not (Test-Path $keystoreDir)) {
    New-Item -ItemType Directory -Force -Path $keystoreDir | Out-Null
}

if (Test-Path $keystore) {
    Write-Host "Keystore already exists: $keystore" -ForegroundColor Yellow
    Write-Host "Set storeFile in android/key.properties to that path, then run get-android-sha.ps1" -ForegroundColor Cyan
    exit 0
}

# Avoid leaving a stale in-repo copy that confuses builds.
$legacyInRepo = Join-Path $root "android\crickflow-release.keystore"
if (Test-Path $legacyInRepo) {
    Write-Host "Found legacy in-repo keystore. Moving it to:" -ForegroundColor Yellow
    Write-Host "  $keystore"
    Move-Item -Path $legacyInRepo -Destination $keystore -Force
    Write-Host "Moved. Update android/key.properties storeFile if needed." -ForegroundColor Green
    exit 0
}

Write-Host "Creating release keystore at:" -ForegroundColor Cyan
Write-Host "  $keystore"
Write-Host ""
Write-Host "You will be prompted for passwords and certificate details." -ForegroundColor Yellow
Write-Host "Remember these passwords - they go into android/key.properties." -ForegroundColor Yellow

keytool -genkey -v `
    -keystore $keystore `
    -alias crickflow `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000

if (-not (Test-Path $keystore)) {
    Write-Host "Keystore was not created." -ForegroundColor Red
    exit 1
}

# Write / refresh key.properties with absolute storeFile (passwords still need editing if new file).
$storeFileProp = ($keystore -replace '\\', '/')
if (-not (Test-Path $keyProps)) {
    @"
# Do NOT commit this file.
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=crickflow
storeFile=$storeFileProp
"@ | Set-Content -Path $keyProps -Encoding UTF8
    Write-Host "`nCreated android/key.properties - set storePassword and keyPassword to the values you just entered." -ForegroundColor Green
} else {
    Write-Host "`nKeystore ready. Ensure android/key.properties has:" -ForegroundColor Green
    Write-Host "  storeFile=$storeFileProp"
}

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "  1. Edit android/key.properties passwords (do NOT commit)"
Write-Host "  2. .\scripts\get-android-sha.ps1  - add SHA to Firebase Console"
Write-Host "  3. .\scripts\update-assetlinks-sha.ps1 ; firebase deploy --only hosting"
Write-Host "  4. .\scripts\build-release.ps1"
