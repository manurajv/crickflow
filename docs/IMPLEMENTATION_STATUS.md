# CrickFlow — Implementation Status (Agent Handoff)




**Last updated:** Upcoming match details (pre-match hub)  

**Firebase project:** `crickflow-b06bc`  

**Android package:** `com.mavixas.crickflow`

> **Master doc:** [PRODUCT_ARCHITECTURE.md](PRODUCT_ARCHITECTURE.md) · **Scoring engine:** [SCORING_ENGINE_ARCHITECTURE.md](SCORING_ENGINE_ARCHITECTURE.md) · **Ball events:** [BALL_EVENT_ARCHITECTURE.md](BALL_EVENT_ARCHITECTURE.md) · **Doc index:** [README.md](README.md)

---

---

## Latest (My Cricket Profile module)

| Item | Status |
|------|--------|
| My Cricket Profile screen — `/my-cricket-profile` + `/player/:id/cricket` | Done |
| Profile header — photo, name, CF ID, location, role, styles, cluster tags | Done |
| Social counters — followers, following, profile views (reused) | Done |
| Actions — Share, QR, Follow, Edit Profile (own) | Done |
| Tabs — Matches, Stats, Trophies, Badges, Teams, Connections (no Highlights/Photos) | Done |
| Matches tab — Upcoming/Live/Completed + filters (overs, ball, type, year, team) | Done |
| Stats tab — Batting, Bowling, Fielding (reused) + Captain section | Done |
| Captain stats — wins, toss %, chases, timeline, by year/format | Done |
| Player clusters — batting (SR/pattern) + bowling (economy/wickets) from match data | Done |
| Trophies — 5 MVP award types (POTM, Fighter, Best Batter/Bowler/Fielder); tap for career list | Done |
| Badges — repeatable (unlockCount, history) vs one-time (unlocked date only); highest-eligible-only match progression | Done |
| Teams tab — per-team stats, sort recent/matches/performance | Done |
| Connections tab — following, followers, mutuals, search, Find Cricketers link | Done |
| Cached Riverpod providers — `myCricketProfileProvider`, `playerCricketProfileByIdProvider` | Done |
| Profile tab + public profile — Open Cricket Profile CTA | Done |
| Light + dark theme via `context.cf` cards | Done |

---

## Latest (Profile social system — player discovery)

| Item | Status |
|------|--------|
| Profile tab redesign — social header (photo, name, CF ID, location, joined, role/styles) | Done |
| Removed stats overview from profile (runs, wickets, charts → My Cricket Profile later) | Done |
| Own profile actions — Edit, Share, QR, Settings | Done |
| Other profile actions — Follow, Share, Message/Report placeholders | Done |
| `playerFollows/` follow + unfollow with realtime counts | Done |
| Follow button states — primary Follow / outlined Following + confirm unfollow | Done |
| Followers / Following / Profile Views counters (realtime via `users/{uid}/social/stats`) | Done |
| Profile view tracking — skip self, 1 view per viewer per 24h | Done |
| Profile details cards — gender, DOB, role, styles, country, city; email/phone owner-only | Done |
| Connections section — followers/following preview, suggested, Find Cricketers | Done |
| Find Cricketers screen — search by name/CF ID, filter chips, player cards | Done |
| Filters — All, Popular, Followers, Following, Teammates, Nearby, Recently Joined, Suggested | Done |
| From Contacts / Mutual Connections — future-ready (hidden / empty) | Done |
| Public profiles `/player/:playerId` (CF ID, not Firebase uid) | Done |
| Followers / Following screens with search + realtime lists | Done |
| Profile QR (`/player/:id/qr`) encodes CF player ID | Done |
| Share profile — `crickflow://player/CF…` + hosted `/player/CF…` | Done |
| Follow + milestone notifications (`player_follow`, `follower_milestone`) | Done — deploy functions |
| Firestore rules + indexes for `playerFollows`, profile views, social stats | Done — deploy rules |
| Cloud Functions — mirror follow/view counts to user doc | Done — deploy functions |
| Light + dark theme via `context.cf` cards and accents | Done |

---

## Latest (Edit Profile screen)

| Item | Status |
|------|--------|
| Dedicated `/profile/edit` screen — separate from onboarding | Done |
| Edit Profile button opens edit screen (not onboarding) | Done |
| Preloads Firestore user + player doc fields | Done |
| Photo change / crop / compress / remove + Storage upload | Done |
| Name validation (3–50 chars), read-only Player ID | Done |
| Location via `OnboardingLocationSection` + district field | Done |
| Cricket fields — role, batting/bowling styles, dominant hand | Done |
| Personal — gender, DOB, bio (250 max) | Done |
| Private — email, phone (owner only) | Done |
| Sticky Save Changes + loading / double-submit guard | Done |
| Unsaved changes dialog — Cancel / Discard / Save | Done |
| Offline queue (`ProfileUpdateQueueService`) + sync on reconnect | Done |
| `ProfileEditRepository` — Firestore, player doc sync, cache refresh | Done |
| Profile invalidates immediately after save | Done |

