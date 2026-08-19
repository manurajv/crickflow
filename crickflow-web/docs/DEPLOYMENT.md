# CrickFlow Web — production deploy

The consumer web app is isolated from mobile Hosting. **Never** run `firebase deploy --only hosting` from the repository root for this app.

## Live site

| Item | Value |
|------|--------|
| Firebase project | `crickflow-b06bc` |
| Hosting site id | `crickflow` |
| Default URL | https://crickflow.web.app |
| Alternate URL | https://crickflow.firebaseapp.com |

Mobile App Links and `/live` stay on the **default** Hosting site (`crickflow-b06bc.web.app`). Do not retarget that site.

## Why a separate site

Root `firebase.json` already serves:

- `/live/**` public scorecard
- `/teams/**` `/tournaments/**` `/match/**` App Link openers
- `assetlinks.json` / AASA

Replacing that site would break the mobile app.

## Deploy (this folder only)

```powershell
cd crickflow-web
.\scripts\deploy-web.ps1
```

That command uses `crickflow-web/firebase.json` (`site: crickflow`) and does not touch root Hosting.

Optional later: attach `www.crickflow.app` to **this** site in Console, then set `NEXT_PUBLIC_SITE_URL` to that URL.

## Auth

Add `crickflow.web.app` and `crickflow.firebaseapp.com` under Authentication → Settings → Authorized domains so Google / phone sign-in works.

## CI

`.github/workflows/crickflow-web.yml` runs typecheck, tests, lint, the production gate, and `next build` when `crickflow-web/**` changes. It does **not** deploy.

## Health

`GET https://crickflow.web.app/api/health` returns `{ ok: true, service: "crickflow-web" }`.

## Rollback

Restore the previous Hosting release for site `crickflow` in Console. Do not retarget the mobile site.
