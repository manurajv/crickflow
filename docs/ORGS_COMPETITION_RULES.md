# Orgs: competition rules, permissions and standings

Orgs are the `series` feature (collection `series`, UI label "Organisation").
This document is the source of truth for who can create competitions in an org
and how org tables and rankings are produced.

## 1. Who can propose or start a match or tournament

Setting: **Org settings > Permissions** (`series.competitionPolicy`). Only the
org **owner** can change it (`updateSeriesCompetitionPolicy`).

### 1.1 Who may propose - matches and tournaments are separate

| Key                       | Applies to  |
|---------------------------|-------------|
| `matchProposeAccess`      | matches     |
| `tournamentProposeAccess` | tournaments |

| Value        | Who can propose (besides the owner and org admins)          |
|--------------|-------------------------------------------------------------|
| `admins`     | nobody else (team admins are blocked too)                   |
| `teamAdmins` | admins of an approved org team (default)                    |
| `everyone`   | team admins and active players of an approved org team      |

The two kinds are independent, e.g. matches `everyone` and tournaments
`admins`. Org admins (owner, `seriesAdmin`, scoped admins) can always propose.

### 1.2 Approval - start directly or wait for an org admin

Per kind and per permitted role (`teamAdmins` = admins of an org team,
`players` = other team members):

| Key                                | Meaning when `true` (default)                      |
|------------------------------------|-----------------------------------------------------|
| `matchTeamAdminsNeedApproval`      | a team admin's match request waits for an org admin |
| `matchPlayersNeedApproval`         | same for a player's match request                   |
| `tournamentTeamAdminsNeedApproval` | same for tournaments, team admins                   |
| `tournamentPlayersNeedApproval`    | same for tournaments, players                       |

`false` = the request is approved automatically and the match / tournament
starts directly (it still counts as an org match and is audited). Org admins
always start directly. The player switch only matters when that kind is open to
`everyone`; the UI hides switches for roles that cannot propose.

### 1.3 Backward compatibility (older orgs and older app builds)

- Orgs created before these settings only have `proposeAccess` /
  `membersCanRequest` and `matchRequestsNeedApproval` /
  `tournamentRequestsNeedApproval`. When the new keys are absent they are
  **derived on read** from those (`membersCanRequest: true` = `everyone`,
  otherwise `teamAdmins`; an approval flag of `false` turns approval off for
  both roles of that kind). Nothing needs migrating and behaviour does not
  change until the owner saves the new settings.
- Every save also writes the **legacy mirrors** so older app builds keep
  working: `proposeAccess` = the more permissive of the two kinds,
  `membersCanRequest` = (`proposeAccess == everyone`), and
  `matchRequestsNeedApproval` / `tournamentRequestsNeedApproval` = true if any
  role of that kind needs approval.
- A partial / legacy save (an old build sending only `proposeAccess`) is merged
  onto the stored policy, so it never wipes the per-kind, per-role or walk-in
  settings. The old single value applies to both kinds. An old build may show a
  button the server then refuses (the server is the authority and returns a
  readable message).

### 1.4 Enforcement

- Server: `proposeSeriesMatch`, `proposeSeriesTournament` /
  `startSeriesTournament` and `startSeriesMatch` call `decideAccess`
  (`functions/src/series/seriesCompetitionOps.js`) with the kind and the
  caller's role.
- Firestore rules: clients cannot create `series_competitions` documents
  directly (callables only); `competitionPolicy` is validated
  (`seriesCompetitionPolicyValid`: access values must be one of the three, all
  approval / walk-in flags booleans).
- UI: the org Matches / Tournaments tabs show "Start", "Request" or nothing per
  kind from `OrgCompetitionAccess` (`lib/domain/services/series/org_competition_access.dart`),
  with the labels "Start a match" / "Request a match" (and the same for
  tournaments).
- Both teams of an org match must be approved org teams linked to a CrickFlow
  team (see `orgTeamLink`). Quick matches are never org matches.
- Suspended / archived orgs or orgs on platform hold accept no new proposals.

## 2. Visibility

- Approved org matches / tournaments are public like any other.
- Pending proposals are visible only to org admins and the proposer, marked
  with a "Pending" badge. Rejected ones disappear from lists.
- Org matches and tournaments carry an **org badge** (org name + verified tick,
  or "Pending") on every card: My Cricket, search, org Matches / Tournaments tabs.

## 3. What counts for org standings and rankings

A match counts only if it is:
1. approved by the org (`seriesOfficialStatus == approved`),
2. not a quick match,
3. `completed` or `abandoned` (no result counts as NR),
4. between two org teams (`seriesClubAId` and `seriesClubBId` set).

Anything else (pending, rejected, scheduled, live, walk-in teams) is ignored.

## 4. Org points table

Org detail > Leaderboard > **Points table** (app and web): P, W, L, T, NR, Pts,
NRR. Points per result and NRR on/off come from the org's ranking rules
(`SeriesRankingRulesModel`). Sort: points, NRR (if enabled), wins, name. A
filter narrows the table to standalone matches or one org tournament; in
tournament mode teams that have not played yet are listed.

- App: computed on the device with the tournament engine
  (`buildOrgPointsTable` > `PointsTableEngineService`).
- Web: the same algorithm ported to TypeScript
  (`crickflow-web/lib/cricket/org-leaderboard.ts`), computed in the browser from
  the org's match documents.
