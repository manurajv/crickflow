# Environment Guide

## Purpose

Explain configuration, flags, and secret hygiene for Admin.

## Overview

| Concern | Mechanism |
|---------|-----------|
| Firebase project | `crickflow-b06bc` via `firebase_options.dart` |
| Panel type | `adminAppTypeProvider` override in `main.dart` |
| Feature flags | `admin_feature_flags` / settings UI |
| Platform settings | `admin_platform_settings` |
| UI locale / regional | `SessionPreferences` + `adminRegionalSettingsProvider` |
| Theme | `themeModeProvider` (+ optional prefs) |

## Admin CI dart-defines

See [cicd.md](cicd.md) and `AdminEnvConfig` / `config/admin/environments.yaml`.

| Define | Example |
|--------|---------|
| `ADMIN_ENV` | `development` / `testing` / `staging` / `production` |
| `ADMIN_VERSION` | from `apps/VERSION` |
| `ADMIN_BUILD_NUMBER` | CI run number |
| `ADMIN_FIREBASE_PROJECT_ID` | display / gating only |
| `ADMIN_GIT_SHA` / `ADMIN_GIT_REF` | build provenance |

These are **not** secrets.

## Secrets — never commit

| Secret | Storage |
|--------|---------|
| Service account JSON | Local / CI secret store |
| Signing keystores | Local, gitignored |
| OAuth client secret | Cloud console only |
| Maps API keys | Console + restricted referrers |
| RTMP / stream keys | Not in admin docs or clients |

Placeholders in documentation only: `YOUR_*`.

## Feature flags

- Prefer Firestore flag docs for admin-operated toggles.
- Remote Config mirror is architectural — wire carefully without breaking mobile.

## Firebase projects

Today: single shared project with mobile. If you split staging:

1. Separate Firebase project.
2. Separate `firebase_options`.
3. Separate Auth users / seed scripts.
4. Document which hosting site maps to which project.

## Best practices

- Treat every browser-shipped value as public.
- Rotate keys on exposure.
- Keep provision scripts out of logs.

## Common mistakes

- Screenshots of Firebase console showing API keys in tickets.
- Using production service accounts on laptops without disk encryption policies.

## Future improvements

- Explicit `AdminEnvironment` enum (dev/staging/prod) with banner in non-prod.
