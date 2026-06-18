# Wagon Wheel — Implementation Progress

**Status:** Phase 3 complete (visual consistency + validation)  
**Last updated:** June 2026  

**Related:** [SCORING_ENGINE_ARCHITECTURE.md](SCORING_ENGINE_ARCHITECTURE.md) · [FIREBASE_SCHEMA.md](FIREBASE_SCHEMA.md)

---

## Overview

Broadcast-style wagon wheel for CrickFlow: scorers mark shot direction on a top-down ground view; coordinates are stored on each `ball_events` document and drive match, player, team, and career analytics.

---

## Progress checklist

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Feature toggle (`wagonWheelEnabled`, default OFF) | ✅ Done | Match creation, match rules screen, `MatchRulesEditor` |
| 2 | Eligibility rules (runs 1–6, NB from bat only) | ✅ Done | `wagon_wheel_eligibility.dart` |
| 3 | Selection popup (tap / drag / confirm) | ✅ Done | `wagon_wheel_selection_sheet.dart` |
| 4 | Percentage coordinate storage on `BallEvent` | ✅ Done | `wagonWheel: { x, y, shotType, source }` |
| 5 | Scoring flow integration (no UI redesign) | ✅ Done | `live_scoring_screen.dart` — popup before `recordBall` |
| 6 | Undo removes wagon wheel with event | ✅ Done | Event deleted on undo; no separate store |
| 7 | Offline support | ✅ Done | Same offline queue as ball events |
| 8 | Shot line rendering (pitch centre → point) | ✅ Done | `WagonWheelGroundPainter` |
| 9 | Run colour system | ✅ Done | `wagon_wheel_colors.dart` |
| 10 | View modes: lines / scatter / heatmap | ✅ Done | `WagonWheelViewScreen` |
| 11 | Filters (batter, bowler, team, match, innings, runs) | ✅ Done | `WagonWheelFilter` + provider |
| 12 | Match insights embed + quick filters | ✅ Done | `WagonWheelEmbeddedSection` |
| 13 | Player career embed (bat + bowl) | ✅ Done | `PlayerDetailScreen` |
| 13b | Team wagon wheel embed | ✅ Done | `TeamDetailScreen` |
| 13c | Full view filter panel | ✅ Done | Batter, bowler, team, innings, runs, date, view mode |
| 13d | Performer tap → filtered full view | ✅ Done | Match Insights top bat/bowl tiles |
| 14 | Insights (off/leg %, zones, boundaries) | ✅ Done | `WagonWheelAnalyticsService` |
| 15 | Unit tests | ✅ Done | `test/wagon_wheel_test.dart` |
| 16 | Tournament default match settings | ⏳ Pending | `TournamentModel` has no rules field yet |
| 17 | Bowler / team dedicated screens | ⏳ Pending | Providers exist; UI entry points TBD |
| 18 | Custom ground image asset | ⏳ Pending | `WagonWheelGroundRenderer` ready for image overlay |
| 19 | Zone validation (1–3 inside, 4 rope, 6 outside) | ✅ Done | `wagon_wheel_field_geometry.dart` |
| 20 | Striker wicket line origin | ✅ Done | Lines from top (striker) end; bowler end at bottom |
| 21 | Pitch length + boundary visuals | ✅ Done | ~33% shorter pitch; dark outside ground |
| 22 | Six line emphasis | ✅ Superseded | Phase 3: uniform line style for all runs |
| 23 | Uniform shot lines (colour only) | ✅ Done | `shotLineWidth`, `shotEndpointRadius` |
| 24 | Pixel-accurate boundary validation | ✅ Done | `WagonWheelCoordinateMapper` |
| 25 | Sixes outside only; 4s anywhere | ✅ Done | Zone A/B/C matrix |
| 26b | Six manual placement outside boundary only | ✅ Done | Inside taps snap along angle |
| 26 | Shared `WagonWheelRenderer` + fixed aspect | ✅ Done | No drift between screens |
| 27 | Simplified full-view filters | ✅ Done | Batter/bowler/team/innings/runs only |
| 28 | LHB display mirror + off/leg labels | ✅ Done | `wagon_wheel_batting_orientation.dart` |
| 23 | AI / CV auto-detection | ⏳ Future | Schema supports `source`, `confidence` |
| 24 | Dot ball / wicket wagon wheel | ⏳ Future | Eligibility hooks ready |
| 25 | Advanced filters (PP, death, spin vs pace) | ⏳ Future | Filter model extensible |

