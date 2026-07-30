# CrickFlow Admin — local quality gate (mirrors CI)
# Usage: .\scripts\ci\admin-quality.ps1

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

function Invoke-Step([string]$cwd, [scriptblock]$scriptBlock) {
  Push-Location $cwd
  try { & $scriptBlock }
  finally { Pop-Location }
}

Write-Host "== admin_core ==" -ForegroundColor Cyan
Invoke-Step (Join-Path $root "apps\admin_core") {
  flutter pub get
  dart format --output=none --set-exit-if-changed .
  flutter analyze --fatal-infos
  flutter test
}

Write-Host "== admin ==" -ForegroundColor Cyan
Invoke-Step (Join-Path $root "apps\admin") {
  flutter pub get
  dart format --output=none --set-exit-if-changed .
  flutter analyze --fatal-infos
}

Write-Host "== superadmin ==" -ForegroundColor Cyan
Invoke-Step (Join-Path $root "apps\superadmin") {
  flutter pub get
  dart format --output=none --set-exit-if-changed .
  flutter analyze --fatal-infos
}

Write-Host "All Admin quality gates passed." -ForegroundColor Green
