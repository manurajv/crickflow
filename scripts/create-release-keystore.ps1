# Creates android/crickflow-release.keystore (gitignored). Run once before Play Store upload.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$keystore = Join-Path $root "android\crickflow-release.keystore"
$keyProps = Join-Path $root "android\key.properties"
$example = Join-Path $root "android\key.properties.example"

if (Test-Path $keystore) {
    Write-Host "Keystore already exists: $keystore" -ForegroundColor Yellow
    exit 0
}

Write-Host "Creating release keystore at:" -ForegroundColor Cyan
Write-Host "  $keystore"
Write-Host ""
Write-Host "You will be prompted for passwords and certificate details." -ForegroundColor Yellow

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

if (-not (Test-Path $keyProps)) {
    Copy-Item $example $keyProps
    Write-Host "`nCreated android/key.properties from example — edit passwords and storeFile." -ForegroundColor Green
}

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "  1. Edit android/key.properties (do NOT commit)"
Write-Host "  2. .\scripts\get-android-sha.ps1  → add SHA to Firebase Console"
Write-Host "  3. .\scripts\update-assetlinks-sha.ps1 && firebase deploy --only hosting"
Write-Host "  4. .\scripts\build-release.ps1"
