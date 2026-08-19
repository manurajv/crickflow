# Firebase integration (web only)

Shared project: **crickflow-b06bc**

## Client config

Loaded from `NEXT_PUBLIC_FIREBASE_*` environment variables. Never commit service account JSON.

The values in `.env.example` are the **existing public web client** identifiers already used by Admin. They are not secrets. A dedicated Firebase Web App named “CrickFlow Web” can be registered later; only env vars change.

## What this app will never do

- Modify `lib/config/firebase_options.dart` (mobile)
- Modify `apps/admin` or `apps/superadmin` options
- Deploy root `firebase.json` Hosting
- Deploy Firestore rules / indexes / Cloud Functions
- Use the Admin SDK

## Reads vs writes

Public reads follow existing rules (`matches`, `players`, `teams`, `tournaments`, `community_posts`, `opportunity_posts`, ball events, overlay).

Writes: follow, like, comment, chat, notifications mark-read, community/discover create, profile update — all gated by `request.auth` in existing rules.

## Realtime

`onSnapshot` is limited to:

- `matches/{id}` when status is live / innings break
- `matches/{id}/overlay/current`
- `matches/{id}/ball_events` with `orderBy sequence desc limit 40` on live pages
- `chats` / `notifications` for the signed-in user
