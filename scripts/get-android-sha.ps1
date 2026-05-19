# Prints debug SHA-1/SHA-256 for Firebase Google Sign-In (Windows).
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$debugKeystore = "$env:USERPROFILE\.android\debug.keystore"
if (-not (Test-Path $debugKeystore)) {
    Write-Host "Debug keystore not found at $debugKeystore"
    Write-Host "Run: flutter run   (once) to generate it."
    exit 1
}
Write-Host "=== Debug keystore (add to Firebase Console) ===" -ForegroundColor Cyan
keytool -list -v -keystore $debugKeystore -alias androiddebugkey -storepass android -keypass android 2>&1 | Select-String -Pattern "SHA1:|SHA256:"

$keyProps = Join-Path $root "android\key.properties"
if (Test-Path $keyProps) {
    Write-Host "`n=== Release keystore ===" -ForegroundColor Cyan
    $props = Get-Content $keyProps | Where-Object { $_ -match '=' } | ForEach-Object {
        $p = $_ -split '=', 2; @{ $p[0].Trim() = $p[1].Trim() }
    }
    $storeFile = ($props | ForEach-Object { $_.storeFile }) | Select-Object -First 1
    $alias = ($props | ForEach-Object { $_.keyAlias }) | Select-Object -First 1
    if ($storeFile) {
        $path = Join-Path (Join-Path $root "android") $storeFile.Replace('../','')
        if (Test-Path $path) {
            keytool -list -v -keystore $path -alias $alias 2>&1 | Select-String -Pattern "SHA1:|SHA256:"
        }
    }
}

Write-Host "`nFirebase: https://console.firebase.google.com/project/crickflow-b06bc/settings/general" -ForegroundColor Green
