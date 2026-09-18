# CrickFlow Cloud Functions

## Series callables

Privileged Series operations are exported from `functions/src/series/seriesFunctions.js`:

- `createSeries`, `addSeriesAdmin`, `removeSeriesAdmin`, `updateSeriesSettings`
- `createSeriesClub`, `reviewSeriesApproval`, `reviewClubJoinRequest`
- `addSeriesClubAdmin`, `removeSeriesClubAdmin`
- `submitSeriesRegistration`, `submitPlayerJoinRequest`, `submitPlayerAddRequest`, `submitPlayerRemovalRequest`
- `proposeSeriesMatch` (optional `createMatchDraft: true` creates a linked draft match), `proposeSeriesTournament`
- `suspendSeriesEntity`, `getSeriesRegistrationIdentity`

Player join is two-step: Club Admin clears via `reviewClubJoinRequest`, then Series Admin
finalizes with `reviewSeriesApproval` (Super Admin may bypass club clearance).

All callables require Firebase Authentication and enforce Series/club role checks
server-side. Ranking updates run from `onMatchCompleted` via
`functions/src/series/updateSeriesRankings.js` when
`seriesId` is set and `seriesOfficialStatus == approved` (idempotent via
`seriesRankingsProcessed`). Sensitive identity is stored under
`series_registrations/{id}/private/identity` and readable only via
`getSeriesRegistrationIdentity`.

## Overview

Backend logic runs in **`functions/`** (Node.js 20, Firebase Functions v2). The earlier single-file stub only aggregated basic stats; the current layout is the **Phase 1.5** target.

## Deployed functions

| Export | Trigger | Purpose |
|--------|---------|---------|
| `onMatchCompleted` | `matches/{id}` updated → `status: completed` | **Stats from `ball_events` replay** (fallback innings cache), badges, hero, `statsSource` |
| `onMatchLive` | `matches/{id}` updated | Match start, 1st innings complete, 2nd innings start — fan-out + enriched messages |
| `onMatchBreak` | `matches/{id}` updated | Match break started / resumed — fan-out with current score |
| `onMatchRevisionCreated` | `matches/{id}/matchRevisions/{id}` created | DLS / target revision notifications |
| `onBallEventCreated` | `matches/{id}/ball_events/{eventId}` created | Wicket, four, six, milestones — enriched fan-out |
| `onMatchCompleted` | `matches/{id}` updated → `status: completed` | Result notification fan-out to team + followers |
| `onNotificationCreated` | `notifications/{id}` created | FCM bridge for in-app notifications |
| `onTeamJoinRequestCreated` | join request created | Push to owner/captain/VC |
| `verifyScoringIntegrity` | Scheduled daily 03:00 (Asia/Colombo) | Logs + writes `scoringIntegrity` on mismatched live/completed matches |
| `cleanupExpiredTournamentLookingPosts` | Scheduled daily 04:15 (Asia/Colombo) | Deletes community `tournamentNeed` looking posts after start date ≤ today or end date already passed |
| `adminVerifyMatchIntegrity` | Callable | Returns replay vs cache issues (organizer / scorer) |
| `adminPreviewMatchStatsFromEvents` | Callable | Preview per-player agg from events (no write) |
| `adminReprocessMatchStats` | Callable | Apply stats from events when `statsProcessed` is false (or `force:true`) |
| `syncPublicScorecard` | `matches/{id}` written | Public `public/scorecard` (no stream keys) |
| `syncPublicOverlay` | `matches/{id}/overlay/{docId}` written | Merges live overlay into public scorecard |
| `onProfileViewWritten` | `users/{id}/profileViews/{viewerId}` written | Increments `socialStats.profileViewsCount` |
| `onTeamProfileViewWritten` | `teams/{id}/profileViews/{viewerId}` written | Increments `teams.profileViewsCount` |
| `onStreamStatusChanged` | `matches/{id}` updated | Stream live/ended fan-out |
| `linkYouTubeAccount` | Callable | OAuth server auth code → refresh token |
| `createYouTubeLiveStream` | Callable | YouTube broadcast + RTMP credentials |
| `listYouTubeChannels` | Callable | Linked YouTube channel |
| `getYouTubeLiveChat` | Callable | Read-only live chat messages |
| `exportYouTubeChapters` | Callable | Replay markers → YouTube description chapters |
| `lookupPlayerByPhone` | Callable | Registrar-only: does this phone already belong to a CrickFlow Auth/user (public fields only) |
| `stampProxyPlayerRegistration` | Callable | Stamps `registrationSource` / `registeredByUserId` on a newly created player |
| `createPlayerInvite` | Callable | Creates a web/app invite link (no SMS from the registrar) |
| `acceptPlayerInvite` | Callable | Invitee (matching phone) accepts; stamps invite audit |

## Module layout

```
functions/src/
  index.js                 # exports
  match/
    onMatchCompleted.js
    onMatchLive.js
    onBallEventCreated.js
  utils/
    notificationBuilder.js   # enriched notification copy
    recipients.js          # scorers + team members + followers
    fanOut.js              # in-app + FCM per user
    matchFormat.js         # score/overs helpers
    ballEventStats.js      # event replay, collectPlayerAggFromEvents, integrity verify
    stats.js               # apply increments + legacy collectPlayerAgg(innings)
    badges.js              # 50, 100, 3w, 5w
  streaming/
    streamFunctions.js
    youtubeOAuth.js
    youtubeLive.js
  players/
    lookupPlayerByPhone.js
    playerInvites.js
```

## Idempotency

`onMatchCompleted` sets `statsProcessed: true` on the match document so re-saves do not double-count stats.

## Admin callables (ball-event stats)

```javascript
// Preview derived stats (Firebase client SDK)
const preview = await httpsCallable(functions, 'adminPreviewMatchStatsFromEvents')({ matchId });

// Integrity report
const report = await httpsCallable(functions, 'adminVerifyMatchIntegrity')({ matchId });

// Re-apply stats when completion failed (statsProcessed === false)
await httpsCallable(functions, 'adminReprocessMatchStats')({ matchId });
```

`adminReprocessMatchStats` with `force: true` can double-count career stats — use only after manual rollback in Firestore.

## Not implemented yet (Phase 2+)

- [ ] Callable delete match
- [ ] Auth custom claims (organizer / scorer roles on token)
- [ ] Scheduled cleanup of stale live matches
- [ ] Email / SMS notifications
- [ ] Net run rate calculation on tournament rows

## Local development

```bash
cd functions
npm install
firebase emulators:start --only functions,firestore
```

## Production deploy

```bash
firebase deploy --only functions
```

Windows — if deploy fails with **Cloud Run CPU quota** (`Quota exceeded for total allowable CPU per project per region`), deploy in batches:

```powershell
.\scripts\deploy-functions-batched.ps1 -RetryFailed -BatchSize 2
```

Or rules only / batched functions via the main script:

```powershell
.\scripts\deploy-firebase.ps1 -RulesOnly
.\scripts\deploy-firebase.ps1 -FunctionsOnly
```

Global function defaults (`functions/src/index.js`): `256MiB`, `cpu: 0.25` — keeps ~35 Cloud Run services within regional quota. Request a quota increase in [GCP Quotas](https://console.cloud.google.com/iam-admin/quotas?project=crickflow-b06bc) for **Cloud Run CPU** in `us-central1` if needed.

Requires Blaze plan for outbound FCM/network from functions.