---

## Latest (Upcoming match details — pre-match hub)

| Item | Status |
|------|--------|
| **Upcoming-only tabs** — `draft` / `scheduled` / `tossCompleted`: Match Info + Squads only; Live, Summary, Scorecard, Insights, Comms, MVP, Highlights hidden | Done |
| Default tab **Match Info**; deep links to hidden tabs fall back to Info | Done |
| `UpcomingMatchInfoTab` — hero preview card (teams, format, venue, date/time, status badge) | Done |
| Live countdown (informational only); past scheduled time → “waiting for scorer to start” | Done |
| Match start remains scorer-controlled (`Start Match` in scoring flow) — countdown/time never auto-live | Done |
| Head-to-head from completed matches between team pair; empty → “No previous meetings” | Done |
| **View more insights** → `/match/:id/head-to-head` (`TeamHeadToHeadScreen`) | Done |
| Match information + officials (reuses Info tab sections) | Done |
| Milestones to unlock — squad career stats via `UpcomingMilestonesService` | Done |
| Match banners (generated placeholders) + Generate Banner CTA when empty | Done |
| Quick actions — share, follow (`MatchFollowButton`), teams, tournament, venue, Google Calendar | Done |
| Squads tab — existing `MatchSquadsTab` + match setup snapshot (unchanged layout) | Done |
| `MatchUpcomingService` + `matchUpcomingProvider`; hub prefetches provider for upcoming matches | Done |
| `test/match_live_service_test.dart` — upcoming tab config (2 tabs only) | Done |
| Scorer **Live Score** on upcoming → match setup wizard (Setup step or resume squads/roles/officials/toss); never auto-`startMatch()` | Done |
| `StartMatchDraftNotifier.loadFromMatch` + `match_setup_navigation.dart` — hydrate draft, persist progress to Firestore | Done |
| Officials from Setup step save on Done/back; scorer can leave and resume setup later | Done |
| Setup wizard step bar — tap completed steps to jump back (Teams → Setup → Squads → …) | Done |
| Upcoming Squads tab — full team roster when playing XI not selected yet (same layout as live) | Done |

---

## Latest (Live tab — real-time match experience)

| Item | Status |
|------|--------|
| **Dynamic hub tabs** — Live while `live`/`inningsBreak`; Summary when `completed`/`abandoned`; neither pre-match | Done |
| Tab order (live): Info, Live, Scorecard, Insights, Comms, Squads, MVP, Highlights | Done |
| Tab order (completed): Info, Summary, Scorecard, Insights, Comms, Squads, MVP, Highlights | Done |
| Last hub tab **Highlights** (`?tab=highlights`, alias `?tab=gallery`) | Done |
| Auto-switch Live → Summary when match completes | Done |
| `MatchLiveService` + `matchLiveProvider` — score, CRR/RRR, chase, DLS, partnership, projections | Done |
| Live tab — score header, batters/bowlers stats tables, target revision, milestones, last-over commentary | Done |
| Live viewers row — total views + live viewer count under CRR/RRR | Done |
| `MatchAudienceRepository` — `engagement/stats.totalViews`, `liveAudience/{uid}` heartbeat | Done |
| Firestore rules for `engagement/*` + `liveAudience/*` (deployed) | Done |
| Embedded commentary — over summary + ball-by-ball (reuses Comms widgets) | Done |
| Powerplay / death-over phase label from `MatchPhaseService` + custom slots | Done |
| Target revision panel (DLS, penalties, revised target) | Done |
| `test/match_live_service_test.dart` — tab visibility + chase snapshot | Done |

---

## Latest (Match Info tab — metadata & administration)

