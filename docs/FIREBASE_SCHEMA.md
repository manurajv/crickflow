# Firebase / Firestore Schema

## Collections

### `users/{userId}`
| Field | Type | Notes |
|-------|------|-------|
| email | string | |
| displayName | string | |
| phoneNumber | string? | |
| photoUrl | string? | |
| role | string | player, scorer, umpire, organizer, viewer |
| location | map | country, stateProvince, city |
| stats | map | matchesPlayed, matchesScored, tournamentsOrganized |
| badgeIds | array | |
| achievementIds | array | |
| createdAt | string | ISO8601 |
| updatedAt | string | |

### `teams/{teamId}`
| Field | Type |
|-------|------|
| name | string |
| logoUrl | string? |
| captainId | string? |
| viceCaptainId | string? |
| coachName | string? |
| playerIds | array |
| location | map |
| stats | map |
| badgeIds | array |
| createdBy | string |

### `players/{playerId}`
| Field | Type |
|-------|------|
| name | string |
| teamId | string? |
| jerseyNumber | number? |
| battingStyle | string |
| bowlingStyle | string |
| photoUrl | string? |
| role | string |
| location | map |
| stats | map |
| badgeIds | array |

### `matches/{matchId}`
| Field | Type |
|-------|------|
| title | string |
| matchType | single \| tournament |
| status | string |
| teamAId, teamBId | string? |
| teamAName, teamBName | string |
| tournamentId | string? |
| rules | map | See **Match rules** below |
| mediaByCode | map? | CM1, CM2… media URLs |
| scheduledAt | string? | ISO8601 |
| createdBy | string | Creator uid |
| scorerIds | array | Uids allowed to score |

#### Match rules (`rules` map)
| Field | Type | Notes |
|-------|------|-------|
| cricketMatchType | string | `limitedOvers`, `indoor`, `testMatch` (legacy: `boxTurf` → indoor) |
| format | string | `standard`, `tennis`, `custom` |
| ballType | string | `leather`, `tennis`, `indoor` |
| totalOvers | number | |
| ballsPerOver | number | |
| oversPerBowler | number | |
| isManualOversPerBowler | boolean | `false` when auto-calculated (`ceil(totalOvers / 5)`) |
| wideRuns, noBallRuns | number | |
| wideCountsAsLegalDelivery | boolean | |
| noBallCountsAsLegalDelivery | boolean | |
| freeHitEnabled | boolean | |
| maxInnings, maxWickets | number | |
| powerplaySlot1 | array | Over numbers for powerplay 1 |
| powerplaySlot2 | array | Over numbers for powerplay 2 |
| powerplaySlot3 | array | Over numbers for powerplay 3 |
| wagonWheelEnabled | boolean | Default `false` — master ON/OFF for shot capture |
| wagonWheelDots | boolean | Legacy; synced with `wagonWheelEnabled` |
| wagonWheelRuns123 | boolean | Legacy; synced with `wagonWheelEnabled` |
| wagonWheelShotSelection | boolean | Legacy; off when `indoor` |
| impactPlayerEnabled | boolean | |
| pitchType | string? | `rough`, `cement`, `turf`, `astroturf`, `matting` |
| matchOfficials | array | `umpires`, `scorers`, `liveStreamer`, `others` |
| innings | array | Embedded innings snapshots |
| currentInningsIndex | number |
| location | map |
| venue | string |
| stream | map | RTMP metadata |
| overlayVersion | number |
| matchHero | map? |
| playerOfMatchId | string? |
| badgeIds | array |
| winnerTeamId | string? |
| resultSummary | string |

#### Subcollection: `matches/{matchId}/ball_events/{eventId}`
Ball-by-ball audit trail with sequence ordering.

| Field | Type | Notes |
|-------|------|-------|
| sequence | number | Monotonic per match |
| eventType | string | `runs`, `wide`, `noBall`, … |
| runs, batsmanRuns, extraRuns | number | |
| strikerId, bowlerId | string? | |
| wagonWheel | map? | `{ enabled, x, y, shotType?, source?, confidence? }` — x/y are **percentages** 0–100 |

#### Subcollection: `matches/{matchId}/overlay/current`
Real-time overlay payload for stream graphics.

### `tournaments/{tournamentId}`
| Field | Type |
|-------|------|
| name | string |
| format | league \| knockout \| leagueKnockout |
| status | string |
| teamIds | array |
| matchIds | array |
| pointsTable | array |
| location | map |
| bannerUrl | string? |

### `badges/{badgeId}`
| Field | Type |
|-------|------|
| title | string |
| type | batting, bowling, fielding, milestone, team, matchHero |
| playerId / teamId / matchId | string? |
| earnedAt | string |

### `fantasy_leagues/{leagueId}`
| Field | Type |
|-------|------|
| name | string |
| joinCode | string (6 chars, unique) |
| matchId | string |
| matchTitle | string |
| createdBy | string |
| status | open \| locked \| closed |
| squadSize | number (default 11) |
| captainMultiplier | number |
| viceCaptainMultiplier | number |

#### Subcollection: `fantasy_leagues/{leagueId}/entries/{entryId}`
| Field | Type |
|-------|------|
| userId | string |
| displayName | string |
| playerIds | array |
| captainId | string? |
| viceCaptainId | string? |
| totalPoints | number |

### `community_posts/{postId}`
| Field | Type |
|-------|------|
| authorId | string |
| authorName | string |
| authorRole | string? |
| category | string |
| title | string |
| body | string |
| location | map |
| createdAt | string |
| updatedAt | string |

### `notifications/{notificationId}`
| Field | Type |
|-------|------|
| userId | string |
| title | string |
| body | string |
| matchId | string? |
| read | boolean |

## Indexes (recommended)

```
matches: createdBy ASC, createdAt DESC
matches: status ASC, createdAt DESC
players: teamId ASC
ball_events: sequence ASC (collection group if needed)
```

## Cloud Functions (Phase 1.5)

- `onMatchCompleted` — aggregate player/team stats
- `onBallEvent` — optional badge triggers
- `sendMatchNotification` — FCM to followers
