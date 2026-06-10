# Ball-by-Ball Data Architecture — Single Source of Truth

**Status:** Living document (audit + migration plan)  
**Last updated:** June 2026  
**Related:** [SCORING_ENGINE_ARCHITECTURE.md](SCORING_ENGINE_ARCHITECTURE.md) · [FIREBASE_SCHEMA.md](FIREBASE_SCHEMA.md) · [WAGON_WHEEL_IMPLEMENTATION.md](WAGON_WHEEL_IMPLEMENTATION.md)

---

## Core principle

Every delivery creates one immutable **`ball_events`** document. All cricket statistics must be **computable from the event log**. Denormalized fields exist only as **projection caches** for live-read latency.

```
ball_events (truth)  →  BallEventAggregator / ScoringEngine.replay  →  UI + overlay + analytics
                              ↓
                    matches.innings[] (projection cache)
```

**Invariant:** `replay(allEvents) === innings projection` for every innings.

---

## Audit summary (June 2026)

### What is already event-sourced

| Area | Source today | Notes |
|------|--------------|-------|
| Undo | `fetchBallEvents` → delete last → `replayInnings` | ✅ Correct path in `MatchRepository.undoLastBall` |
| Over dots / current over | `ball_events` via `ScoringDisplayUtils` | ✅ |
| Extras breakdown (scorecard) | `ScorecardDisplayService.extrasBreakdown` from events | ✅ Partial — total still from `innings.extras` |
| Dismissal notation | Wicket `ball_events` metadata | ✅ |
| Wagon wheel | `ball_events.wagonWheel` only | ✅ |
| Fantasy / live MVP points | `FantasyPointsService.rawPlayerPoints(events)` | ✅ |
| Commentary | Stored on event at record time | ✅ (generated once, stored on fact) |

### Duplicate stores (projection cache — acceptable if replayable)

| Location | Fields | Role |
|----------|--------|------|
| `matches.innings[]` | `totalRuns`, `totalWickets`, `legalBalls`, `extras` | Live score projection |
| `matches.innings[].batsmen[]` | `runs`, `balls`, `fours`, `sixes`, `isOut`, `dismissalInfo` | Batting projection |
| `matches.innings[].bowlers[]` | `oversBowledBalls`, `runsConceded`, `wickets`, `wides`, `noBalls` | Bowling projection |
| `matches.innings[].fielders[]` | `catches`, `runOuts`, `stumpings` | Fielding projection |
| `matches.innings[].partnerships[]` | Closed partnership records | Partnership projection |
| `matches.innings[].fallOfWickets[]` | FOW lines | FOW projection |
| `matches.innings[]` | `partnershipRuns`, `partnershipBalls` | Active partnership cache |
| `overlay/current` | Scorebug snapshot | Broadcast cache |
| `public/scorecard` | Web viewer snapshot | Public cache |

### Reads still using projection instead of events

| Consumer | Before | Target |
|----------|--------|--------|
| `MatchScorecardView` batting/bowling rows | `innings.batsmen` / `innings.bowlers` | `BallEventAggregator.projectInnings` |
| `MatchScorecardView` fall of wickets | `innings.fallOfWickets` | Derived from replay / wicket events |
| `MatchScorecardView` Min column | Hardcoded `-` | `batterMinutesFromEvents` |
| `MatchScorecardView` Maidens (M) | Hardcoded `0` | `maidenOversFromEvents` |
| `MatchInsightsService` top bat/bowl | `innings.batsmen` / `innings.bowlers` | Event-derived replay |
| `MatchInsightsService` milestones | `innings.batsmen` / `innings.bowlers` | Event-derived replay |
| `functions/onMatchCompleted` | `collectPlayerAgg(innings)` | Phase C: aggregate from `ball_events` |
| `BadgeService.pickMatchHero` | `innings` projections | Phase C: event replay |

### BallEvent schema gaps vs target spec

| Field | Status | Notes |
|-------|--------|-------|
| `matchId`, `inningsNumber`, `overNumber`, `ballInOver` | ✅ | `ballInOver` = legal ball in over |
| `timestamp`, `sequence` | ✅ | |
| `strikerId`, `nonStrikerId`, `bowlerId` | ✅ | Pre-ball snapshot |
| `battingTeamId`, `bowlingTeamId` | ✅ Added | Populated at record time |
| `tournamentId` | ✅ Added | From match |
| `runs` (totalRuns), `batsmanRuns` (runsOffBat) | ✅ | |
| `byeRuns`, `legByeRuns`, `wideRuns`, `noBallRuns`, `penaltyRuns` | ✅ Added | Explicit breakdown per delivery |
| `isLegalDelivery` | ✅ | |
| `countsAsBallFaced`, `countsInOver`, `countsToBowler` | ✅ Added | Stored audit flags |
| `isWicket`, `bowlerGetsWicket` | ✅ Added | |
| `wicketType`, `dismissedPlayerId`, `fielders[]` | ✅ | |
| `isBoundary`, `boundaryType` | ✅ Added | `four` / `six` |
| `wagonWheel` | ✅ | x%, y%, shotType, source |
| `batterCreaseTime` / `batterDismissalTime` | 🔶 Derived | Minutes computed from event timestamps + crease entry |
| `partnershipId` on event | ❌ Future | Partnerships derived from wicket boundaries |
| `shotDistance`, `shotZone` | ❌ Future | Wagon wheel schema extensible |
| `createdBy` (scorer uid) | ❌ Phase B | |
| `strikerAfterBall` / `nonStrikerAfterBall` | ❌ Phase B | Undo audit |

