# Deploy Firestore rules, indexes, Storage, Functions, and Hosting (.well-known).
#
# Usage:
#   .\scripts\deploy-firebase.ps1              # full deploy
#   .\scripts\deploy-firebase.ps1 -RulesOnly  # firestore rules only (fast)
#   .\scripts\deploy-firebase.ps1 -FunctionsOnly  # functions only (batched)
#
# If Functions fail with Cloud Run "Quota exceeded for total allowable CPU",
# use batched deploy instead:
#   .\scripts\deploy-functions-batched.ps1 -RetryFailed -BatchSize 2
#
# If Functions fail with "Timeout after 10000" during discovery, deploy rules
# separately first, then retry functions with a higher discovery timeout:
#   $env:FUNCTIONS_DISCOVERY_TIMEOUT = "60000"
#   firebase deploy --only functions
param(
  [switch]$RulesOnly,
  [switch]$FunctionsOnly
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

if ($RulesOnly) {
  Write-Host "Deploying Firestore rules only..." -ForegroundColor Cyan
  firebase deploy --non-interactive --only "firestore:rules"
  Write-Host "Done." -ForegroundColor Green
  exit 0
}

if ($FunctionsOnly) {
  & (Join-Path $PSScriptRoot "deploy-functions-batched.ps1")
  exit $LASTEXITCODE
}

Write-Host "Installing Cloud Functions dependencies..." -ForegroundColor Cyan
Set-Location functions
npm install --omit=dev
Set-Location ..

# Slow cold analysis of index.js can exceed the default 10s discovery window.
if (-not $env:FUNCTIONS_DISCOVERY_TIMEOUT) {
  $env:FUNCTIONS_DISCOVERY_TIMEOUT = "60000"
}

Write-Host "Deploying Firebase..." -ForegroundColor Cyan
firebase deploy --non-interactive --only "firestore:rules,firestore:indexes,storage,functions,hosting"

Write-Host "Done." -ForegroundColor Green
