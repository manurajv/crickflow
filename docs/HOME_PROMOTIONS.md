# Home promotions (Admin)

Collection: `home_promotions`

Platform admins (UIDs in `app_meta/platform_admins.uids`) can create/update/delete docs. All clients may read active creatives.

## Example advertisement

```json
{
  "kind": "advertisement",
  "title": "Island Cricket Gear",
  "description": "Bats, pads, and kits for club cricket.",
  "imageUrl": "https://…",
  "buttonText": "Shop now",
  "redirectAction": "url",
  "redirectUrl": "https://example.com/shop",
  "priority": 10,
  "active": true,
  "expiresAt": null,
  "createdAt": "<timestamp>"
}
```

## Example announcement

```json
{
  "kind": "announcement",
  "title": "New version available",
  "description": "Streaming studio improvements and highlight seek.",
  "imageUrl": "",
  "buttonText": "Learn more",
  "redirectAction": "route",
  "redirectUrl": "/store",
  "priority": 20,
  "active": true
}
```

Deploy rules: `.\scripts\deploy-firebase.ps1` (includes `firestore.rules`).
