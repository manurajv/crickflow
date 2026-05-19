# CrickFlow — Full Implementation Reference

**Last updated:** Phase 3.5 (Fantasy MVP)  
**Firebase project:** `crickflow-b06bc`  
**Android package:** `com.mavixas.crickflow`  
**Hosting:** https://crickflow-b06bc.web.app  

This document describes everything implemented in the app: architecture, screens, data layer, domain logic, Cloud Functions, hosting, and what is still pending.

---

## Table of contents

1. [Tech stack](#tech-stack)
2. [Project structure](#project-structure)
3. [App routes & screens](#app-routes--screens)
4. [Firestore schema](#firestore-schema)
5. [Data models](#data-models)
6. [Repositories (all methods)](#repositories-all-methods)
7. [Services (all methods)](#services-all-methods)
8. [Domain layer (all methods)](#domain-layer-all-methods)
9. [Core utilities](#core-utilities)
10. [Riverpod providers](#riverpod-providers)
11. [Shared UI widgets](#shared-ui-widgets)
12. [Cloud Functions](#cloud-functions)
13. [Firebase Hosting & public web](#firebase-hosting--public-web)
14. [Security rules (summary)](#security-rules-summary)
15. [Deep links & App Links](#deep-links--app-links)
16. [Phase completion matrix](#phase-completion-matrix)
17. [Not implemented / deferred](#not-implemented--deferred)
18. [Scripts & CI](#scripts--ci)

---

## Tech stack

| Layer | Technology |
|-------|------------|
| Mobile | Flutter 3.10+, Dart |
| State / DI | `flutter_riverpod` |
| Navigation | `go_router` |
| Backend | Firebase Auth, Firestore, Storage, FCM |
| Serverless | Cloud Functions (Node.js 2nd gen) |
| Streaming | `rtmp_broadcaster` (RTMP publish), YouTube embed (`webview_flutter`) |
| Deep links | `app_links` |
| CI | GitHub Actions — `flutter analyze`, `flutter test` |

---

## Project structure

```
lib/
├── main.dart, app.dart
├── config/routes/app_router.dart
├── core/          # theme, constants, enums, utils, firebase bootstrap, routing
├── data/          # models, repositories, services
├── domain/        # scoring engine, fantasy points, fixtures, badges, commentary
├── features/      # UI by feature (auth, home, matches, scoring, …)
└── shared/        # providers, reusable widgets

functions/src/     # Cloud Functions
public/            # Firebase Hosting (scorecard, admin, legal, app links)
docs/              # Feature & ops documentation
scripts/           # deploy, signing, SHA, release build
```

---

## App routes & screens

Defined in `lib/config/routes/app_router.dart`.

| Route | Screen | Purpose |
|-------|--------|---------|
| `/splash` | `SplashScreen` | Auth + onboarding gate |
| `/onboarding` | `OnboardingScreen` | First-run intro |
| `/login` | `LoginScreen` | Google + phone OTP (no role picker) |
| `/home` | `HomeScreen` | Match feed, quick actions, bottom nav |
| `/match/create` | `CreateMatchScreen` | New single match (non-viewers only) |
| `/match/:id` | `MatchCenterScreen` | Hub: score, stream, highlights, fantasy |
| `/match/:id/score` | `LiveScoringScreen` | Ball-by-ball scoring |
| `/match/:id/scorecard` | `ScorecardScreen` | Innings scorecard |
| `/match/:id/highlights` | `MatchHighlightsScreen` | Highlight timeline |
| `/match/:id/stream` | `LiveStreamScreen` | RTMP + Go Live settings |
| `/match/:id/webrtc` | `WebrtcViewerScreen` | WebRTC signaling (beta) |
| `/match/:id/overlay` | `LiveOverlayScreen` | Stream graphics preview |
| `/tournaments` | `TournamentScreen` | Leagues + knockout |
| `/teams` | `TeamScreen` | Team list |
| `/teams/:id` | `TeamDetailScreen` | Squad, photos, join link |
| `/players` | `PlayerScreen` | Browse players |
| `/notifications` | `NotificationsScreen` | In-app notifications |
| `/profile` | `ProfileScreen` | Profile + Member/Viewer mode |
| `/analytics` | `AnalyticsScreen` | Stats overview |
| `/settings` | `SettingsScreen` | Privacy, account deletion |
| `/fantasy` | `FantasyScreen` | My leagues + join code |
| `/fantasy/:id` | `FantasyLeagueScreen` | Leaderboard, share code |
| `/fantasy/:id/squad` | `FantasySquadScreen` | Pick 11 + C/VC |

**Router guards**

- Unauthenticated users → `/login`
- Logged-in on `/login` → `/home`
- `UserRole.viewer` cannot open `/match/create`

---

## Firestore schema

| Collection / path | Purpose |
|-------------------|---------|
| `users/{userId}` | Profile, role, stats, badges |
| `teams/{teamId}` | Roster, logo, captain |
| `players/{playerId}` | Player profiles (`teamId`, stats) |
| `matches/{matchId}` | Match state, innings, stream metadata |
| `matches/{id}/ball_events/{eventId}` | Ball-by-ball audit |
| `matches/{id}/overlay/current` | Live overlay for stream |
| `matches/{id}/highlights/{eventId}` | Auto highlights (CF) |
| `matches/{id}/public/scorecard` | Public web scorecard (no secrets) |
| `matches/{id}/webrtc/room` | WebRTC signaling room |
| `matches/{id}/webrtc/room/candidates/{id}` | ICE candidates (rules allow create) |
| `tournaments/{tournamentId}` | Format, teams, bracket |
| `notifications/{id}` | Per-user notifications |
| `badges/{badgeId}` | Earned badges |
| `fantasy_leagues/{leagueId}` | Fantasy league metadata |
| `fantasy_leagues/{id}/entries/{entryId}` | User squads + points |

See also [FIREBASE_SCHEMA.md](FIREBASE_SCHEMA.md), [FANTASY.md](FANTASY.md).

---

## Data models

| Model | File | Key fields / notes |
|-------|------|-------------------|
| `UserModel` | `user_model.dart` | `role` (`UserRole`), location, stats |
| `TeamModel` | `team_model.dart` | `playerIds`, `createdBy` |
| `PlayerModel` | `player_model.dart` | `teamId`, `userId`, stats |
| `MatchModel` | `match_model.dart` | `innings`, `rules`, `stream` (`StreamMetadataModel`) |
| `InningsModel` | `innings_model.dart` | Batsmen/bowlers, legal balls, status |
| `BallEventModel` | `ball_event_model.dart` | `isHighlight`, `highlightTag`, commentary |
| `MatchRulesModel` | `match_rules_model.dart` | Overs, wides, free hit, etc. |
| `OverlayStateModel` | `overlay_state_model.dart` | Striker, bowler, RR, required RR |
| `TournamentModel` | `tournament_model.dart` | `format`, standings, bracket refs |
| `BracketSlotModel` | `bracket_models.dart` | Knockout tree slots |
| `NotificationModel` | `notification_model.dart` | `userId`, `read` |
| `BadgeModel` | `badge_model.dart` | Type, player, match |
| `FantasyLeagueModel` | `fantasy_league_model.dart` | `joinCode`, `status`, multipliers |
| `FantasyEntryModel` | `fantasy_entry_model.dart` | `playerIds`, captain/vice, `totalPoints` |
| `LineupPlayer` | `lineup_player.dart` | Scoring lineup picker |
| `LocationModel` | `location_model.dart` | country, city |

**Enums** (`lib/core/constants/enums.dart`): `UserRole`, `MatchStatus`, `BallEventType`, `WicketType`, `TournamentFormat`, `StreamStatus`, `StreamDestination`, `BadgeType`, etc.

---

## Repositories (all methods)

### `AuthRepository` — `lib/data/repositories/auth_repository.dart`

| Method | Description |
|--------|-------------|
| `authStateChanges` | `Stream<User?>` from Firebase Auth |
| `currentUser` | Current Firebase user |
| `getCurrentUserProfile()` | Load `UserModel` from Firestore |
| `signInWithGoogle()` | Google OAuth → ensure profile + player doc |
| `signInWithPhone(...)` | Start phone verification |
| `verifyPhoneOtp(...)` | Complete phone sign-in |
| `_ensureProfile(User)` | Create `users/{uid}` + `players/{uid}` on first login |
| `signOut()` | Auth + Google sign-out |
| `deleteAccount()` | Notifications, player, user doc, Auth user |

### `UserRepository` — `user_repository.dart`

| Method | Description |
|--------|-------------|
| `getUser(id)` | One-shot read |
| `createUser(user)` | Create doc |
| `updateUser(user)` | Update doc |
| `deleteUser(id)` | Delete doc |
| `watchUser(id)` | Real-time profile stream |

### `TeamRepository` — `team_repository.dart`

| Method | Description |
|--------|-------------|
| `createTeam(team)` | New team UUID |
| `updateTeam(team)` | Update team |
| `getTeam(id)` | One-shot read |
| `watchTeams({createdBy})` | List stream, optional filter |
| `watchTeam(id)` | Single team stream |
| `addPlayerToTeam({teamId, playerId})` | `arrayUnion` on `playerIds` |

### `PlayerRepository` — `player_repository.dart`

| Method | Description |
|--------|-------------|
| `createPlayer(player)` | New player doc |
| `updatePlayer(player)` | Update player |
| `deletePlayer(playerId)` | Delete player |
| `getPlayerByUserId(userId)` | Doc id = auth uid |
| `searchAvailablePlayers(...)` | Squad picker search (exclude team) |
| `assignPlayerToTeam({playerId, teamId})` | Link player to team |
| `ensurePlayerProfileForUser(...)` | Auto-create `players/{uid}` |
| `watchPlayersByTeam(teamId)` | Alias → `watchPlayersForTeam` |
| `watchPlayersForTeam(teamId)` | Query `teamId` + roster fallback |
| `getPlayersByTeam(teamId)` | One-shot squad |
| `getPlayersByIds(ids)` | Batch read (chunks of 10) |
| `_playersFromTeamRoster(teamId)` | Load via `teams.playerIds` |

### `MatchRepository` — `match_repository.dart`

| Method | Description |
|--------|-------------|
| `createMatch(match)` | Create match doc |
| `updateMatch(match)` | Update + public scorecard sync |
| `_syncPublicScorecard(match, overlay?)` | Client fallback for public web |
| `touchStreamHeartbeat(matchId)` | Update stream heartbeat timestamp |
| `getMatch(id)` | One-shot read |
| `watchMatch(id)` | Real-time match |
| `watchMatches({createdBy})` | Filtered list |
| `watchMatchFeed()` | All matches (live first ordering) |
| `fetchBallEvents(matchId)` | One-shot ball events |
| `lastBallSequence(matchId)` | Max sequence for next ball |
| `recordBall({match, input, sequence})` | Scoring engine + Firestore commit + highlights |
| `undoLastBall(matchId)` | Delete last event, replay innings |
| `updateLineup(...)` | Striker, non-striker, bowler on innings |
| `completeMatch(matchId)` | Set completed, winner, result text |
| `_inferWinnerTeamId(match)` | Winner from innings totals |
| `_resultText(match, winnerId)` | Human-readable result |
| `_commitMatchState(...)` | Batch match + ball_event + overlay |
| `watchOverlay(matchId)` | `overlay/current` stream |
| `watchBallEvents(matchId)` | Ordered by `sequence` |
| `getBallEvents(matchId)` | One-shot for fantasy refresh |
| `startMatch(matchId, firstInnings, {scorerId})` | Status → live |
| `addScorer(matchId, userId)` | Add to `scorerIds` |
| `endCurrentInnings(matchId)` | End innings / break |
| `startNextInnings(matchId)` | Second innings |
| `canStartNextInnings(match)` | Validation helper |

### `TournamentRepository` — `tournament_repository.dart`

| Method | Description |
|--------|-------------|
| `createTournament(tournament)` | New tournament |
| `updateTournament(tournament)` | Update |
| `getTournament(id)` | One-shot |
| `watchTournaments()` | All tournaments stream |
| `addTeamToTournament({tournamentId, teamId})` | Register team |
| `generateLeagueFixtures(...)` | Round-robin matches in Firestore |
| `generateKnockoutBracket(...)` | Bracket + round-1 matches |
| `advanceKnockoutFromMatch(match)` | Winner advances slot |
| `_maybeCreateKnockoutMatch(...)` | Create next-round match doc |

### `NotificationRepository` — `notification_repository.dart`

| Method | Description |
|--------|-------------|
| `watchForUser(userId)` | Notifications stream |
| `markRead(notificationId)` | Set `read: true` |
| `markAllRead(userId)` | Batch mark read |
| `deleteAllForUser(userId)` | Account deletion cleanup |

### `FantasyRepository` — `fantasy_repository.dart`

| Method | Description |
|--------|-------------|
| `createLeagueForMatch({match, createdBy, name?})` | New league + unique `joinCode` |
| `getLeague(leagueId)` | One-shot |
| `findLeagueByJoinCode(code)` | Query by code |
| `watchLeague(leagueId)` | Real-time league |
| `watchLeaderboard(leagueId)` | Entries ordered by `totalPoints` |
| `watchUserEntries(userId)` | Collection group across leagues |
| `watchUserEntry({leagueId, userId})` | Current user's entry |
| `getUserEntry({leagueId, userId})` | One-shot entry |
| `joinLeague({league, userId, displayName})` | Create entry doc |
| `saveSquad({league, entry, playerIds, captainId, viceCaptainId, ballEvents})` | Validate + save + score |
| `refreshLeaguePoints({league, ballEvents})` | Batch-update all entry totals |
| `setLeagueStatus({leagueId, status, requesterId})` | open / locked / closed |

---

## Services (all methods)

### `StreamService` — `lib/data/services/stream_service.dart`

| Method / getter | Description |
|-----------------|-------------|
| `isPlatformSupported` | Android/iOS only |
| `status`, `lastError`, `cameraController` | State |
| `isInitialized`, `isStreaming` | Camera state |
| `initCamera()` | Permissions + `CameraController` |
| `startStream({rtmpUrl, streamKey, bitrate})` | RTMP publish |
| `stopStream()` | Stop RTMP |
| `dispose()` | Release camera |
| `buildRtmpEndpoint(rtmpUrl, streamKey)` | Static URL builder |

### `NotificationService` — `notification_service.dart`

| Method | Description |
|--------|-------------|
| `registerDevice(userId)` | Save FCM token on user |
| `subscribeToMatch(matchId)` | Topic `match_{id}` |
| `unsubscribeFromMatch(matchId)` | Leave topic |

### `StorageService` — `storage_service.dart`

| Method | Description |
|--------|-------------|
| `pickAndUploadTeamLogo(teamId)` | Image picker → Storage |
| `uploadTeamLogo(teamId, file)` | Upload logo URL |
| `pickAndUploadPlayerPhoto(playerId)` | Image picker → Storage |
| `uploadPlayerPhoto(playerId, file)` | Upload photo URL |

### `PublicScorecardSync` — `public_scorecard_sync.dart`

| Method | Description |
|--------|-------------|
| `syncFromMatch(match, {overlay})` | Write `matches/{id}/public/scorecard` (sanitized) |

### `WebrtcSignalingService` — `webrtc_signaling_service.dart`

| Method | Description |
|--------|-------------|
| `openRoom({matchId, publisherId})` | Set room `open` |
| `closeRoom(matchId)` | Set room `closed` |
| `registerViewer(matchId)` | Increment `viewerCount` |
| `watchRoom(matchId)` | `Stream<WebrtcRoomState?>` |

**Model:** `WebrtcRoomState` — `publisherId`, `status`, `viewerCount`, `isOpen`.

### `WebrtcSignalingService` — not yet implemented

- SDP offer/answer exchange
- ICE candidate handling in app (`flutter_webrtc` not added)
- TURN/STUN production config

---

## Domain layer (all methods)

### `ScoringEngine` — `lib/domain/services/scoring_engine.dart`

| Method | Description |
|--------|-------------|
| `recordBall({match, input, sequence})` | Apply ball → `ScoringInput` (match, event, overlay) |
| `undoLastBall(match, lastEvent)` | Reverse one ball on innings |
| `replayInnings({match, baseInnings, events})` | Rebuild state from events |
| `baseInningsFrom(current)` | Empty innings template |
| `buildOverlayForMatch(match)` | Overlay from current innings |
| `_buildEvent(...)` | Build `BallEventModel` from input |
| `_applyEventToInnings(...)` | Runs, wickets, strike rotation |
| `_reverseEvent(...)` | Undo math |
| `_updateBatsman(...)` / `_updateBowler(...)` | Innings stats |
| `_buildOverlay(...)` | RR, required RR, batsman figures |
| `_inputFromEvent(e)` | Map event → `BallEventInput` |
| `_replaceInnings(match, innings)` | Update innings list |

**Types:** `BallEventInput`, `ScoringInput` (with `copyWith` on innings helper).

### `FantasyPointsService` — `fantasy_points_service.dart`

| Method | Description |
|--------|-------------|
| `rawPlayerPoints(events)` | Per-player points before multipliers |
| `totalForEntry({entry, league, events})` | Captain 2×, vice 1.5× squad total |

### `CommentaryService` — `commentary_service.dart`

| Method | Description |
|--------|-------------|
| `forBall({type, runs, wicketType})` | Template commentary string |
| `forEvent(event)` | Wrapper for `BallEventModel` |

### `FixtureGeneratorService` — `fixture_generator_service.dart`

| Method | Description |
|--------|-------------|
| `roundRobinPairings(teams)` | All team pairs |
| `buildLeagueMatches(...)` | `List<MatchModel>` for league |
| `nextPowerOfTwo(n)` | Bracket sizing |
| `knockoutRoundCount(teamCount)` | Number of KO rounds |
| `knockoutPairings(teams)` | Seeded bracket pairings |
| `buildKnockoutRoundOneMatches(...)` | First-round match models |
| `buildBracketSkeleton({teams})` | `List<List<BracketSlotModel>>` |

### `BadgeService` — `badge_service.dart`

| Method | Description |
|--------|-------------|
| `evaluateInningsBadges({matchId, innings, playerNames})` | 50/100, 3/5 wicket badges |
| `pickMatchHero(match)` | Top batter or bowler → `MatchHeroModel` |
| `_badge(...)` | Internal `BadgeModel` factory |

---

## Core utilities

| Utility | File | Functions |
|---------|------|-----------|
| `CricketMath` | `cricket_math.dart` | `strikeRate`, `economyRate`, `runRate`, `requiredRunRate`, `battingAverage`, `bowlingAverage`, `formatOvers`, `ballsFromOvers` |
| `HighlightUtils` | `highlight_utils.dart` | `isHighlight`, `classify`, `label`, `overBallLabel` |
| `YoutubeUtils` | `youtube_utils.dart` | `videoIdFromUrl`, `embedUrl`, `formatStreamOffset`, `offsetFromStreamStart` |
| `DeepLinkUtils` | `deep_link_utils.dart` | `matchPath`, `scorecardPath`, `publicLivePath`, `teamPath`, `matchUri`, `scorecardUri`, `teamUri`, `hostedUri`, `privacyPolicyUri`, `httpsScorecardUri`, `publicLiveScorecardUri`, `pathFromUri` |
| `AppDateUtils` | `date_utils.dart` | `formatMatchDate`, `formatShort`, `timeAgo` |
| `generateFantasyJoinCode` | `fantasy_join_code.dart` | 6-char alphanumeric code |
| `canManageMatch` | `match_permissions.dart` | Scorer/creator check (not viewer) |
| `canCreateMatches` | `match_permissions.dart` | Non-viewer |
| `homeRouteForRole` | `match_permissions.dart` | Always `/home` |

### `DeepLinkHandler` — `lib/core/routing/deep_link_handler.dart`

| Method | Description |
|--------|-------------|
| `takePendingPath()` | Static: path stored before login |
| `init()` | Initial link + `uriLinkStream` |
| `_navigate(uri)` | `GoRouter.go(path)` or stash for login |
| `dispose()` | Cancel subscription |

---

## Riverpod providers

Defined in `lib/shared/providers/providers.dart` unless noted.

| Provider | Type | Description |
|----------|------|-------------|
| `authRepositoryProvider` | `Provider` | |
| `userRepositoryProvider` | `Provider` | |
| `matchRepositoryProvider` | `Provider` | |
| `teamRepositoryProvider` | `Provider` | |
| `playerRepositoryProvider` | `Provider` | |
| `tournamentRepositoryProvider` | `Provider` | |
| `fantasyRepositoryProvider` | `Provider` | |
| `notificationServiceProvider` | `Provider` | |
| `notificationRepositoryProvider` | `Provider` | |
| `streamServiceProvider` | `Provider` | Auto-dispose on scope end |
| `storageServiceProvider` | `Provider` | |
| `authStateProvider` | `StreamProvider<User?>` | |
| `currentUserProfileProvider` | `FutureProvider<UserModel?>` | |
| `matchesProvider` | `StreamProvider<List<MatchModel>>` | Global feed |
| `matchProvider` | `family` | Single match |
| `ballEventsProvider` | `family` | Ball events for match |
| `webrtcSignalingProvider` | `Provider` | |
| `webrtcRoomProvider` | `family` | Signaling room state |
| `overlayProvider` | `family` | Overlay stream |
| `teamsProvider` | `StreamProvider` | Current user's teams |
| `tournamentsProvider` | `StreamProvider` | All tournaments |
| `fantasyUserEntriesProvider` | `StreamProvider` | My fantasy leagues |
| `fantasyLeagueProvider` | `family` | One league |
| `fantasyLeaderboardProvider` | `family` | Leaderboard entries |
| `fantasyMyEntryProvider` | `family` | `(leagueId, userId)` |
| `teamPlayersProvider` | `family` | `team_players_provider.dart` |
| `matchLineupSquadsProvider` | `family` | `lineup_providers.dart` — batting/bowling squads |
| `routerProvider` | `Provider<GoRouter>` | App router |

---

## Shared UI widgets

| Widget | File | Role |
|--------|------|------|
| `CfButton` | `cf_button.dart` | Primary/outlined/gold actions |
| `ScoreboardCard` | `scoreboard_card.dart` | Home match cards |
| `YoutubeEmbedCard` | `youtube_embed_card.dart` | In-app YouTube player |
| `MultiCameraWatchSection` | `multi_camera_watch_section.dart` | Camera A/B switch |
| `PlayerLineupPicker` | `player_lineup_picker.dart` | Scoring lineup |
| `TeamSelector` | `team_selector.dart` | Team pick on create match |
| `MatchRulesEditor` | `match_rules_editor.dart` | Custom rules |
| `LocationFields` / `LocationFilterBar` | location widgets | Sri Lanka defaults |
| `WicketPickerSheet` | `wicket_picker_sheet.dart` | Dismissal type UI |

---

## Cloud Functions

Entry: `functions/src/index.js`

| Export | Trigger | File | Behavior |
|--------|---------|------|----------|
| `onMatchCompleted` | `matches/{matchId}` updated | `onMatchCompleted.js` | Aggregate player/team stats; badges; match hero; `statsProcessed`; tournament standings; FCM + user notification |
| `onMatchLive` | `matches/{matchId}` updated | `onMatchLive.js` | FCM when status → `live` |
| `onBallEventCreated` | `ball_events/{eventId}` created | `onBallEventCreated.js` | Highlights doc for 4/6/wicket; FCM to match topic |
| `syncPublicScorecard` | `matches/{matchId}` written | `syncPublicScorecard.js` | Mirror sanitized doc to `public/scorecard` |
| `syncPublicOverlay` | `overlay/{docId}` written | `syncPublicScorecard.js` | Merge overlay into public scorecard |

### Internal helpers (functions)

| Module | Functions |
|--------|-----------|
| `utils/stats.js` | `applyPlayerStats`, `collectPlayerAgg`, `applyTeamResult` |
| `utils/badges.js` | `evaluateInningsBadges`, `pickMatchHero`, `makeBadge` |
| `utils/messaging.js` | `notifyMatchTopic`, `createUserNotification` |
| `utils/tournament.js` | `oversFromBalls`, `inningsForTeam`, `matchNrrDelta`, `updateTournamentStandings` |
| `syncPublicScorecard.js` | `sanitizeStream`, `sanitizeInnings`, `buildPublicPayload` |

---

## Firebase Hosting & public web

Configured in `firebase.json`.

| Path | Asset | Purpose |
|------|-------|---------|
| `/` | `public/index.html` | Marketing / landing |
| `/privacy` | `public/privacy.html` | Privacy policy |
| `/open-app` | `public/open-app.html` | Deep link fallback |
| `/live/**` | `public/scorecard/index.html` | Public live scorecard + YouTube |
| `/match/**`, `/teams/**` | `public/open-app.html` | Open in app |
| `/admin`, `/admin/**` | `public/admin/index.html` | Web admin SPA |
| `/.well-known/assetlinks.json` | Android App Links |
| `/apple-app-site-association` | iOS universal links |

**Public scorecard page** reads `matches/{id}/public/scorecard` (and overlay when present). Supports dual YouTube URLs when configured on `match.stream`.

---

## Security rules (summary)

File: `firestore.rules`

- **Users:** read all signed-in; write own doc only  
- **Teams:** read all; create any; update/delete creator  
- **Players:** read all; create/update signed-in; delete own profile  
- **Matches:** read all; create as creator; update scorers/creator; delete creator  
- **ball_events:** read all; create/delete scorers; no update  
- **overlay:** read public; write scorers  
- **highlights:** read signed-in; write false (CF only)  
- **public:** read public; write scorers  
- **webrtc:** read signed-in; room write scorer or signed-in; candidates create signed-in  
- **tournaments:** read all; write creator  
- **notifications:** read/update/delete own  
- **fantasy_leagues:** read all signed-in; create any; update/delete creator  
- **entries:** read all signed-in; create/update/delete own `userId`  

---

## Deep links & App Links

**Schemes / hosts**

- Custom: `crickflow://match/{id}`, etc.  
- HTTPS: `crickflow-b06bc.web.app` (and optional `crickflow.app`)

**Handled paths** (`DeepLinkUtils.pathFromUri`): `/match/...`, `/teams/...`, etc.

**Share URLs**

- App deep link: `DeepLinkUtils.matchUri(id)`  
- Public web: `DeepLinkUtils.publicLiveScorecardUri(id)` → `/live/{id}`

---

## Phase completion matrix

| Phase | Feature | Status |
|-------|---------|--------|
| 1 | Auth, matches, scoring, teams, players | Done |
| 1.5 | Cloud Functions, FCM, offline patterns | Done |
| 2 | Tournaments, knockout, deep links, RTMP, onboarding | Done |
| 2+ | Single login, Member/Viewer mode, account deletion | Done |
| 3.1 | Highlights, commentary, highlights screen, CF | Done |
| 3.2 | YouTube embed, public `/live/{id}` scorecard | Done |
| 3.2+ | HLS restream | Not started |
| 3.3 | WebRTC Firestore signaling + beta viewer | Done (signaling only) |
| 3.3 | `flutter_webrtc` peer media, TURN | Not started |
| 3.4 | Multi-camera YouTube URLs | Done |
| 3.5 | Fantasy leagues MVP | Done |
| 3.6 | Ball tracking / AI | Not started |
| Store | Play Store polish, release keystore QA | Deferred (docs ready) |

---

## Not implemented / deferred

- **WebRTC media:** `flutter_webrtc`, SDP/answer, ICE handling, TURN server  
- **Fantasy v2:** CF scoring on each ball; tournament-wide leagues  
- **HLS restream:** FFmpeg on Cloud Run  
- **PiP** for multi-camera in-app  
- **Ball tracking / ML** highlights (Phase 3.6)  
- **iOS RTMP / full device matrix** — verify per `DEVICE_QA.md`  

---

## Scripts & CI

| Script | Purpose |
|--------|---------|
| `scripts/deploy-firebase.ps1` | Deploy rules, functions, hosting |
| `scripts/get-android-sha.ps1` | Print signing SHA-256 |
| `scripts/update-assetlinks-sha.ps1` | Update `assetlinks.json` |
| `scripts/build-release.ps1` | Release APK/AAB |
| `scripts/create-release-keystore.ps1` | Keystore scaffold |
| `.github/workflows/flutter.yml` | CI analyze + test |

---

## Related documentation

| Doc | Topic |
|-----|--------|
| [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) | Agent handoff / checklist |
| [PHASE3_ROADMAP.md](PHASE3_ROADMAP.md) | Phase 3 order |
| [MVP_ROADMAP.md](MVP_ROADMAP.md) | Original MVP phases |
| [FANTASY.md](FANTASY.md) | Fantasy rules & deploy |
| [WEBRTC.md](WEBRTC.md) | WebRTC next steps |
| [MULTI_CAMERA.md](MULTI_CAMERA.md) | Dual camera URLs |
| [PLAY_STORE_READINESS.md](PLAY_STORE_READINESS.md) | Store launch |
| [DEVICE_QA.md](DEVICE_QA.md) | Manual QA |
| [FIREBASE_SCHEMA.md](FIREBASE_SCHEMA.md) | Collection fields |
| [ANDROID_RELEASE_SIGNING.md](ANDROID_RELEASE_SIGNING.md) | Signing |
| [AGENTS.md](../AGENTS.md) | Repo conventions for agents |

---

*Generated for CrickFlow codebase handoff. Update this file when adding repositories, routes, or Cloud Functions.*
