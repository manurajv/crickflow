# CrickFlow — Implementation Status (Agent Handoff)




**Last updated:** Ball-by-ball architecture Phases A–C complete  

**Firebase project:** `crickflow-b06bc`  

**Android package:** `com.mavixas.crickflow`

> **Master doc:** [PRODUCT_ARCHITECTURE.md](PRODUCT_ARCHITECTURE.md) · **Scoring engine:** [SCORING_ENGINE_ARCHITECTURE.md](SCORING_ENGINE_ARCHITECTURE.md) · **Ball events:** [BALL_EVENT_ARCHITECTURE.md](BALL_EVENT_ARCHITECTURE.md) · **Doc index:** [README.md](README.md)

---

## Latest (live scoring quick shortcuts)

| Item | Status |
|------|--------|
| Need Help — scoring mistake (last 20 balls), change scorer, facing problem report | Done |
| Facing problem reports → `scoringIssueReports/` | Done |
| Power Play management (create/edit/delete slots + labels) | Done |
| Change Squad — Team A/B, playing vs substitutes, swap, add roster/guest | Done |
| Live lineup refresh via `matchLineupSquadsProvider` invalidation | Done |
| Match Breaks — drinks, timed out, lunch, stumps, rain, other | Done |
| Active break banner + slide to resume | Done |
| Break history on match doc + match summary tab | Done |
| Break start/end notifications (Cloud Function `onMatchBreak`) | Done — deploy functions |
| Firestore rules — `scoringIssueReports/` | Done — deploy rules |

---

## Latest (notifications)

| Item | Status |
|------|--------|
| Team members receive match notifications (fan-out) | Done |
| Match followers (`matchFollowers/`) + Follow button | Done |
| Notification preferences (team + follower toggles) | Done |
| Per-team notification toggle on team detail | Done |
| Enriched push/in-app messages (score, target, chase) | Done — deploy functions |
| Second innings notification fix | Done — deploy functions |
| DLS / target revision notifications | Done — deploy functions |
| Team join request badge count on team cards | Done |
| Home bell unread count | Done (existing) |

---

## Latest (revise target & match result)

| Item | Status |
|------|--------|
| Scoring shortcut — Revise Target | Done |
| Scorer-assisted DLS (manual target from officials, no ICC math) | Done |
| DLS — overs reduced from locked to scheduled; target only on End Innings | Done |
| First innings — Continue Innings (overs only, no target) | Done |
| First innings — End Innings after DLS | Done |
| End Innings shortcut + break → 2nd innings flow | Done |
| Second innings — overs + target revision | Done |
| End Innings — All Out / Declare / Penalty Runs | Done |
| Match Result — winner, draw, abandoned | Done |
| Firestore `matchRevisions/` + `matchTimeline/` history | Done |
| Live banner + match summary DLS card | Done |
| Scorecard / summary revision badges & history | Done |
| Live scoring header — scales to avoid overflow with chase/DLS lines | Done |
| Scorer-only access | Done |
| Firestore rules deployed | Done |

---

## Latest (start match setup)

| Item | Status |
|------|--------|
| Ground search — Places autocomplete on setup form | Done |
| Ground map picker — separate screen with search + draggable pin | Done |
| Map pick requires ground name text field | Done |
| Special cases — wide/no-ball rules (runs, legal delivery) on setup | Done |
| Schedule / Next buttons — equal width, label "Schedule" | Done |
| Ground map picker — WebView + Maps JavaScript API (tap/drag pin) | Done |
| Players per team (1–25, default 11) on Start Match setup | Done |
| Squad selection — playing XI cap + separate substitutes | Done |
| Squad UI — blue playing / orange substitute colors + PLAYING/SUB badges | Done |
| Auto-convert to substitute when playing squad full | Done |
| Add player — permanent team add vs match-only guest (role/styles required) | Done |
| Match player snapshots in Firestore (`teamAPlayingPlayers`, substitutes) | Done |
| Toss / lineup — playing XI only (substitutes excluded) | Done |
| Match start validation — exact `playersPerTeam` per team | Done |
| Firestore rules — match setup snapshots + `playersPerTeam` | Done |
| Team add notification (`team_member_added`) + report to admin | Done |

---

## Latest (match officials & scorer permissions)

| Item | Status |
|------|--------|
| Match type UI — Test: wagon wheel on, special cases off | Done |
| Match type UI — Indoor: wagon wheel off, special cases on | Done |
| Match type UI — Limited overs: both visible | Done |
| Match officials — player name / Player ID search (directory style) | Done |
| Match officials — snapshots with playerId, name, profilePhoto, userId | Done |
| Firestore officials — named keys (`umpire1`, `scorer1`, …) + legacy arrays | Done |
| Scorer 1 auto-assigned to match creator | Done |
| Scorer 2 selectable; both scorers can score live | Done |
| Live scoring — non-scorers read-only + “View Match” | Done |
| Change Scorer — replace Scorer 1/2 slot, Firestore + realtime permissions | Done — deploy rules |
| Firestore rules — `scorer1UserId` / `scorer2UserId` write access | Done — deploy rules |

---

## Latest (add player UI)

| Item | Status |
|------|--------|
| Match squad add-player sheet — card options, inline permanent search, polished guest form | Done |
| Add registered player screen — name / partial Player ID search (walk-in removed) | Done |
| `searchAvailablePlayers` — full name + partial CF ID fallback | Done |

---

