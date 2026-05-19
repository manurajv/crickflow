# Build Play Store AAB. Requires android/key.properties (see docs/ANDROID_RELEASE_SIGNING.md).
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$keyProps = Join-Path $root "android\key.properties"
if (-not (Test-Path $keyProps)) {
    Write-Host "Missing android/key.properties — release will use debug signing." -ForegroundColor Yellow
    Write-Host "See docs/ANDROID_RELEASE_SIGNING.md before Play Store upload." -ForegroundColor Yellow
} else {
    Write-Host "Release keystore configured." -ForegroundColor Green
}

Write-Host "Refreshing assetlinks (debug + release SHA)..." -ForegroundColor Cyan
& (Join-Path $PSScriptRoot "update-assetlinks-sha.ps1")

Write-Host "Building app bundle..." -ForegroundColor Cyan
flutter pub get
flutter build appbundle --release

$bundle = Join-Path $root "build\app\outputs\bundle\release\app-release.aab"
if (Test-Path $bundle) {
    Write-Host "`nAAB ready:" -ForegroundColor Green
    Write-Host "  $bundle"
    Write-Host "`nNext: upload to Play Console. See docs/STORE_LISTING.md" -ForegroundColor Cyan
    Write-Host "Then: firebase deploy --only hosting  (if assetlinks changed)" -ForegroundColor Cyan
} else {
    Write-Host "Build finished but AAB not found at expected path." -ForegroundColor Red
    exit 1
}
