# Stale unfinished matches (30-day rule)

A match that was scheduled or started but never finished stops showing in
**Live** and **Upcoming** lists 30 days after it was meant to be played.

## Rule

A match is *stale* when **all** of these hold:

1. Its status is unfinished: `draft`, `scheduled`, `tossCompleted`, `live` or
   `inningsBreak`. (App: `MatchLifecycle.effectiveStatus`, so a match whose
   final innings is done but still says `inningsBreak` counts as completed.)
2. Its anchor time is more than **30 days** ago. The anchor is the later of
   `scheduledAt` and `startedAt`; if neither is set, `createdAt`. A match with
   no dates at all is never stale.

Completed and abandoned matches are **never** stale and are never touched.
Rescheduling a match to a future date (or starting it) brings it back.

Code: `lib/domain/scoring/match_staleness.dart` (`isStaleUnfinishedMatch`,
`isListedLive`, `isListedUpcoming`) and the web copy
`crickflow-web/lib/cricket/match-staleness.ts`. Tests:
`test/match_staleness_test.dart`, `crickflow-web/tests/match-staleness.test.ts`.

## Display only — no data is changed

Nothing is written, deleted or marked abandoned. The match document, its
tournament fixture slot, rounds, groups, brackets, points table, NRR, org
leaderboard and player stats stay exactly as they were. This is deliberate:
auto-abandoning would hand out no-result points and could change standings
and knockout progress.

## Where it applies

| Surface | Effect |
| --- | --- |
| Home live / upcoming discovery (`fetchLiveAndUpcomingMatches`, nearby matches) | stale matches dropped; feed no longer floats them to the top as live |
| My Cricket → Scoring view | stale matches not offered to resume (still in the Matches list) |
| Tournament Live / Upcoming filters (`tournamentMatchesFilteredProvider`) | dropped; Completed filter unchanged |
| Tournament dashboard summary counts | stale matches not counted as live or upcoming |
| Org Matches tab (sections and chip counts) | dropped from Live / Upcoming / All |
| Match cards (any list, search results) | badge reads **Expired**, no live highlight |
| Web: home Upcoming, /matches Live and Upcoming | dropped; cards show **Expired** |

Not changed on purpose: the full tournament fixtures / bracket view, standings,
"is the tournament ready to complete" (a stale fixture still has to be finished
or abandoned by the organiser), match detail pages and scoring screens (the
scorer can still open, finish or abandon the match).
