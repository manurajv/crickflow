# Firebase & API Documentation

## Purpose

Describe external/backend APIs used by CrickFlow Admin (and related platform services). **No secrets.**

## Overview

| API | Admin usage | Notes |
|-----|-------------|-------|
| Firebase Authentication | Login, session | Same project as mobile |
| Cloud Firestore | Primary data | Additive admin collections |
| Firebase Hosting | Deploy web panels | Separate targets/sites |
| Cloud Functions | Platform backend | Do not break mobile; see FUNCTIONS.md |
| Cloud Storage | Future admin uploads | Prefer signed rules |
| Remote Config | Mirrored keys later | Admin settings façade exists |
| Google Sign-In | Admin OAuth | Authorized domains required |
| Maps / Places | Grounds map preview | Client keys via Firebase options — rotate in console |
| AdMob | Config mirror only | Mobile SDK unchanged |
| YouTube / Facebook / RTMP | Broadcast **monitor** only | Do not control streams from admin |
| FCM | Campaign architecture | Do not alter mobile generation |

## Firebase Authentication

**Purpose:** Identify administrators.  
**Auth:** Email/password, Google provider.  
**Flow:** See [authentication.md](authentication.md).  
**Errors:** Map via login screen / `AdminErrors` (wrong password, disabled user, popup blocked).  
**Never document:** OAuth client secrets, service account private keys.

## Cloud Firestore

**Purpose:** Persist admin + shared domain data.  
**Auth:** Firebase Auth uid + rules.  
**Usage:** Repositories only.  
**Errors:** permission-denied, failed-precondition (index), unavailable — show professional messages.  
**Data flow:** UI → provider → repository → Firestore.

## Cloud Storage

**Purpose:** Media for CMS/ads (as implemented).  
**Auth:** Rules by admin role.  
**Usage:** Upload via future/storage helpers; never embed long-lived secrets in clients beyond Firebase config.

## Cloud Functions

**Purpose:** Server workflows (notifications, scoring side-effects, etc.).  
**Admin rule:** Prefer additive callables; do **not** modify mobile notification generation unless explicitly tasked.  
**Docs:** [FUNCTIONS.md](../FUNCTIONS.md).

## Remote Config

**Purpose:** Feature toggles / remote parameters.  
**Admin:** `admin_remote_config` / settings UI may mirror keys — values are not secrets store.

## Maps

**Purpose:** Ground location preview.  
**Auth:** API key restricted by HTTP referrer in Google Cloud Console.  
**Placeholder:** `YOUR_MAPS_BROWSER_KEY` (configure in Cloud Console, not in markdown).

## AdMob

**Purpose:** Unit IDs / placement metadata for operators.  
**Does not** initialize mobile AdMob SDK inside admin.

## YouTube / Facebook Live / RTMP

**Purpose:** Observe broadcast metadata and health.  
**Do not** start/stop external streams from admin docs or code without a dedicated safe design.

## Error handling pattern

```dart
try {
  await repo.save(...);
} catch (e) {
  state = state.copyWith(error: AdminErrors.userMessage(e));
}
```

## Best practices

- Restrict API keys by domain/bundle in cloud consoles.
- Rotate compromised keys immediately; never paste real keys into docs/PRs.
- Keep streaming control planes separate from admin monitoring.

## Common mistakes

- Checking secrets into `firebase_options` commentary or screenshots.
- Calling privileged Functions without App Check / auth context (when enabled).

## Future improvements

- Central `AdminApiCatalog` linking each hub to backends.
- OpenAPI for any future HTTPS admin gateway.
