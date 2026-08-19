# Apply Storage CORS so browser photo uploads work from crickflow.web.app.
# Requires Google Cloud SDK authenticated to project crickflow-b06bc.

param(
  [string]$Bucket = "gs://crickflow-b06bc.firebasestorage.app"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

$sdkBin = Join-Path $env:LOCALAPPDATA "Google\Cloud SDK\google-cloud-sdk\bin"
$gsutil = Get-Command gsutil -ErrorAction SilentlyContinue
if (-not $gsutil) {
  $gsutilCmd = Join-Path $sdkBin "gsutil.cmd"
  if (Test-Path $gsutilCmd) { $gsutil = $gsutilCmd }
}
if (-not $gsutil) {
  Write-Error "gsutil not found. Open a new PowerShell after installing Cloud SDK, or run:`n& `"$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\bin\gsutil.cmd`" cors set config\storage-cors.json $Bucket"
}

$gcloud = Get-Command gcloud -ErrorAction SilentlyContinue
if (-not $gcloud) {
  $gcloudCmd = Join-Path $sdkBin "gcloud.cmd"
  if (Test-Path $gcloudCmd) { $gcloud = $gcloudCmd }
}
if ($gcloud) {
  & $gcloud config set project crickflow-b06bc
}

& $gsutil cors set config\storage-cors.json $Bucket
& $gsutil cors get $Bucket
Write-Host "Storage CORS updated. Retry a Community / Settings photo upload on https://crickflow.web.app"
