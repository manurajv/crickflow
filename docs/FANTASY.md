# Fantasy cricket (MVP)

Phase **3.5** — pick squads from match rosters and earn points from live ball events.

## Firestore

- `fantasy_leagues/{leagueId}` — name, `joinCode`, `matchId`, `status` (`open` | `locked` | `closed`), multipliers
- `fantasy_leagues/{leagueId}/entries/{entryId}` — `userId`, `playerIds`, captain / vice, `totalPoints`

## Auto-scoring

Cloud Function `onBallEventCreated` recalculates all entry `totalPoints` for leagues tied to the match after each ball (see `functions/src/fantasy/`).

## Points (MVP)

| Event | Points |
|-------|--------|
| Run (batsman) | 1 per run |
| Four | +1 bonus |
| Six | +2 bonus |
| Wicket (bowler) | 25 |
| Catch / fielder on wicket | 8 |
| Captain | 2× that player’s points |
| Vice-captain | 1.5× |

Points refresh when the league screen is open (ball events stream) and when saving a squad.

## App flows

1. **Match Center → Fantasy → Create league** — share the 6-character join code.
2. **Home → Fantasy Cricket** — join with code or open existing leagues.
3. **Build squad** — 11 players from both teams; pick captain (C) and vice (VC).

## Deploy

After pulling these changes:

```powershell
firebase deploy --only firestore:rules,firestore:indexes
```

## Later

- Tournament-wide leagues (aggregate multiple matches)
- Cloud Function to update points on each ball (no client refresh)
- Draft / transfer windows, private leagues, prizes
