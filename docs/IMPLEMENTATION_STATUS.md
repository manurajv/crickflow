# CrickFlow — Implementation Status (Agent Handoff)




**Last updated:** Ball-by-ball architecture Phases A–C complete  

**Firebase project:** `crickflow-b06bc`  

**Android package:** `com.mavixas.crickflow`

> **Master doc:** [PRODUCT_ARCHITECTURE.md](PRODUCT_ARCHITECTURE.md) · **Scoring engine:** [SCORING_ENGINE_ARCHITECTURE.md](SCORING_ENGINE_ARCHITECTURE.md) · **Ball events:** [BALL_EVENT_ARCHITECTURE.md](BALL_EVENT_ARCHITECTURE.md) · **Doc index:** [README.md](README.md)

---

## Latest (ball-by-ball architecture)

| Item | Status |
|------|--------|
| Full scoring audit + migration plan | Done — [BALL_EVENT_ARCHITECTURE.md](BALL_EVENT_ARCHITECTURE.md) |
| `BallEventAggregator` — derive scorecard/stats from events | Done |
| Extended `BallEventModel` (teams, run breakdown, wicket/boundary flags) | Done |
| Scorecard reads event-derived batting/bowling/FOW/extras | Done |
| Batter minutes (Min) + maiden overs (M) from events | Done |
| Match insights top bat/bowl/milestones from event replay | Done |
| Phase B: no FOW/partnerships/fielders on innings write | Done |
| Phase B: `createdBy`, after-ball audit on events | Done |
| Phase B: `ScoringIntegrityCheck` (debug) | Done |
| Phase C: `onMatchCompleted` stats from `ball_events` | Done |
| Phase C: nightly `verifyScoringIntegrity` | Done |
| Phase C: admin verify / preview / reprocess callables | Done |
| Run-out integrity fix — `lineupChange` events for crease/bowler updates | Done |
| Run-out UI — professional dismissed/new-batter picker sheets | Done |
| Run-out scenarios + integrity tests (`scoring_engine_run_out_integrity_test.dart`) | Done |
| Run-out over display — single `W`, no extra dot after wicket; `lineupChange` hidden | Done |
| Run-out flow — full sheet (fielders, delivery type, runs) + “Who will face the next ball?” picker; `nextStrikerId`/`nextStrikerName` on event; wide/NB from match rules | Done |
| BallEvent wicket metadata (fielders, dismissed name, FOW context) persisted in Firestore | Done |
| Scorecard dismissal from event metadata — `run out Fielder` / `F1 / F2`, pro formats | Done |
| Scorecard stumped display — `st b Bowler` only (keeper stored, not shown) | Done |
| Dismissal standardization — `DismissalFormatter` + metadata-driven display everywhere | Done |
| Mankad — stored as `runOut` + `isMankad`; display `run out Bowler` | Done |
| Bowler wicket credit rules — `creditsBowlerWicket` in engine + Cloud Functions | Done |
| BallEvent metadata — `dismissalType`, `fielderIds`/`fielderNames`, `wicketNumber`, `isMankad` | Done |
| Caught behind / stumped auto wicketkeeper from match setup | Done |
| Caught behind auto-detect — `Caught` + keeper fielder → `dismissalSubType: caught_behind`, display `c †Keeper b Bowler` | Done |
| Wicketkeeper change events (`BallEventType.wicketKeeperChange`) + Change wicketkeeper shortcut | Done |
| Keeper metadata on wicket events (`wicketKeeperId`, `currentWicketKeeperId` at dismissal time) | Done |
| Single undo for wicket workflow (`undoGroupId` groups wicket + lineup changes) | Done |
| Active wicketkeeper cannot bowl (bowler picker blocks keeper) | Done |
| Wicketkeeper blocked as opening bowler (start innings + edit lineup) | Done |
| Scoring UI kit — unified bottom sheets (start innings → live scoring) | Done |
| Retired hurt — not a wicket; `retiredHurt` + `isEligibleToReturn`; batter can return | Done |
| Wicket picker — all dismissal types visible (no Show more) | Done |
| Quick settings sheet — 4-column grid, More shortcuts / Show less, primary + secondary tiers | Done |

---

## Latest (scorecard UI)

| Item | Status |
|------|--------|
| Collapsible innings cards (one expanded at a time) | Done |
| Batting / bowling tables (R B 4s 6s SR Min · O M R W Eco) | Done |
| Extras breakdown, total + CRR, to bat, fall of wickets | Done |
| Professional dismissal notation display | Done |
| Theme-only styling (`MatchScorecardView`) — no top match card | Done |

---

## Latest (wagon wheel)

| Item | Status |
|------|--------|
| Wagon wheel toggle (default OFF) at match creation / rules | Done |
| Popup after runs 1–6 and NB from bat | Done |
| `ball_events.wagonWheel` { x%, y%, shotType } | Done |
| Lines / scatter / heatmap + filters | Done |
| Match Insights + Player profile embed | Done |
| Progress tracker | [WAGON_WHEEL_IMPLEMENTATION.md](WAGON_WHEEL_IMPLEMENTATION.md) |

---

## Latest (ecosystem UX)

