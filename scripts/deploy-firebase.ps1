# Deploy Firestore rules, indexes, Storage, Functions, and Hosting (.well-known).
$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

Write-Host "Installing Cloud Functions dependencies..." -ForegroundColor Cyan
Set-Location functions
npm install --omit=dev
Set-Location ..

Write-Host "Deploying Firebase..." -ForegroundColor Cyan
firebase deploy --non-interactive --only "firestore:rules,firestore:indexes,storage,functions,hosting"

Write-Host "Done." -ForegroundColor Green
