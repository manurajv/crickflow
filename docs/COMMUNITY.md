# Community posts (MVP)

Firestore collection: `community_posts`

## Purpose

Recruitment and local cricket network — scorers, players, umpires, practice slots, grounds. Powers the **Community** tab and category deep-links from **Discover**.

## Fields

| Field | Type |
|-------|------|
| authorId | string (Firebase uid) |
| authorName | string |
| authorRole | string? |
| category | enum string (see `CommunityPostCategory`) |
| title | string |
| body | string |
| location | map (country, stateProvince, city) |
| createdAt | ISO8601 |
| updatedAt | ISO8601 |

## Queries

- Global feed: `orderBy createdAt desc` (limit 50)
- By category: `where category == … orderBy createdAt desc`
- Near me: `where location.city == … orderBy createdAt desc`

Indexes: `firestore.indexes.json`

## Security

- Signed-in read
- Create/update/delete only if `authorId == auth.uid`

## Routes

- `/community` — feed + filters
- `/community?category=lookingForScorer` — filtered (from Discover)
