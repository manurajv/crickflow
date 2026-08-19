# Deploy CrickFlow Web only — never the repo-root Hosting site.
# Requires Firebase CLI login. Site id: crickflow (crickflow.web.app).

param(
  [string]$ProjectId = "crickflow-b06bc",
  [string]$Site = "crickflow"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

if (-not (Test-Path .env.local) -and (Test-Path .env.example)) {
  Copy-Item .env.example .env.local
}

npm run build
npx firebase-tools deploy --only hosting:$Site --project $ProjectId --config firebase.json --non-interactive

Write-Host "Deployed consumer web to https://$Site.web.app"
Write-Host "Did not deploy root firebase.json (mobile App Links / /live)."
