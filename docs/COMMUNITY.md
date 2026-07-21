# Community (social feed)

Firestore collection: `community_posts`

## Purpose

Cricket community social feed — recruitment, tournament announcements, media posts, and local network. Powers the **Community** tab and category deep-links from **Discover**.

## Fields (backward compatible)

| Field | Type | Notes |
|-------|------|--------|
| authorId | string | Firebase uid |
| authorName | string | Denormalized |
| authorRole | string? | |
| authorPhotoUrl | string? | |
| authorPlayerId | string? | Public player ID |
| authorVerified | bool | From badges when posting |
| category | enum string | See `CommunityPostCategory` |
| postKind | enum string | general / tournament / team / achievement / match / image / video |
| title | string | |
| body | string | |
| location | map | country, stateProvince, district, city, lat/lng |
| tournamentId | string? | Linked tournament |
| matchId / teamId | string? | Optional embeds |
| media | list | `{url, type, aspect}` — aspect: square / landscape16x9 / portrait9x16 / free |
| tournamentSnapshot | map? | Denormalized tournament card (thumbnail, contact, fees…) |
| likeCount / commentCount / shareCount / saveCount | int | |
| isPinned / isSponsored / isAdminPost | bool | Ranking boost |
| createdAt / updatedAt | ISO8601 | |

### Subcollections

- `community_posts/{id}/likes/{userId}`
- `community_posts/{id}/saves/{userId}`
- `community_posts/{id}/comments/{commentId}` (+ nested `likes`)

### Reports

- `community_post_reports/{id}` — posts/comments: `postId`, optional `commentId`/`authorId`; user reports: `type: user`, `authorId` = reported uid
- Chat blocks: `chat_blocks` — blocked authors are filtered from the Community feed

## Queries

- Feed head: `orderBy createdAt desc` (page size 20) + load-more
- By category: `where category == … orderBy createdAt desc`
- Location multi-filter: client-side match against persisted selections (SharedPreferences)
- Blocked-author filter: client-side via `blockedUserIdsProvider`

Indexes: `firestore.indexes.json`

## Security

- Public read on posts
- Create if `authorId == auth.uid`
- Update: author **or** engagement counter-only changes
- Likes/saves/comments: signed-in owner of the interaction doc

## Routes

- `/community` — feed + location filter + create
- `/community?category=lookingForScorer` — Discover deep-link
- `/community?postId=…` — share deep-link (hosted via `DeepLinkUtils.hostedCommunityPostUri`)
- `/community/chats`, `/community/chats/requests`, `/community/chats/:chatId` — auth required

## UI surfaces

- Redesigned post cards (profile, follow, media, tournament embed, actions)
- Infinite scroll + pull-to-refresh + skeletons
- Create post with post kinds + image crop (aspect picker)
- Location multi-select filter (persisted)
- Comments sheet (nested replies, like/report, copy, delete own)
- Full-screen media viewer (swipe + double-tap / pinch zoom)
- Chat FAB + list / requests / conversation; profile Message + Report Player

## Deferred later

- Online presence indicators in chat
- @mention picker polish
- GPS-radius ranking beyond city/country
- Native video post upload (schema ready)

## Search

Community AppBar search opens unified `/search`. New **Posts** category (+ included in All). Hashtag-style queries (`#tag`) match post text.

## Chat (DM)

Firestore: `chats/{chatId}`, `chats/{chatId}/messages/{messageId}`, `chat_blocks/{blocker_blocked}`

| Route | Screen |
|-------|--------|
| `/community/chats` | Chat list (pinned → unread → recent; swipe archive/delete; search users) |
| `/community/chats/requests` | Message requests (Accept / Decline / Block) |
| `/community/chats/:chatId` | Conversation |

First contact creates `status: request`. After accept → `active`. Decline/block prevents repeats.
Community FAB shows unread + request badge. Profile **Message** opens/creates a thread.
