# Deploy Cloud Functions in small batches to avoid Cloud Run CPU quota errors
# ("Quota exceeded for total allowable CPU per project per region").
#
# Usage:
#   .\scripts\deploy-functions-batched.ps1              # all exports, batches of 4
#   .\scripts\deploy-functions-batched.ps1 -BatchSize 2   # smaller batches
#   .\scripts\deploy-functions-batched.ps1 -RetryFailed # last known quota failures only
#
param(
  [int]$BatchSize = 4,
  [int]$PauseSeconds = 45,
  [switch]$RetryFailed
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

if (-not $env:FUNCTIONS_DISCOVERY_TIMEOUT) {
  $env:FUNCTIONS_DISCOVERY_TIMEOUT = "60000"
}

$allFunctions = @(
  "onMatchCompleted",
  "onMatchLive",
  "onBallEventCreated",
  "onMatchRevisionCreated",
  "onMatchBreak",
  "verifyScoringIntegrity",
  "cleanupExpiredTournamentLookingPosts",
  "syncPublicScorecard",
  "syncPublicOverlay",
  "adminVerifyMatchIntegrity",
  "adminPreviewMatchStatsFromEvents",
  "adminReprocessMatchStats",
  "onNotificationCreated",
  "onTeamJoinRequestCreated",
  "onTeamRosterReportCreated",
  "onPlayerFollowWritten",
  "onProfileViewWritten",
  "onTeamProfileViewWritten",
  "onStreamStatusChanged",
  "linkYouTubeAccount",
  "storeStreamingOAuthToken",
  "createYouTubeLiveStream",
  "endYouTubeLiveStream",
  "listYouTubeChannels",
  "getYouTubeLiveChat",
  "getYouTubeBroadcastStatus",
  "startYouTubeLiveBroadcast",
  "exportYouTubeChapters",
  "createFacebookLiveStream",
  "createTwitchLiveStream",
  "lookupPlayerByPhone",
  "stampProxyPlayerRegistration",
  "createPlayerInvite",
  "acceptPlayerInvite"
)

$failedOnly = @(
  "onNotificationCreated",
  "createFacebookLiveStream",
  "getYouTubeBroadcastStatus",
  "listYouTubeChannels",
  "getYouTubeLiveChat",
  "endYouTubeLiveStream",
  "storeStreamingOAuthToken",
  "onMatchLive",
  "onTeamProfileViewWritten",
  "onMatchCompleted",
  "exportYouTubeChapters",
  "syncPublicOverlay",
  "onPlayerFollowWritten"
)

$targets = if ($RetryFailed) { $failedOnly } else { $allFunctions }
$failed = @()

Write-Host "Deploying $($targets.Count) function(s) in batches of $BatchSize..." -ForegroundColor Cyan

for ($i = 0; $i -lt $targets.Count; $i += $BatchSize) {
  $end = [Math]::Min($i + $BatchSize - 1, $targets.Count - 1)
  $batch = $targets[$i..$end]
  $only = ($batch | ForEach-Object { "functions:$_" }) -join ","
  Write-Host ""
  Write-Host "Batch $([int]($i / $BatchSize) + 1): $($batch -join ', ')" -ForegroundColor Yellow

  firebase deploy --non-interactive --only $only
  if ($LASTEXITCODE -ne 0) {
    $failed += $batch
    Write-Host "Batch failed - will continue with remaining batches." -ForegroundColor Red
  }

  if ($end -lt ($targets.Count - 1)) {
    Write-Host "Waiting ${PauseSeconds}s for Cloud Run quota to settle..." -ForegroundColor DarkGray
    Start-Sleep -Seconds $PauseSeconds
  }
}

Write-Host ""
if ($failed.Count -eq 0) {
  Write-Host "All function batches deployed successfully." -ForegroundColor Green
  exit 0
}

Write-Host "Some batches failed. Re-run with -RetryFailed after a minute:" -ForegroundColor Red
Write-Host "  .\scripts\deploy-functions-batched.ps1 -RetryFailed -BatchSize 2" -ForegroundColor Yellow
Write-Host "Failed: $($failed -join ', ')" -ForegroundColor Red
exit 1
