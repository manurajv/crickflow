# Deployment Guide

## Purpose

Ship Admin web apps safely through development → production.

## Environments

| Stage | Use | Notes |
|-------|-----|-------|
| Local | `flutter run -d chrome` | localhost Auth domains |
| Staging | Hosting preview channel / staging site | Same project or separate Firebase project if adopted |
| Production | `superadmin.crickflow.app`, `admin.crickflow.app` | Custom domains + HTTPS |

## CI/CD (Admin)

Full guide: [cicd.md](cicd.md)

- PR validation + main build artifacts (no auto-deploy)
- Manual Hosting deploy via `workflow_dispatch` + `firebase.admin.json`
- Environments matrix: `config/admin/environments.yaml`
- Local gates: `.\scripts\ci\admin-quality.ps1`

Output: `build/web` per app.

## Firebase Hosting

Configure targets in `firebase.json` (sites for superadmin/admin). Deploy example:

```powershell
# Adjust to your scripts / targets
firebase deploy --only hosting:superadmin --project crickflow-b06bc
firebase deploy --only hosting:admin --project crickflow-b06bc
```

Windows helper may exist under `scripts/` — prefer scripted deploys for consistency.

## Rules & indexes

```powershell
firebase deploy --only firestore:rules,firestore:indexes --project crickflow-b06bc
```

Deploy rules **before** clients that depend on new collections.

## Versioning

- App `version` in each `pubspec.yaml`.
- Document user-facing changes in [changelog.md](changelog.md).
- DevOps Release Center tracks release metadata (manual — never auto-prod).

## Custom domains

1. Add domain in Firebase Hosting.
2. DNS records as instructed.
3. Add Auth authorized domains.
4. Restrict API keys by HTTP referrer.

## Best practices

- Smoke-test login + one CRUD path after deploy.
- Keep mobile and admin deploys independent.
- Never deploy with debug API keys unrestricted.

## Common mistakes

- Forgetting authorized domains → Google Sign-In fails.
- Deploying hosting but not rules → permission-denied floods.
- Mixing Super and Org build artifacts on the wrong site.

## Future improvements

- CI pipeline: analyze → test → build web → preview channel.
- Automated lighthouse / a11y checks on preview.
