# Prints debug + release SHA-1/SHA-256 for Firebase (Windows).
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Read-KeyProperties([string]$path) {
    $map = @{}
    Get-Content $path | Where-Object { $_ -match '=' -and -not $_.TrimStart().StartsWith('#') } | ForEach-Object {
        $p = $_ -split '=', 2
        $map[$p[0].Trim()] = $p[1].Trim()
    }
    return $map
}

function Resolve-KeystorePath([string]$storeFile) {
    if ([System.IO.Path]::IsPathRooted($storeFile)) {
        return $storeFile
    }
    # storeFile in key.properties is relative to android/app/
    $fromApp = Join-Path (Join-Path $root "android\app") $storeFile
    if (Test-Path $fromApp) { return $fromApp }
    # Fallback: relative to android/
    $fromAndroid = Join-Path (Join-Path $root "android") ($storeFile -replace '^\.\./', '')
    return $fromAndroid
}

$debugKeystore = "$env:USERPROFILE\.android\debug.keystore"
if (-not (Test-Path $debugKeystore)) {
    Write-Host "Debug keystore not found at $debugKeystore"
    Write-Host "Run: flutter run   (once) to generate it."
    exit 1
}

Write-Host "=== Debug keystore (local flutter run / debug builds) ===" -ForegroundColor Cyan
keytool -list -v -keystore $debugKeystore -alias androiddebugkey -storepass android -keypass android 2>&1 |
    Select-String -Pattern "SHA1:|SHA256:"

$keyProps = Join-Path $root "android\key.properties"
if (Test-Path $keyProps) {
    $props = Read-KeyProperties $keyProps
    $storeFile = $props['storeFile']
    $alias = $props['keyAlias']
    $storePass = $props['storePassword']
    $keyPass = $props['keyPassword']
    if (-not $keyPass) { $keyPass = $storePass }

    if ($storeFile -and $alias -and $storePass) {
        $path = Resolve-KeystorePath $storeFile
        Write-Host "`n=== Release keystore (Play Store / release builds) ===" -ForegroundColor Cyan
        if (Test-Path $path) {
            keytool -list -v -keystore $path -alias $alias -storepass $storePass -keypass $keyPass 2>&1 |
                Select-String -Pattern "SHA1:|SHA256:"
        } else {
            Write-Host "Keystore not found: $path" -ForegroundColor Yellow
        }
    } else {
        Write-Host "`nRelease: android/key.properties is incomplete (storeFile, keyAlias, storePassword)." -ForegroundColor Yellow
    }
} else {
    Write-Host "`nRelease: no android/key.properties - run .\scripts\create-release-keystore.ps1" -ForegroundColor Yellow
}

Write-Host "`nAdd BOTH debug and release SHA-1/SHA-256 to Firebase Console." -ForegroundColor Green
Write-Host 'Firebase: https://console.firebase.google.com/project/crickflow-b06bc/settings/general' -ForegroundColor Green
