# Permanent delete (admin panel) and all-or-nothing creates

## Why a normal user could not create a team (t43, 2026-11-09)
`playerRosterTargetUnlocked()` in `firestore.rules` refused any player write that
moved the legacy `players.teamId` pointer **away from an org-locked team**.
Anyone already playing for an org team (org owners/admins, super admin's
profile, any org member) has `teamId` = that org team, so the
"add me to my new team" write was denied. The app wrote the team doc first and
the roster afterwards, so the team doc was left behind with an empty roster.

Fix: membership is checked on `teamIds` (an org team can't be added or removed
by a client), while the primary `teamId` pointer may move between teams the
player already belongs to. Org / staff roles only ever ADD permissions.

## Atomic create
- App: `TeamRepository.createTeamAtomic` (logo upload -> one batch with team doc
  + creator membership; failure deletes the upload). Helper:
  `lib/core/utils/atomic_create.dart` (`runAtomicCreate`).
- Tournaments: images uploaded first, one tournament write, uploads deleted on
  failure; follow-up community posts are optional.
- Orgs: created server-side by `createSeries`; logo/cover uploads are deleted
  if attaching them fails.
- Web: `crickflow-web/features/teams/create-team-form.tsx` uses the same pattern.
- `storage.rules` lets a user delete their own just-uploaded team / tournament /
  org image (needed for the cleanup).

## Admin panel: Delete permanently
Callable `adminDeleteEntity({ type: team|tournament|series|match, id, reason })`
(`functions/src/admin/adminDeleteEntity.js`), staff with the matching
permission only (Super Admin always). Each run writes `admin_audit_logs`.

| Type | Deleted | Kept / updated | Notified (Priority + push) |
|---|---|---|---|
| team | team doc + join_requests/profileViews, followers, roster reports, tournament team requests, notification prefs, `teams/{id}/` files | players stay; team removed from `teamIds`/`teamId`; removed from tournaments' `teamIds`; org club `linkedTeamId` cleared | owner, captain, vice-captain |
| tournament | doc + groups, rounds, points tables, officials, sponsors, members, team requests, rules, analytics, its community posts, unplayed fixtures, `tournaments/{id}/` files | started/completed matches kept, `tournamentId` -> `removedTournamentId` | organizer, owner/admin members |
| series (org) | doc + subcollections, all `series_*` docs, its tournaments (as above), unplayed org matches, `series/{id}/` files | org teams unlocked (become normal teams); played matches kept, `seriesId` -> `removedSeriesId` | owner, active org admins, org team owners |
| match | doc + ball_events/overlay/..., digest, media; removed from tournament `matchIds` | career stats already counted from a completed match are not reversed | match creator |

Career stats: matches that were played are never deleted as a side effect, so
players' career totals (incremented when a match completes) stay consistent.

The app/web show "This team/tournament/organization/match was removed" when a
deleted doc is opened.
