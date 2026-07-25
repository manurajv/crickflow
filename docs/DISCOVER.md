# Discover — Cricket Opportunity Marketplace

**Status:** Implemented · **Firebase:** `crickflow-b06bc`

Discover is a marketplace where players, teams, officials, coaches, organizers, scorers, grounds, and sponsors find each other.

## Screen

- Route: `/discover` (shell tab)
- Saved bookmarks: `/discover/saved` (Profile hub)
- Deep link: `/discover?postId={id}` · share URI via `DeepLinkUtils.hostedOpportunityPostUri`

## Post intent (create flow)

Every post type is **seeking** something. Titles are fixed (not editable):

| Feed chip | Fixed title | Posting as |
|-----------|-------------|------------|
| Find Player | I'm looking for a player | Team / captain / organizer |
| Find Team | I'm looking for a team | Player |
| Find Umpire | I'm looking for an umpire | Organizer / match manager |
| Find Scorer | I'm looking for a scorer | Organizer / match manager |
| Find Coach | I'm looking for a coach | Player / team / academy |
| Grounds | Ground available | Ground owner / manager |
| Find Sponsor | I'm looking for a sponsor | Organizer / tournament |
| Find Commentator | I'm looking for a commentator | Organizer / streamer |
| Find Streaming Crew | I'm looking for a streaming crew | Organizer / tournament |
| Find Photographer | I'm looking for a photographer | Organizer / team |
| Find Videographer | I'm looking for a videographer | Organizer / team |

**Not in Discover create:** tournaments — post those in **Community**. Legacy `findTournament` posts may still appear under All.

Category pick shows role + subtitle so Find Player vs Find Team is unambiguous. **Grounds** is a listing (offer a venue), not a seeker post.

Category-specific fields are driven by `OpportunityFieldSchema` — extend the enum + schema map for new types.

**Find Umpire / Scorer / Commentator / Streaming Crew / Photographer / Videographer:** “When needed” supports **one day** or a **date range** (`fields.matchDate` + optional `fields.matchDateEnd`).

Feed cards show **every filled schema field** as a compact badge (long text truncated). Dates stay on the calendar row; location stays on its own line. Ground posts with multiple photos show a **16:9 swipeable gallery** (crop locked to 16:9 on upload).

## Quick filters

| Category | Filters |
|----------|---------|
| All | Leather · Tennis · Nearby · Newest |
| Find Player | Roles · Right/Left-hand · We pay · Player pays · Free · Leather · Tennis · Nearby · Newest |
| Find Team | Roles · Club/School/Academy/Casual · I get paid · I pay to join · Free · Leather · Tennis · Nearby · Newest |
| Find Umpire | Certified · Experienced · Open/Club/School/Company · Paid · Free · Leather · Tennis · Nearby · Newest |
| Find Scorer | Digital · CrickFlow · Experienced · Open/Club/School/Company · Paid · Free · Leather · Tennis · Nearby · Newest |
| Find Coach | Batting · Bowling · Fitness · Fielding · All-round · Nearby · Newest |
| Grounds | Bookable · Turf · Matting · Astro · Leather · Tennis · Nearby · Newest |
| Find Commentator | English · Sinhala · Tamil · Experienced · Nearby · Newest |
| Find Streaming Crew | Drone · Live Graphics · Commentary · Nearby · Newest |
| Find Photographer | Experienced · Nearby · Newest |
| Find Videographer | Drone · Live Production · Highlights · Nearby · Newest |
| Find Sponsor | Nearby · Newest |

Matching aliases include legacy payment labels, batting `Right`/`Left`, and `Either` for ball type.

## Firestore

| Collection / path | Purpose |
|-------------------|---------|
| `opportunity_posts/{id}` | Listings (dynamic `fields` map, `searchText`, counters, expiry) |
| `opportunity_posts/{id}/saves/{uid}` | Per-post bookmark |
| `opportunity_posts/{id}/applications/{uid}` | Future applications |
| `opportunity_post_reports/{id}` | Moderation reports |
| `users/{uid}/saved_opportunity_posts/{postId}` | User bookmark index |

**Status values:** `active` · `expired` · `removed`  
**Expiry:** 1 / 3 / 7 / 30 days (`expiresAt`)

## Client stack

```
lib/features/discover/domain/          # categories + field schema
lib/data/models/opportunity_post_model.dart
lib/data/repositories/opportunity_repository.dart
lib/shared/providers/opportunity_provider.dart
lib/features/discover/presentation/    # feed, create flow, cards
```

## Admin

Platform admins (`app_meta/platform_admins.uids`) can pin, feature, remove posts, and block authors.

Authors can **Edit** or **Delete** their own listings from the card overflow menu (⋯).

## Deploy

```powershell
.\scripts\deploy-firebase.ps1
```

Deploys Firestore rules, indexes, and Storage rules (`opportunities/{userId}/…`).
