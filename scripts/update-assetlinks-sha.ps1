# Merges SHA-256 fingerprints from debug + release keystores into
# public/.well-known/assetlinks.json
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$assetLinks = Join-Path $root "public\.well-known\assetlinks.json"

function Get-Sha256FromKeytool([string]$keystore, [string]$alias, [string]$storePass, [string]$keyPass) {
    # Native stderr must not become terminating errors under ErrorAction Stop.
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $out = & keytool -list -v -keystore $keystore -alias $alias -storepass $storePass -keypass $keyPass 2>&1 |
            ForEach-Object { "$_" }
    } finally {
        $ErrorActionPreference = $prev
    }
    $line = $out | Select-String -Pattern "SHA256:\s*(.+)" | Select-Object -First 1
    if (-not $line) { return $null }
    return ($line.Matches[0].Groups[1].Value.Trim().ToUpper())
}

function Resolve-KeystorePath([string]$storeFile) {
    $storeFile = $storeFile.Trim().Trim('"').Trim("'")
    if ([System.IO.Path]::IsPathRooted($storeFile)) {
        return $storeFile
    }
    # Relative paths in key.properties are resolved from android/app/
    $fromApp = Join-Path (Join-Path $root "android\app") $storeFile
    if (Test-Path $fromApp) { return $fromApp }
    $fromAndroid = Join-Path (Join-Path $root "android") ($storeFile -replace '^\.\./', '')
    return $fromAndroid
}

function Read-KeyProperties([string]$path) {
    $map = @{}
    # Strip UTF-8 BOM so the first key is not "\uFEFFstorePassword"
    $raw = [System.IO.File]::ReadAllText($path)
    if ($raw.Length -gt 0 -and [int][char]$raw[0] -eq 0xFEFF) {
        $raw = $raw.Substring(1)
    }
    foreach ($line in ($raw -split "`r?`n")) {
        $t = $line.Trim()
        if ($t.Length -eq 0 -or $t.StartsWith('#')) { continue }
        if ($t -notmatch '=') { continue }
        $p = $t -split '=', 2
        $map[$p[0].Trim()] = $p[1].Trim()
    }
    return $map
}

$fingerprints = [System.Collections.Generic.List[string]]::new()

$debugKeystore = "$env:USERPROFILE\.android\debug.keystore"
if (Test-Path $debugKeystore) {
    $sha = Get-Sha256FromKeytool $debugKeystore "androiddebugkey" "android" "android"
    if ($sha -and -not $fingerprints.Contains($sha)) { $fingerprints.Add($sha) }
} else {
    Write-Host "Debug keystore missing (optional for Play): $debugKeystore" -ForegroundColor Yellow
}

$keyProps = Join-Path $root "android\key.properties"
if (Test-Path $keyProps) {
    $map = Read-KeyProperties $keyProps
    $storeFile = $map['storeFile']
    $alias = $map['keyAlias']
    $storePass = $map['storePassword']
    $keyPass = $map['keyPassword']
    if (-not $keyPass) { $keyPass = $storePass }

    if ($storeFile -and $alias -and $storePass) {
        $storePath = Resolve-KeystorePath $storeFile
        if (Test-Path $storePath) {
            $sha = Get-Sha256FromKeytool $storePath $alias $storePass $keyPass
            if ($sha) {
                if (-not $fingerprints.Contains($sha)) { $fingerprints.Add($sha) }
                Write-Host "Release SHA-256 loaded from: $storePath" -ForegroundColor DarkGray
            } else {
                Write-Host "Could not read SHA-256 from release keystore (check passwords in key.properties)." -ForegroundColor Yellow
            }
        } else {
            Write-Host "Release keystore not found at: $storePath" -ForegroundColor Yellow
        }
    } else {
        Write-Host "android/key.properties incomplete (need storeFile, keyAlias, storePassword)." -ForegroundColor Yellow
    }
} else {
    Write-Host "No android/key.properties - release fingerprint skipped." -ForegroundColor Yellow
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
        sha256_cert_fingerprints = @($fingerprints)
    }
} | ConvertTo-Json -Depth 5

# assetlinks is a JSON array
"[$doc]" | Set-Content -Path $assetLinks -Encoding utf8
Write-Host "Updated $assetLinks with $($fingerprints.Count) fingerprint(s):" -ForegroundColor Green
$fingerprints | ForEach-Object { Write-Host "  $_" }
if ($fingerprints.Count -lt 2) {
    Write-Host "Expected 2 (debug + release). Fix key.properties / keystore path, then re-run." -ForegroundColor Yellow
}
Write-Host "Deploy: firebase deploy --only hosting" -ForegroundColor Cyan
