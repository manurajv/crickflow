# CrickFlow — Application Architecture

## Overview

CrickFlow is a **feature-first Flutter** application using **Riverpod** for state management, **GoRouter** for navigation, and **Firebase** as the primary backend. A **Node.js/Express** REST API supplements role-based operations and future admin tooling.

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter (iOS / Android)                  │
│  ┌──────────┐  ┌────────────┐  ┌─────────────────────────┐ │
│  │ UI Layer │→ │ Riverpod   │→ │ Repositories / Services │ │
│  └──────────┘  └────────────┘  └───────────┬─────────────┘ │
└────────────────────────────────────────────┼────────────────┘
                                             │
              ┌──────────────────────────────┼──────────────────┐
              ▼                              ▼                  ▼
     ┌────────────────┐           ┌──────────────┐   ┌─────────────┐
     │ Firebase Auth  │           │  Firestore   │   │  Storage    │
     │ Google / Phone │           │  Real-time   │   │  Images     │
     └────────────────┘           └──────────────┘   └─────────────┘
                                             │
                                    ┌────────┴────────┐
                                    │ Cloud Functions │
                                    │ Stats / Badges  │
                                    └─────────────────┘
                                             │
                                    ┌────────┴────────┐
                                    │ Express REST API│
                                    └─────────────────┘
```

## Layer Responsibilities

| Layer | Path | Responsibility |
|-------|------|----------------|
| **Presentation** | `lib/features/*/presentation/` | Screens, widgets, user input |
| **Application** | `lib/shared/providers/` | Riverpod providers, routing |
| **Domain** | `lib/domain/services/` | Scoring engine, badge logic (pure Dart) |
| **Data** | `lib/data/` | Models, Firestore repositories |
| **Core** | `lib/core/` | Theme, constants, utilities |

## Key Design Decisions

1. **Customizable match rules** — `MatchRulesModel` is persisted on every match before scoring starts. Supports standard and tennis cricket.
2. **Scoring engine** — Pure Dart `ScoringEngine` applies ball events deterministically; repositories persist to Firestore in atomic batches.
3. **Real-time sync** — Match document + `ball_events` subcollection + `overlay/current` document. Viewers subscribe via streams.
4. **Location schema** — `LocationModel` embedded on users, teams, players, matches, tournaments for future geo-filtering.
5. **Offline** — Firestore persistence (enable in app init for production).

## Match Lifecycle

```
draft → scheduled → live → inningsBreak → completed
```

Single matches and tournament matches share the same `MatchModel`; tournament link via `tournamentId`.

## Security

- Firestore rules enforce auth + role-based writes (see `firestore.rules`).
- Scorer/organizer roles validated server-side in Express for sensitive endpoints.

## Future Expansion Hooks

- `overlayVersion` field for optimistic overlay sync
- `StreamMetadataModel` for RTMP/WebRTC
- Cloud Functions for stats aggregation, notifications, AI highlights
