# Merges SHA-256 fingerprints from get-android-sha.ps1 into public/.well-known/assetlinks.json
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$assetLinks = Join-Path $root "public\.well-known\assetlinks.json"

function Get-Sha256FromKeytool([string]$keystore, [string]$alias, [string]$storePass, [string]$keyPass) {
    $out = keytool -list -v -keystore $keystore -alias $alias -storepass $storePass -keypass $keyPass 2>&1
    $line = $out | Select-String -Pattern "SHA256:\s*(.+)" | Select-Object -First 1
    if (-not $line) { return $null }
    return ($line.Matches[0].Groups[1].Value.Trim().ToUpper())
}

$fingerprints = @()
$debugKeystore = "$env:USERPROFILE\.android\debug.keystore"
if (Test-Path $debugKeystore) {
    $sha = Get-Sha256FromKeytool $debugKeystore "androiddebugkey" "android" "android"
    if ($sha) { $fingerprints += $sha }
}

$keyProps = Join-Path $root "android\key.properties"
if (Test-Path $keyProps) {
    $map = @{}
    Get-Content $keyProps | Where-Object { $_ -match '=' } | ForEach-Object {
        $p = $_ -split '=', 2
        $map[$p[0].Trim()] = $p[1].Trim()
    }
    if ($map.storeFile) {
        $storePath = Join-Path (Join-Path $root "android") ($map.storeFile -replace '^\.\./', '')
        if (Test-Path $storePath) {
            $sha = Get-Sha256FromKeytool $storePath $map.keyAlias $map.storePassword $map.keyPassword
            if ($sha -and $fingerprints -notcontains $sha) { $fingerprints += $sha }
        }
    }
}

if ($fingerprints.Count -eq 0) {
    Write-Host "No SHA-256 found. Run flutter run once or configure android/key.properties." -ForegroundColor Yellow
    exit 1
}

$doc = @{
    relation = @("delegate_permission/common.handle_all_urls")
    target = @{
        namespace = "android_app"
        package_name = "com.mavixas.crickflow"
        sha256_cert_fingerprints = $fingerprints
    }
} | ConvertTo-Json -Depth 5

# assetlinks is a JSON array
"[$doc]" | Set-Content -Path $assetLinks -Encoding UTF8
Write-Host "Updated $assetLinks with $($fingerprints.Count) fingerprint(s):" -ForegroundColor Green
$fingerprints | ForEach-Object { Write-Host "  $_" }
Write-Host "Deploy: firebase deploy --only hosting" -ForegroundColor Cyan
