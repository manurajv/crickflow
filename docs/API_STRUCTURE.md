# REST API Structure (Express.js)

Base URL: `https://api.crickflow.app/v1` (configure per environment)

## Authentication

All protected routes require:
```
Authorization: Bearer <Firebase ID Token>
```

## Endpoints

### Auth & Users
| Method | Path | Description |
|--------|------|-------------|
| GET | `/users/me` | Current user profile |
| PATCH | `/users/me` | Update profile & location |
| GET | `/users/:id` | Public profile |

### Teams
| Method | Path | Role |
|--------|------|------|
| GET | `/teams` | List (location filters: `?country=&city=`) |
| POST | `/teams` | organizer+ |
| GET | `/teams/:id` | Detail |
| PATCH | `/teams/:id` | organizer+ |
| POST | `/teams/:id/players` | Add player |

### Matches
| Method | Path | Role |
|--------|------|------|
| GET | `/matches` | List with filters |
| POST | `/matches` | organizer, scorer |
| GET | `/matches/:id` | Detail + innings |
| PATCH | `/matches/:id` | scorer+ |
| POST | `/matches/:id/balls` | Record ball (idempotent via `clientEventId`) |
| DELETE | `/matches/:id/balls/last` | Undo last ball |
| GET | `/matches/:id/overlay` | Overlay state |

### Tournaments
| Method | Path | Role |
|--------|------|------|
| GET | `/tournaments` | List |
| POST | `/tournaments` | organizer |
| POST | `/tournaments/:id/teams` | Register team |
| POST | `/tournaments/:id/fixtures` | Generate fixtures |
| GET | `/tournaments/:id/standings` | Points table |

### Streaming
| Method | Path | Description |
|--------|------|-------------|
| POST | `/streams/:matchId/start` | Register RTMP session |
| POST | `/streams/:matchId/stop` | End stream |
| GET | `/streams/:matchId/status` | Health check |

### Analytics
| Method | Path | Description |
|--------|------|-------------|
| GET | `/analytics/players/:id` | Career stats |
| GET | `/analytics/teams/:id` | Team history |
| GET | `/analytics/location` | Aggregates by geo |

## Response Format

```json
{
  "success": true,
  "data": { },
  "error": null,
  "meta": { "timestamp": "2026-05-19T12:00:00Z" }
}
```

## Error Codes

| Code | HTTP | Meaning |
|------|------|---------|
| AUTH_REQUIRED | 401 | Missing token |
| FORBIDDEN | 403 | Insufficient role |
| NOT_FOUND | 404 | Resource missing |
| VALIDATION_ERROR | 422 | Invalid input |
