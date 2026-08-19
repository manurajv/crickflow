# CrickFlow Web

Independent **consumer web platform** for CrickFlow. Shares the existing Firebase project (`crickflow-b06bc`) with the mobile app. Does **not** modify:

- Flutter mobile app (`lib/`)
- Admin / Super Admin (`apps/admin`, `apps/superadmin`)
- Root `firebase.json` Hosting (App Links + `/live` scorecard)

Tracking lives here only:

- [WEB_DEVELOPMENT_STATUS.md](./WEB_DEVELOPMENT_STATUS.md)
- [WEB_FEATURE_PARITY.md](./WEB_FEATURE_PARITY.md)
- [docs/WEB_ARCHITECTURE.md](./docs/WEB_ARCHITECTURE.md)

## Stack

Next.js (App Router) · TypeScript · Tailwind CSS · Firebase client SDK · Zustand · TanStack Query · Recharts

## Setup

```bash
cd crickflow-web
copy .env.example .env.local
npm install
npm run dev
```

Open http://localhost:3000

## Auth

Google popup and phone OTP (same Firebase Authentication as mobile). Add `localhost` and `crickflow.web.app` under Authentication → Settings → Authorized domains.

## Deploy (ops)

Do **not** run `firebase deploy --only hosting` from the repo root for this app.

Live Hosting site: **crickflow** → https://crickflow.web.app  
Keep `crickflow-b06bc.web.app` on the existing mobile Hosting site for App Links and `/live`.

```powershell
cd crickflow-web
.\scripts\deploy-web.ps1
```

## Tests and CI

```bash
npm test
npm run ci
```

GitHub Actions: `.github/workflows/crickflow-web.yml` (no automatic deploy).

Ops checklist: [docs/PRODUCTION_CHECKLIST.md](./docs/PRODUCTION_CHECKLIST.md).