## Latest (select team screen)

| Item | Status |
|------|--------|
| Select Team — removed inline country/city filters + AppBar search icon | Done |
| Select Team — Teams tab location filter sheet + inline search bar | Done |
| Select Team — `TeamsListFilter` search (name, code, location, ID) | Done |
| Select Team — location filters cleared on screen open | Done |
| Select Team — block duplicate Team A/B selection with visual state | Done |
| Select Team — empty state with clear filters / search again | Done |

---

## Latest (match setup & over management)

| Item | Status |
|------|--------|
| Start Match — AppBar trailing action removed (back only) | Done |
| Configurable balls per over (1–12, default 6) — setup + match rules edit | Done |
| Live scoring — over completion prompt (End Over / Continue Over) | Done |
| Live scoring — manual End Over shortcut + required adjustment notes | Done |
| `overNotes` on match doc + undo removes linked notes | Done |
| Match insights — Over Adjustments section | Done |
| Scoring engine — `endOver` event, strike rotation on end only | Done |
| Innings — `currentOverStartLegalBalls` for accurate over display | Done |
| Sequential over tracking — `currentOverNumber` / `currentOverSegment` (fixes early-end carry-over) | Done |
| Mid-over bowler change — segment increment (5A/5B), stats per bowler | Done |
| Ball events — `overSegment`; match doc — `overMetadata` (segments + whole-over summary) | Done |
| This Over indicator — resets on new over; continued overs stay grouped | Done |
| Over lifecycle tests (`scoring_engine_over_lifecycle_test.dart`) | Done |

---

## Latest (team management + notifications)

| Item | Status |
|------|--------|
| Multi-team membership — players can join multiple teams (`teamIds` array) | Done — deploy rules |
| Join team flow — pending request, no duplicate/member/leadership requests | Done |
| Join request notifications — owner, captain, vice captain (Firestore + FCM) | Done — deploy `onNotificationCreated` function |
| Home bell — unread count badge, realtime, clears on notifications screen | Done |
| Team card dot — pending join requests for leadership roles | Done |
| Join request panel — approve/reject for owner, captain, vice captain | Done |
| Leave team — roster cleanup, memberCount, owner transfer (earliest joined) | Done |
| Owner sole member leave — deletes team, join requests, notifications | Done |
| Remove member — role-based permissions + notification to removed player | Done |
| Team roster transactions — reads before writes (leave/remove/assign) | Done |
| Firestore rules — leadership join-request + roster management | Done — deploy rules |
| Realtime member counts — `memberCount` synced on roster changes | Done |
| Teams tab location filter reset on tab enter | Done |
| Offline — Firestore persistence enabled (`firebase_bootstrap.dart`) | Done |

---

## Latest (guest mode + player onboarding)

| Item | Status |
|------|--------|
| Guest browse — app opens to Home without login | Done |
| Public Firestore read rules (matches, teams, players, …) | Done — deploy rules |
| Login gate dialog for protected actions | Done — `auth_gate.dart` |
| Resume action after login (`PendingAuthAction`) | Done |
| Google sign-in user doc bootstrap (`onboardingCompleted: false`) | Done |
| 6-step player onboarding (`/player-onboarding`) | Done |
| Player ID (`CF000001`) allocated on onboarding complete only | Done |
| Player ID local cache (SharedPreferences) for offline | Done |
| Profile tab guest sign-in prompt | Done |
| Player ID shown under name on profile | Done |
| Country picker — pinned cricket nations + alphabetical | Done |
| Onboarding location — Google Maps detect, search, edit | Done |
| Auto phone dial code from country selection | Done |
| Create team form — logo crop, searchable location, intl contact | Done |
| Team ID (`TM00001`) + invite QR saved to Firestore/Storage on create | Done |
| Storage rules — team logo/QR, player photos, size & type limits | Done — deploy storage |
| Teams tab — scope/location chips, inline search, QR share rows, pull-to-refresh | Done |
| Team detail — banner, squad cards, owner/captain controls, leave + ownership transfer | Done |
| Firestore rules — playerId immutable, own-profile edits | Done — deploy rules |

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
| Run-out last wicket — wicket recorded first; no next-batter blocker; post-wicket lineup only when innings continues | Done |
| Run-out sheet — inline validation (dismissed batter, fielder, run out type); Confirm disabled until valid | Done |
| Change Batters sheet — non-striker tap: swap, short run, crossed before wicket, umpire correction, other | Done |
| `BallEventType.batterSwap` — `swapReason`, `runsCancelled`, `swapNote`; engine apply + replay/undo | Done |
| Batter swap + last-wicket run-out tests (`scoring_engine_run_out_integrity_test.dart`) | Done |
| `OversFormatter` — single source for overs display, economy, run rate, RRR from `ballsPerOver` | Done |
| Scorecard / live score / player stats use `OversFormatter` + per-innings `effectiveRules.ballsPerOver` | Done |
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
| Change Scorer — QR / Teams / Officials / Search tabs, single active scorer | Done |
| Change Scorer QR — HTTPS + query token; open-app.html intent redirect | Done |
| CF player ID (`CF000001`) on users; search by mobile, email, or player ID | Done |
| Current scorer badge on Teams / Officials / Search tabs | Done |
| Scorer ownership — `currentScorerId`, transfer history, activity logs, Firestore rules | Done |
| Live scoring read-only mode when scorer transfers away (real-time listener) | Done |

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