---

## Derivation map

All items below are produced by `BallEventAggregator` (`lib/domain/scoring/ball_event_aggregator.dart`):

| Stat / feature | Derivation |
|----------------|------------|
| Scorecard batting | Replay → `BatsmanInningsModel` per player |
| Scorecard bowling | Replay → `BowlerInningsModel` + maiden map |
| Extras breakdown | Sum `byeRuns`, `legByeRuns`, `wideRuns`, `noBallRuns`, `penaltyRuns` |
| Team total | Sum `runs` per innings |
| Fall of wickets | Wicket events + running score at dismissal |
| Partnerships | Reset on wicket; runs/balls between dismissals |
| Fielding | Wicket events → catches / run outs / stumpings |
| Min (minutes) | First crease appearance timestamp → dismissal or now |
| Strike rate / economy | `CricketMath` on derived counts |
| Wagon wheel | Filter events with `wagonWheel.enabled` |
| Over history (`0 1 4 W`) | Events grouped by `overNumber` |
| Worm / run rate graphs | Cumulative `runs` by `sequence` |
| MVP / fantasy | `FantasyPointsService` on events |
| Milestones (50, 3 wkts) | Derived batting/bowling totals |
| Undo | Delete event → full replay (no partial reverse) |

---

## Projection cache policy

| Write path | Order |
|------------|-------|
| `recordBall` | 1. Build `BallEvent` 2. Reduce 3. Batch write `ball_events` + `matches.innings` + `overlay` |
| `undoLastBall` | 1. Delete last event 2. Replay all 3. Rewrite projection |

**Rule:** UI and analytics **prefer event-derived** values when `ball_events` are loaded. Fall back to `innings[]` only when events are unavailable (legacy matches).

---

## Migration phases

### Phase A — Done (this pass)

- [x] `BallEventAggregator` — pure derivation service
- [x] Extended `BallEventModel` canonical fields
- [x] Scorecard + insights wired to event-derived stats
- [x] Batter minutes + maiden overs from events
- [x] Unit tests for aggregator

### Phase B — Done

- [x] `createdBy` on every event (scorer uid from live scoring)
- [x] `strikerAfterBall` / `nonStrikerAfterBall` on every event
- [x] `ScoringIntegrityCheck` — debug `replay(events) == innings` after record/undo
- [x] Stop persisting `partnerships` / `fallOfWickets` / `fielders` on innings
- [x] `BallEventAggregator` derives FOW, partnerships, fielding from events

### Phase C — Done

- [x] `onMatchCompleted` aggregates from `ball_events` (fallback: innings cache)
- [x] `functions/src/utils/ballEventStats.js` — server replay + `collectPlayerAggFromEvents`
- [x] Badges + match hero from event-derived innings
- [x] `verifyScoringIntegrity` — nightly scheduled scan (03:00 Asia/Colombo)
- [x] Admin callables: `adminVerifyMatchIntegrity`, `adminPreviewMatchStatsFromEvents`, `adminReprocessMatchStats`
- [x] Match doc `statsSource: ball_events | innings_cache` on completion

### Phase D — Future features (schema-ready)

- Duckworth-Lewis, powerplay phase tags, pitch maps, AI insights — all filter/group `ball_events` without schema breaks.

---

## Key files

| Area | Path |
|------|------|
| Ball event model | `lib/data/models/ball_event_model.dart` |
| Aggregator (client) | `lib/domain/scoring/ball_event_aggregator.dart` |
| Aggregator (server) | `functions/src/utils/ballEventStats.js` |
| Reducer / replay | `lib/domain/services/scoring_engine.dart` |
| Integrity (client debug) | `lib/domain/scoring/scoring_integrity_check.dart` |
| Integrity (server nightly) | `functions/src/match/verifyScoringIntegrity.js` |
| Admin callables | `functions/src/admin/scoringAdmin.js` |
| Persistence | `lib/data/repositories/match_repository.dart` |
| Scorecard UI | `lib/features/matches/presentation/widgets/match_scorecard_view.dart` |
| Insights | `lib/domain/services/match_insights_service.dart` |
| Tests | `test/ball_event_aggregator_test.dart` |

---

## Undo checklist

Undo must reverse by **replay**, not partial mutation:

| State | Replay |
|-------|--------|
| Runs / wickets / overs | ✅ |
| Striker / non-striker | ✅ |
| Batter / bowler stats | ✅ |
| Extras | ✅ |
| Free hit | ✅ |
| Partnership | ✅ |
| Fall of wickets | ✅ (via replay) |
| Fielder credits | ✅ (via replay) |
| Wagon wheel | ✅ (event deleted) |
| Minutes | ✅ (re-derived) |
| MVP | ✅ (re-derived) |
| Milestones | ✅ (re-derived) |

**Do not use** `ScoringEngine._reverseEvent` — partial and incomplete.
