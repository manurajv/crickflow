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
| rules | map | Full customizable rules |
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
