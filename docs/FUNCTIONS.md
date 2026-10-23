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

## Org tournaments and matches (Oct 2026)

| Callable | Who | What |
|---|---|---|
| `startSeriesTournament` | Owner/admins directly; team admins (players if `competitionPolicy.membersCanRequest`) as a request | Links a tournament the caller organizes to the org (`mode: create` after the wizard, `mode: link` = admins adding an existing one), adds chosen org teams, writes a `series_competitions` row, audit + approval + notifications. |
| `startSeriesMatch` | Match creator/scorer; requester must own one side | Registers a match between two approved org teams. Inside an org tournament it inherits the tournament's status. |
| `updateSeriesCompetitionPolicy` | Owner | `series.competitionPolicy`: `tournamentRequestsNeedApproval`, `matchRequestsNeedApproval` (default true), `membersCanRequest` (default false). |
| `proposeSeriesTournament` (legacy) | as `startSeriesTournament` link | Older app builds; now requires the caller to organize the tournament. |

`reviewSeriesApproval` stores a rejection reason (older apps that send none get "No reason given"); a rejection unlinks the tournament/match from the org. Approval counts already-finished matches. Org rankings only count a match when an approved `series_competitions` row covers it (directly or via its tournament).

`proposeSeriesMatch` follows the same access rules as `startSeriesMatch`: players can propose only when `membersCanRequest` is on, and only for a match involving their own org team.

## Org teams are CrickFlow teams (Oct 2026)

- Every `series_clubs` row has `linkedTeamId` → a real `teams/{id}`. The app creates the team with the normal create-team flow and passes `linkedTeamId` to `createSeriesClub` (caller must own the team). Web / older apps don't, so `createSeriesClub` creates the team server-side (owner = caller).
- That team carries `orgLock: { seriesId, clubId, seriesName, lockedAt }`. Firestore rules then refuse client edits to its name, roster and details, deletion, team join requests/invitations, and moving players onto/off it. Stats/badges still update. Platform admins (`canManageTeams`) keep their moderation fields.
- The roster mirrors approved org membership changes (`activateMembership`, player removals) — done by Cloud Functions only. Match-only guests never touch it.
- A rejected org team is unlocked and stays a normal team.
- `migrateSeriesTeamLinks({ seriesId })` (org admins; the app runs it once per session when an admin opens the org) backfills existing org teams without deleting anything: locks a linked team owned by the org team's creator and adds active org members to it, or creates a team for org teams with none. Teams owned by someone else / already locked elsewhere are skipped and reported.
