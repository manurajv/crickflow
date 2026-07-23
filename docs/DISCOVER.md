# Discover — Cricket Opportunity Marketplace

**Status:** Implemented · **Firebase:** `crickflow-b06bc`

Discover is a marketplace where players, teams, officials, coaches, organizers, scorers, grounds, and sponsors find each other.

## Screen

- Route: `/discover` (shell tab)
- Saved bookmarks: `/discover/saved` (Profile hub)
- Deep link: `/discover?postId={id}` · share URI via `DeepLinkUtils.hostedOpportunityPostUri`

## Categories

All, Find Player, Find Team, Find Umpire, Find Scorer, Find Coach, Find Ground, Find Tournament, Find Sponsor, Find Commentator, Find Streaming Crew, Find Photographer, Find Videographer.

Category-specific fields are driven by `OpportunityFieldSchema` — add new types by extending the enum + schema map.

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

## Deploy

```powershell
.\scripts\deploy-firebase.ps1
```

Deploys Firestore rules, indexes, and Storage rules (`opportunities/{userId}/…`).
