# CrickFlow — Product & System Architecture

**Brand:** CrickFlow (working title) · **Firebase:** `crickflow-b06bc` · **Package:** `com.mavixas.crickflow`

> UI references (19 CricHeroes-style screens) are **inspiration only** — navigation, information hierarchy, and ecosystem scope. CrickFlow uses a **dark broadcast theme** (electric blue + gold), compact density, and original components.

---

## 1. Product vision

CrickFlow is a **cricket ecosystem**, not only a scorer:

| Pillar | Status |
|--------|--------|
| Live ball-by-ball scoring | ✅ |
| Custom match rules (tennis / indoor / T20…) | ✅ |
| Tournaments & knockout | ✅ |
| Teams & players + location | ✅ |
| RTMP + YouTube viewing | ✅ |
| Public web scorecard | ✅ |
| Highlights & commentary | ✅ |
| Fantasy MVP (MVP) | ✅ MVP |
| Multi-tab match hub | ✅ Shell |
| AI highlights / insights | Client insights ✅ · ML 🔜 |
| Community marketplace | ✅ Posts MVP |
| Store / PRO | ✅ Roadmap screen · IAP 🔜 |

**Audience:** Sri Lankan tennis-ball, indoor, school, club cricket — organizers, scorers, streamers, fans.

---

## 2. Navigation architecture

### Bottom shell (5 tabs)

| Tab | Route | Screen |
|-----|-------|--------|
| Home | `/home` | Feed, welcome, quick actions |
| Discover | `/discover` | Geo matches, tournaments, teams + recruitment |
| Matches | `/matches` | Filtered match list |
| Community | `/community` | Recruitment posts feed |
| Profile | `/profile` | Account, Member/Viewer mode |

Implemented via `StatefulShellRoute` + `MainShellScaffold`.

### Match hub (7 tabs)

| Tab | Implementation |
|-----|----------------|
| Summary | `MatchSummaryTab` — scoreboard, stream, actions |
| Scorecard | `MatchScorecardTab` |
| Comms | `MatchCommentaryTab` — ball timeline |
| Insights | `MatchInsightsTab` — hero, top bat/bowl, milestones |
| Squads | `MatchSquadsTab` — dual-column rosters, C/VC |
| MVP | `MatchMvpTab` — live fantasy-style points + link to `/fantasy` |
| Highlights | `MatchHighlightsTab` |

Route: `/match/:id` → `MatchHubScreen`.

---

## 3. Design system (chrome)

| Token | Value | Use |
|-------|-------|-----|
| `chromeBackground` | `surface` #141B2D | App bar + bottom nav |
| `navSelected` | Gold #FFC107 | Active tab icon + label |
| `navUnselected` | `textSecondary` | Inactive tabs |
| `navIndicator` | Blue 25% | Nav pill |
| `appBarGradient` | Blue → surface | Subtle app bar depth |

**Widgets:** `CfChromeAppBar`, compact `AppDimens`, global `NavigationBarTheme`.

---

## 4. Flutter architecture

```
lib/
├── config/routes/       # GoRouter + shell
├── core/theme/          # AppColors, AppTheme, AppDimens
├── data/                # Models, repositories, services
├── domain/services/     # ScoringEngine, FantasyPoints, …
├── features/            # Feature-first UI
└── shared/              # Providers, widgets
```

**State:** Riverpod · **Routing:** GoRouter · **Backend:** Firebase (Auth, Firestore, FCM, Storage, Functions)

See [ARCHITECTURE.md](ARCHITECTURE.md) for layer diagram.

---

## 5. Firestore (summary)

| Collection | Notes |
|------------|--------|
| `users`, `players`, `teams` | Location on every entity |
| `matches` + `ball_events`, `overlay`, `public`, `highlights`, `webrtc` | Real-time match |
| `tournaments` | League / knockout |
| `fantasy_leagues` + `entries` | Join code leagues |
| `notifications`, `badges` | Engagement |

Full schema: [FIREBASE_SCHEMA.md](FIREBASE_SCHEMA.md)

---

## 6. Cloud Functions

| Function | Trigger |
|----------|---------|
| `onMatchCompleted` | Stats, badges, hero, standings |
| `onMatchLive` | FCM match start |
| `onBallEventCreated` | Highlights doc + FCM |
| `syncPublicScorecard` | Public web mirror |
| `syncPublicOverlay` | Overlay on public page |

---

## 7. Reference screens → CrickFlow mapping

| Reference pattern | CrickFlow approach |
|-------------------|-------------------|
| Red app bar + white body | Dark surface + gold/blue accents |
| My Cricket sub-tabs | Shell + `/matches` + tournaments route |
| Match: Scorecard / Comms / MVP | `MatchHubScreen` tabs |
| Insights / Heroes | `MatchInsightsTab` (client-side; CF hero on complete) |
| Community grid | `/discover` categories |
| Looking / recruitment | `/community` posts |
| Stats grid | `/analytics` + player profiles (expand) |
| Store | Future tab or `/store` |

---

## 8. Roadmap & progress

### Done (ship-ready core)

- Phases 1–2: Auth, scoring, teams, tournaments, RTMP, deep links, release docs
- Phase 3.1–3.5: Highlights, YouTube, public scorecard, WebRTC signaling, multi-cam, fantasy
- **UX:** Compact theme, unified chrome, 5-tab shell, match hub

### Next (recommended order)

1. **Discover** — geo queries on matches, tournaments, grounds
2. **WebRTC media** — `flutter_webrtc` ([WEBRTC.md](WEBRTC.md))
3. **AI insights** — ML performance cards (beyond client aggregates)
4. **AI highlights** — clip markers, thumbnails
5. **Play Store** — when ready ([PLAY_STORE_READINESS.md](PLAY_STORE_READINESS.md))

Track detail: [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md)

---

## 9. Documentation index

| Doc | Purpose |
|-----|---------|
| [README.md](README.md) | Doc index |
| **PRODUCT_ARCHITECTURE.md** | This file — vision + structure |
| [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) | Agent handoff / checklist |
| [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) | Tokens & components |
| [MVP_ROADMAP.md](MVP_ROADMAP.md) | Phase 1–2 |
| [PHASE3_ROADMAP.md](PHASE3_ROADMAP.md) | Phase 3 |
| [FIREBASE_SCHEMA.md](FIREBASE_SCHEMA.md) | Collections |
| Release / ops | `RELEASE_CHECKLIST`, `DEVICE_QA`, `ANDROID_RELEASE_SIGNING` |

Removed duplicate: `FULL_IMPLEMENTATION.md` (merged here + IMPLEMENTATION_STATUS).

---

## 10. Deploy

```powershell
.\scripts\deploy-firebase.ps1
flutter pub get
flutter run
```

After schema changes:

```powershell
firebase deploy --only firestore:rules,firestore:indexes
```
