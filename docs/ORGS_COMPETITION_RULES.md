# Orgs: competition rules, permissions and standings

Orgs are the `series` feature (collection `series`, UI label "Organisation").
This document is the source of truth for who can create competitions in an org
and how org tables and rankings are produced.

## 1. Who can propose a match or tournament

Setting: **Org settings > Permissions** (`series.competitionPolicy.proposeAccess`).

| Value        | Who can propose                                            |
|--------------|------------------------------------------------------------|
| `admins`     | Org owner and org admins only (team admins are blocked too) |
| `teamAdmins` | Org admins + admins of the org's teams (default)            |
| `everyone`   | Org admins + any member of an org team                      |

Backward compatibility: orgs created before this setting only have
`membersCanRequest`. `true` is treated as `everyone`, `false` as `teamAdmins`.
Every save writes both fields so older app builds keep working.

Related policy switches (same screen):
- `requireApprovalForMatches` / `requireApprovalForTournaments` - when on, a
  proposal from a non-admin waits for org-admin approval (`pendingApproval`);
  when off it is approved automatically.

Rules:
- Org admins (owner, `seriesAdmin`, scoped admins) can always propose and approve.
- Only the **org owner** can change the policy (`updateSeriesCompetitionPolicy`).
- Enforced server-side in `proposeSeriesMatch`, `proposeSeriesTournament` and
  `startSeriesMatch` via `decideAccess` (`functions/src/series/seriesCompetitionOps.js`).
- Firestore rules: clients can no longer create `series_competitions`
  documents directly (callables only), and `competitionPolicy` is validated
  (`proposeAccess` must be one of the three values).
- The UI hides "Propose" / "Start match" buttons the user cannot use and shows
  a short reason instead.
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

Org detail > Leaderboard > **Points table**. Computed on the client with the
same engine as tournament points tables (`PointsTableEngineService`):
P, W, L, T, NR, Pts, NRR. Points per result and NRR on/off come from the org's
ranking rules (`SeriesRankingRulesModel`). Sort: points, NRR (if enabled),
wins, name. A filter narrows the table to standalone matches or one org
tournament; in tournament mode teams that have not played yet are listed.

## 5. Org player rankings

Org detail > Leaderboard > **Player rankings**. Uses the app's own
`PlayerRankingsRepository.rankFromMatches`, so definitions match the global
Rankings screen exactly:
- Sections: Batting (10 categories), Bowling (7), Fielding (4).
  There is no all-rounder section in the app, so none here either.
- Ball-type chips (all / leather / tennis...) and the same category dropdown.
- Input is limited to matches that count (section 3). Players are read from
  `players` docs, so walk-in players without an account/profile are excluded.

## 6. Naming

User-facing labels say **Teams** / **Team admins** for org members.
All org families use the same wording: tab "Teams" (associations: "Member teams"),
singular "Team", "Team admins", "Team registration".
Internal collection / field names (`series_clubs`, `clubAdmin`) are unchanged.

## 7. Known limitations

- Server aggregates `series_club_rankings` / `series_player_rankings`
  (`updateSeriesRankings`) are no longer used by the mobile UI (NRR and
  fielding were incomplete); the web leaderboard still reads them.
- A single `proposeAccess` setting applies to both matches and tournaments.