---

## Architecture

```
LiveScoringScreen
  → WagonWheelEligibility.shouldCapture?
  → WagonWheelSelectionSheet (x%, y%)
  → BallEventInput.wagonWheel
  → MatchRepository.recordBall → Firestore ball_events.wagonWheel

Analytics
  → ballEventsProvider + WagonWheelAnalyticsService
  → WagonWheelChart / WagonWheelViewScreen
```

---

## Data schema (ball event)

```json
{
  "runs": 4,
  "batsmanRuns": 4,
  "strikerId": "player_123",
  "bowlerId": "player_456",
  "wagonWheel": {
    "enabled": true,
    "x": 67.2,
    "y": 24.1,
    "shotType": "four",
    "source": "manual"
  }
}
```

Coordinates are **always percentages** (0–100), never pixels. Pitch centre: `(50, 50)`.

---

## Key files

| Area | Path |
|------|------|
| Model | `lib/data/models/wagon_wheel_data.dart` |
| Ball event | `lib/data/models/ball_event_model.dart` |
| Eligibility | `lib/domain/wagon_wheel/wagon_wheel_eligibility.dart` |
| Field geometry | `lib/domain/wagon_wheel/wagon_wheel_field_geometry.dart` |
| Ground renderer | `lib/features/wagon_wheel/presentation/widgets/wagon_wheel_ground_renderer.dart` |
| Analytics | `lib/domain/wagon_wheel/wagon_wheel_analytics_service.dart` |
| Handedness coords | `lib/domain/wagon_wheel/wagon_wheel_batting_orientation.dart` |
| Selection UI | `lib/features/wagon_wheel/presentation/wagon_wheel_selection_sheet.dart` |
| Painter | `lib/features/wagon_wheel/presentation/widgets/wagon_wheel_ground_painter.dart` |
| Full view | `lib/features/wagon_wheel/presentation/wagon_wheel_view_screen.dart` |
| Providers | `lib/shared/providers/wagon_wheel_provider.dart` |
| Scoring hook | `lib/features/scoring/presentation/live_scoring_screen.dart` |
| Settings | `start_match_setup_form.dart`, `match_scoring_rules_screen.dart` |
| Tests | `test/wagon_wheel_test.dart` |

---

## Scorer workflow

1. Toggle **Enable wagon wheel tracking** ON at match creation (default OFF).
2. Tap run **1–6** (or NB + runs off bat).
3. Wagon wheel sheet opens — tap/drag marker, **Confirm shot**.
4. Ball event saved with coordinates; scoring screen unchanged otherwise.
5. **Cancel** on sheet aborts the ball (no score recorded).
6. **Undo** removes the event and its wagon wheel data together.

---

## Routes

- `/wagon-wheel?matchId=…` — match wagon wheel
- `/wagon-wheel?batterId=…` — batter career
- `/wagon-wheel?bowlerId=…` — bowler conceded
- `/wagon-wheel?teamId=…` — team shots
- `/wagon-wheel?tournamentId=…` — tournament aggregate

---

## Next steps

1. Add `defaultMatchRules` to `TournamentModel` for tournament-level WW default.
2. Ship ground image asset and optional `Image.asset` fallback in painter.
3. Bowler tab on match hub + team detail wagon wheel cards.
4. Cloud Function: optional wagon wheel summary on match complete.
