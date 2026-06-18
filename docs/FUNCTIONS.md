# CrickFlow Cloud Functions

## Overview

Backend logic runs in **`functions/`** (Node.js 20, Firebase Functions v2). The earlier single-file stub only aggregated basic stats; the current layout is the **Phase 1.5** target.

## Deployed functions

| Export | Trigger | Purpose |
|--------|---------|---------|
| `onMatchCompleted` | `matches/{id}` updated → `status: completed` | **Stats from `ball_events` replay** (fallback innings cache), badges, hero, `statsSource` |
| `onMatchLive` | `matches/{id}` updated | Match start, 1st innings complete, 2nd innings start — fan-out + enriched messages |
| `onMatchRevisionCreated` | `matches/{id}/matchRevisions/{id}` created | DLS / target revision notifications |
| `onBallEventCreated` | `matches/{id}/ball_events/{eventId}` created | Wicket, four, six, milestones — enriched fan-out |
| `onMatchCompleted` | `matches/{id}` updated → `status: completed` | Result notification fan-out to team + followers |
| `onNotificationCreated` | `notifications/{id}` created | FCM bridge for in-app notifications |
| `onTeamJoinRequestCreated` | join request created | Push to owner/captain/VC |
| `verifyScoringIntegrity` | Scheduled daily 03:00 (Asia/Colombo) | Logs + writes `scoringIntegrity` on mismatched live/completed matches |
| `adminVerifyMatchIntegrity` | Callable | Returns replay vs cache issues (organizer / scorer) |
| `adminPreviewMatchStatsFromEvents` | Callable | Preview per-player agg from events (no write) |
| `adminReprocessMatchStats` | Callable | Apply stats from events when `statsProcessed` is false (or `force:true`) |
| `syncPublicScorecard` | `matches/{id}` written | Public `public/scorecard` (no stream keys) |
| `syncPublicOverlay` | `matches/{id}/overlay/{docId}` written | Merges live overlay into public scorecard |

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
  admin/
    scoringAdmin.js        # callable QA + reprocess
    tournament.js          # points table
    messaging.js           # FCM + in-app notifications
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

Requires Blaze plan for outbound FCM/network from functions.