| Item | Status |
|------|--------|
| 5-tab bottom shell (Home · Discover · Matches · Community · Profile) | Done |
| Match hub tabs (Summary · Scorecard · Comms · Insights · Squads · MVP · Highlights) | Done |
| Match insights (hero, top bat/bowl, milestones, live MVP points) | Done (client-side) |
| Match squads (dual-column rosters, C/VC badges) | Done |
| Community posts (`community_posts`, feed, create, filters) | Done |
| Discover → Community category deep links | Done |
| Unified app bar + bottom nav colors (gold selected, surface chrome) | Done |
| Compact design tokens (`app_dimens.dart`) | Done |
| CricHeroes-style references (19 screens) | Inspiration only — not cloned |

---

## Phases 1 & 2 — Complete ✅

Ship when [PLAY_STORE_READINESS.md](PLAY_STORE_READINESS.md) manual steps are done.

## Phase 3 — In progress

See [PHASE3_ROADMAP.md](PHASE3_ROADMAP.md).

| 3.1 | Match highlights + auto commentary | Done |
| 3.2 | YouTube viewer + public web scorecard `/live/{id}` | Done |
| 3.2+ | HLS restream | Pending |
| 3.3 | WebRTC signaling + beta viewer | Done (media peer TBD) |
| 3.4 | Multi-camera (dual YouTube URLs) | Done |
| 3.5 | Fantasy leagues (join code, squad, leaderboard) | Done (MVP + CF scoring) |
| 3.6 | Ball tracking / AI | Not started — see [REMAINING_FEATURES.md](REMAINING_FEATURES.md) |

---

## MVP feature status (Phases 1–2)



| Area | Status |

|------|--------|

| Auth (Google, Phone, roles) | Done |

| Onboarding + splash routing | Done |

| Matches, scoring, undo, innings | Done |
| Match lifecycle (toss → chase → result, super over) | Done |
| Toss line under live score (1st inn, first 3 overs) | Done |
| Scorecard toss decision edit (bat/bowl swap, initial 1st inn) | Done |

| Teams, squads (existing + new players) | Done |

| Team join via invite link | Done |

| Tournaments (league + knockout + auto fixtures) | Done |

| Notifications, badges, stats (CF) | Done |

| Deep links + hosting (`/`, `/privacy`, `/open-app`) | Done |
| App Links (`crickflow-b06bc.web.app` + debug SHA in assetlinks) | Done |
| Settings → privacy (url_launcher) | Done |
| RTMP stream heartbeat (Firestore) | Done |

| RTMP (`rtmp_broadcaster`) | Done |

| Single login + Member/Viewer app mode | Done |

| Web admin (hosted `/admin`) | Done |

| Release signing scaffold | Done |
| GitHub Actions (`flutter analyze` + test) | Done |
| Store listing doc + release build script | Done |



---



## Your action items (cannot be automated)



| Step | Doc / script |

|------|----------------|

| Firebase deploy | `scripts/deploy-firebase.ps1` |

| Paste / refresh SHA-256 in assetlinks | `scripts/get-android-sha.ps1`, `scripts/update-assetlinks-sha.ps1` |

| Create release keystore | `docs/ANDROID_RELEASE_SIGNING.md` |

| Device QA | `docs/DEVICE_QA.md` |

| Full release order | `docs/RELEASE_CHECKLIST.md` |

| iOS: enable Associated Domains in Xcode | `ios/Runner/Runner.entitlements` |

| Custom domain `crickflow.app` (optional) | `docs/APP_LINKS.md` |



---



## Key files (recent ship-prep)



| Feature | Files |

|---------|--------|

| Onboarding | `onboarding_screen.dart`, `splash_screen.dart`, `prefs_keys.dart` |

| Team join | `team_join_banner.dart` |

| RTMP | `stream_service.dart`, `live_stream_screen.dart` |

| Hosting | `firebase.json`, `public/index.html`, `public/open-app.html`, `public/privacy.html`, `public/.well-known/` |
| App Links | `deep_link_utils.dart`, Android manifest, `assetlinks.json`, `apple-app-site-association` |

| Signing | `android/app/build.gradle.kts`, `key.properties.example` |

| Scripts | `deploy-firebase.ps1`, `get-android-sha.ps1`, `update-assetlinks-sha.ps1`, `build-release.ps1`, `create-release-keystore.ps1` |
| CI | `.github/workflows/flutter.yml` |



---



## Deploy



```powershell

.\scripts\deploy-firebase.ps1

flutter pub get

flutter run

```



---



## Changelog



| Phase | Changes |

|-------|---------|

| Account deletion | Settings UI, auth repo, Firestore rules |
| Ship prep | GitHub CI, STORE_LISTING, IOS_SETUP, build-release.ps1, README |
| Hosting links | Firebase site root, HTTPS rewrites, privacy page, debug assetlinks, iOS associated domain |
| Ship-prep | Onboarding, hosting, admin, signing, join team, full checklists |

| 2f | RTMP, release docs, team invite |

| 2e | Login roles, viewer mode, match feed |

| 2d | Squad picker, bracket advance |

| 2c | Deep links, knockout, photos |

| 1.5 | Cloud Functions, offline, FCM |