| Item | Status |
|------|--------|
| **Info tab first** — live order: Info, Live, Scorecard, Insights, Comms, Squads, MVP, Highlights; completed: Summary replaces Live | Done |
| `MatchInfoService` + `matchInfoProvider` — snapshot from match doc, revisions, timeline | Done |
| Match Overview — tournament, round, format, venue, toss, result, match ID | Done |
| Match Configuration — overs, balls/over, players, powerplay, DLS, custom rules | Done |
| Teams — captain, vice captain, wicketkeeper from `MatchSetupData` snapshot | Done |
| Match Officials — scorers, umpires, commentators, streamers, referee | Done |
| Match Notes — chronological timeline (milestones, breaks, DLS, result) | Done |
| Match Events — admin log (scorer changes, revisions, penalties, abandoned) | Done |
| DLS / target revision + penalty runs + abandoned match sections | Done |
| Match Conditions — ground, pitch, day/night, ball type (when available) | Done |
| Quick Links — squads, points table, leaderboard, tournament, teams, venue | Done |
| `watchMatchTimeline` stream + light/dark themed cards | Done |
| `publicMatchId` — 8-digit id assigned at match start (Info tab, not Firestore id) | Done |
| Info venue tap → Google Maps directions from current location | Done |
| Info tab — teams section removed; venue removed from quick links | Done |

---

## Latest (Match Summary tab — broadcast-style redesign)

| Item | Status |
|------|--------|
| `MatchSummaryService` — aggregates match, analytics, MVP, ball events into cached snapshot | Done |
| `matchSummaryProvider` — Riverpod cache (reuses `matchAnalyticsProvider` + `matchMvpProvider`) | Done |
| Match Result card — scores, result line, format, venue, date, duration, toss, POTM | Done |
| AI Performance Insights — personalized viewer copy, helpful/not helpful, read more | Done |
| Heroes — horizontal scroll: POTM, Fighter, Best Batter/Bowler/Fielder with MVP scores | Done |
| Star Performers — responsive grid (batters, bowlers, fielders, all-rounders) | Done |
| Best Partnership card — highest stand, contribution progress bar | Done |
| Team Comparison — side-by-side runs, wickets, boundaries, dots, extras, SR/RR | Done |
| Match Timeline — powerplay, milestones, wickets, innings break, DLS, penalties | Done |
| Match Awards & Badges — auto-generated from stats (century, 3/5 wkts, six hitter, etc.) | Done |
| Quick Actions — follow, share, scorecard, insights, comms, MVP tab navigation | Done |
| Light/dark theme cards; DLS/revisions/manage actions preserved | Done |
| Unit tests — `test/match_summary_service_test.dart` | Done |

---

## Latest (MVP tab — format-aware scoring & redesigned UI)

