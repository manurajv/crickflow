# CrickFlow Cloud Functions

## Overview

Backend logic runs in **`functions/`** (Node.js 20, Firebase Functions v2). The earlier single-file stub only aggregated basic stats; the current layout is the **Phase 1.5** target.

## Deployed functions

| Export | Trigger | Purpose |
|--------|---------|---------|
| `onMatchCompleted` | `matches/{id}` updated → `status: completed` | Player/team stats, badges, hero, tournament table, idempotent via `statsProcessed` |
| `onMatchLive` | `matches/{id}` updated → `status: live` | FCM topic `match_{id}` — match started |
| `onBallEventCreated` | `matches/{id}/ball_events/{eventId}` created | FCM + `highlights` doc for wicket, four, six |
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
    stats.js               # deduped player aggregates
    badges.js              # 50, 100, 3w, 5w
    tournament.js          # points table
    messaging.js           # FCM + in-app notifications
```

## Idempotency

`onMatchCompleted` sets `statsProcessed: true` on the match document so re-saves do not double-count stats.

## Not implemented yet (Phase 2+)

- [ ] Callable functions for admin (recalculate stats, delete match)
- [ ] Auth custom claims (organizer / scorer roles on token)
- [ ] Scheduled cleanup of stale live matches
- [ ] Email / SMS notifications
- [ ] Net run rate calculation on tournament rows
- [ ] Fan-out to all follower user IDs (only `createdBy` gets in-app notification today)

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