- NRR follows the ICC rule used by tournaments: a side that is all out is
  charged the full quota of overs (batting and bowling), super-over innings are
  ignored, and NRR is `runsFor/oversFaced - runsAgainst/oversBowled` over the
  whole table, rounded to 3 decimals.

## 5. Org player rankings

Org detail > Leaderboard > **Player rankings** (app and web). Same stat
definitions, categories and minimums as the global Rankings screen:

- Sections: Batting (10 categories), Bowling (7), Fielding (4) - 21 in total.
  There is no all-rounder section in the app, so none here either.
- Ball-type chips (leather / tennis / indoor, only those that were played) and
  the category dropdown. Input is limited to matches that count (section 3).
- App: `PlayerRankingsRepository.rankFromMatches` replays ball events on the
  device.
- Web: batting and bowling come from the match documents exactly like the app.
  Fielding, dot balls, maidens, fastest 50 / 100 need ball-event replay, which a
  browser cannot afford, so the server stores a small **digest per finished org
  match** in `series_match_digests/{matchId}` (see 5.1).

### 5.1 Match digests (`series_match_digests`)

- Written by the Cloud Function `onOrgMatchDigest` (trigger on `matches/{id}`)
  when an approved, non-quick org match with two org teams is `completed` or
  `abandoned`; refreshed if its innings / rules / org fields change; removed if
  it stops counting. Clients cannot write it (rules: read public, write false).
- Content: per player `catches`, `runOuts`, `stumpings`, `dotBalls`, `maidens`,
  `fastestFiftyBalls`, `fastestHundredBalls`. Fielding comes from the ball
  events when the match has any, otherwise from the innings' stored fielders
  (same precedence as the app).
- Backfill: matches that finished before digests existed have none. Until then
  the web leaderboard falls back to the innings' fielders and shows no replay
  stats for them. Org admins see a **Refresh stats** button on the web
  leaderboard (callable `rebuildSeriesStandings`, org admins only, safe to
  re-run) that builds every missing digest.
- Parity is enforced by one golden file,
  `test/fixtures/org_leaderboard_golden.json`: the Dart test
  (`test/org_leaderboard_golden_test.dart`) shows the app engines produce its
  `expected` section; `functions/src/series/orgMatchDigest.test.js` shows the
  server digest equals the app's replay stats; `crickflow-web/tests/org-leaderboard.test.ts`
  shows the web port reproduces every table and all 21 categories (leather and
  tennis, all competition filters). Regenerate `expected` only for an
  intentional rule change: `UPDATE_GOLDEN=1 flutter test test/org_leaderboard_golden_test.dart`.

## 5a. Walk-in players

Setting: **Org settings > Permissions > Allow walk-in players**
(`competitionPolicy.allowWalkIns`, default `true`; orgs without the key allow
them, so nothing changes until the owner turns it off).

A **walk-in** is a player without a CrickFlow account:
- a match-only guest (`isMatchOnlyPlayer`, not registered, id `guest_...`), or
- a roster entry whose `players` document has no `userId`.

| Where                              | Walk-ins allowed | Walk-ins not allowed |
|------------------------------------|------------------|----------------------|
| Add to an org **match squad**      | yes              | blocked              |
| Add to an org **team roster**      | never            | never                |
| Org tournament matches             | yes              | blocked              |
| Org / app / web **rankings**       | listed in the match, never ranked | same |

- Org team rosters are always locked: managed by the org (rules + UI + server),
  so walk-ins can never join a roster, whatever the setting.
- When walk-ins are **not allowed**:
  - UI: the add-player sheet hides "Add match-only guest" and explains why; the
    squad and live change-squad screens refuse a guest / account-less player.
  - Server: `startSeriesMatch` and `proposeSeriesMatch` reject a squad that
    contains a walk-in (`failed-precondition`, naming the players).
  - Server: the trigger `onOrgMatchSquad` removes a walk-in added later to an
    org match, or to a match of an org tournament (the org is taken from the
    tournament when the match has no `seriesId` yet), that is not finished and records
    `orgWalkInsRemoved`. Firestore rules cannot loop over a squad list, which is
    why this part is a trigger. Players who already batted, bowled or fielded
    stay, so scoring is never corrupted.
  - Turning the setting off does **not** rewrite existing squads or finished
    matches; it only blocks new walk-ins.
- When walk-ins **are allowed** they can be in a match squad and play, but they
  are **excluded from every ranking**: only players with a `userId` are ranked
  (app `PlayerRankingsService`, web `rankOrgPlayers`). They still count in the
  team's innings totals, so the **points table** and NRR include their runs and
  wickets (the team scored them).

## 6. Naming

User-facing labels say **Teams** / **Team admins** for org members.
All org families use the same wording: tab "Teams" (associations: "Member teams"),
singular "Team", "Team admins", "Team registration".
Internal collection / field names (`series_clubs`, `clubAdmin`) are unchanged.

## 7. Known limitations

- Legacy server aggregates `series_club_rankings` / `series_player_rankings`
  (`updateSeriesRankings`) are still written but **no longer read by anything**:
  the app and the web leaderboard use sections 4 and 5. They can be removed in a
  later clean-up.
- A legacy single-value write from an older app build applies to both matches
  and tournaments (it cannot express different values).
- Web start flows (org admins only) still use the plain `proposeSeriesMatch` /
  `proposeSeriesTournament` callables; the server decides, so the new
  permissions apply, but the page does not yet hide buttons per kind.
- Digests only exist for matches finished after deploy until an org admin taps
  **Refresh stats** (section 5.1).