| Item | Status |
|------|--------|
| `MatchMvpService` — bat/bowl/field breakdown, par score, SR/economy weighting by format | Done |
| Clutch & partnership bonuses, wicket value by batting order, death-over impact | Done |
| Player Of The Match (#1) & Fighter Of The Match (CricHeroes rules) | Done |
| `matchMvpProvider` — cached Riverpod board (no per-rebuild recalculation) | Done |
| MVP tab — podium (top 3), ranked list, expandable breakdown, award banners | Done |
| Filters — All, Batters, Bowlers, Fielders, Team A/B, POTM, FOTM | Done |
| How MVP is Calculated? explanation screen (`/match/:id/mvp/how`) | Done |
| Custom overs, balls per over, Test/ODI/T20/T10 support — no hardcoded 20-over assumptions | Done |
| Light theme cards, blue accents, no yellow text | Done |
| Unit tests — `test/match_mvp_service_test.dart` | Done |

---

## Latest (Insights tab — professional match analytics)

| Item | Status |
|------|--------|
| `MatchAnalyticsService` — cached read-only aggregation from ball events | Done |
| Match Summary dashboard — top batter, best bowler, partnerships, boundary/dot %, extras, over extremes | Done |
| `MatchPhaseService` — dynamic powerplay (30%), death (25%), last-N overs, custom slot support | Done |
| Phase analysis — dynamic labels with over ranges, enriched metrics (RR, boundaries, dot %, SR) | Done |
| Test match insights — session, new ball, batting control, bowling pressure; T20 phases hidden | Done |
| Wagon wheel — existing chart preserved; collapsible wrapper + legend | Done |
| Scoring areas — leg/off/straight pie from handedness-adjusted wagon wheel data | Done |
| Partnership analysis — horizontal bars, highest highlighted | Done |
| Partnership analysis — reference-style comparison cards, innings selector, contribution bars | Done |
| Phase analysis — powerplay/middle/death (limited overs only) | Done |
| Boundary, bowling impact, extras, dot ball sections | Done |
| DLS + penalty run badges in match summary | Done |
| Test match support — hides phase analysis & RRR | Done |
| Custom `ballsPerOver` respected in all charts | Done |
| Collapsible sections with lazy chart loading | Done |
| Light theme — white cards, blue accent, no yellow text | Done |
| Unit tests — `test/match_analytics_service_test.dart` | Done |

---

## Latest (match card & Matches tab redesign)

| Item | Status |
|------|--------|
| Unified `MatchListCard` — CricHeroes-style white cards (16px radius, subtle shadow) | Done |
| `MatchCardContent` — type header, date \| overs \| venue, vertical team rows, right-aligned scores | Done |
| Status pills — Upcoming orange, LIVE red (+ pulse dot), Result grey, break/rain blue | Done |
| State-specific actions — Squads/Details, Live Score/Scorecard/Insights, Scorecard/Insights/Leaderboard | Done |
| Team avatars on cards (`MatchTeamAvatar` — logo or initials) | Done |
| Matches tab — Start banner, Your/Played/Network/All chips, empty state | Done |
| Home, Discover, Highlights use same `MatchListCard` | Done |

---

## Latest (light theme refinement)

| Item | Status |
|------|--------|
| Professional light palette — #111111 text, #F6F7F9 bg, white cards | Done |
| Semantic tokens — accent, scoreEmphasis, link, statusLive/Upcoming/Completed | Done |
| No yellow text in light mode — gold reserved for dark broadcast UI | Done |
| Match cards — white cards, status chips (LIVE red, Upcoming orange, Result grey) | Done |
| Stat grid — dashboard-style white cards with shadows | Done |
| App bar / nav — white chrome, blue selected nav in light mode | Done |
| Buttons — primary blue, secondary white/grey border, danger red | Done |
| Banners / team / scoring sheets migrated to `context.cf` | Done |
| `cfCardDecoration()` shared card helper | Done |
| Start Match wizard — step chips (Teams → Setup → Squads → Roles → Officials → Toss) | Done |
| Live scoring — all sheets/dialogs use `ScoringUiKit` white surfaces | Done |

---

## Latest (light / dark theme)

| Item | Status |
|------|--------|
| Light theme (`AppTheme.lightTheme`) — outdoor-friendly palette | Done |
| Dark theme retained (`AppTheme.darkTheme`) | Done |
| Default theme = Light (`ThemeMode.light`) | Done |
| Theme persistence via SharedPreferences (`theme_mode`) | Done |
| Cold start — preference loaded before `runApp` (no flicker) | Done |
| `ThemeService` + `themeModeProvider` (Riverpod) | Done |
| `CfColors` theme extension + `context.cf` helper | Done |
| Settings → Appearance (Light / Dark segmented control) | Done |
| `ThemeMode.system` storage ready (UI not exposed yet) | Done |
| Scoring presentation sheets/dialogs + start-match flow screens migrated to `context.cf` | Done |
| Start Match — `StartMatchCard`, step progress bar, white setup cards | Done |
| Live scoring header — light: white card + dark score text (outdoor readability) | Done |
| Batter strip — ON STRIKE badge, accent border, white surfaces | Done |
| Remaining screens — post-match hub tabs, scorecard view, highlights still use legacy `AppColors` | Partial |

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
| Offline — local-first scoring + Firestore persistence | Done |

---

## Latest (offline-first match scoring)

| Item | Status |
|------|--------|
| Hive local store — match snapshots, ball events, overlay (`MatchLocalStore`) | Done |
| Offline sync queue — ball commits, undo, match updates, Firestore batches | Done |
| `OfflineSyncService` — connectivity-aware sequential flush | Done |
| `MatchRepository` — local-first writes; hybrid match/event/overlay streams | Done |
| `MatchTargetRevisionRepository` — DLS, target revision, end innings, match result offline | Done |
| Match snapshot on start + first score (`ensureLocalSnapshot`) | Done |
| Live scoring badge — ONLINE / OFFLINE / SYNCING + pending count | Done |
| Settings offline sync info updated | Done |
| Firestore persistence retained as secondary cache (`firebase_bootstrap.dart`) | Done |

---

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
| Match hub tabs (dynamic Live/Summary · Scorecard · Insights · Comms · Squads · MVP · Highlights) | Done |
| Match Summary tab (result card, AI insight, heroes, stars, awards, partnership, comparison, timeline) | Done |
| Comms tab — commentary center (filters, over summaries, milestones, match events) | Done |
| Comms tab — CricHeroes-style UI (5 filters, compact timeline, no raw debug text) | Done |
| Comms tab — live-scoring ball bubbles, boundary descriptions in Full, overs layout | Done |
| Comms tab — themed over highlights, powerplays in Full, powerplay cards with icons | Done |
| Match insights (hero, top bat/bowl, milestones) | Done (client-side) |
| Match MVP tab (format-aware bat/bowl/field scoring, POTM, Fighter, filters) | Done |
| Match squads — side-by-side playing XI + substitutes from match setup snapshots, C/VC/WK badges | Done |
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


