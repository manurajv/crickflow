# CrickFlow Admin — Developer Documentation

Official technical handbook for the **CrickFlow Admin** ecosystem (`apps/admin_core`, `apps/admin`, `apps/superadmin`).

> Quality bar: Flutter / Firebase / Stripe-style clarity.  
> Scope: **web admin only** — do not change the mobile app from this handbook.

## Quick start

```powershell
cd apps/admin_core; flutter pub get
cd ../superadmin; flutter pub get; flutter run -d chrome
# Org Admin on another port:
cd ../admin; flutter pub get; flutter run -d chrome --web-port=8081
```

Firebase project: **`crickflow-b06bc`** (never commit secrets; use placeholders in docs).

## Table of contents

| Guide | Description |
|-------|-------------|
| [Architecture Overview](architecture.md) | Layers, dependency flow, why this design |
| [Project Structure](project-structure.md) | Every folder explained |
| [Developer Guide](developer-guide.md) | Day-one onboarding |
| [Coding Standards](coding-standards.md) | Naming, lint, PR expectations |
| [Authentication](authentication.md) | Auth flow, roles, sessions, routes |
| [State Management](state-management.md) | Riverpod, repositories, DI |
| [Firestore](firestore.md) | Collections, rules, indexes, queries |
| [Firebase & APIs](firebase-apis.md) | Auth, Firestore, Functions, Maps, ads… |
| [Features](features.md) | Every admin module |
| [Component Library](component-library.md) | Shared `Cf*` widgets |
| [Error Handling](error-handling.md) | Errors, retries, UX |
| [Deployment](deployment.md) | Dev → prod, Hosting, domains |
| [CI/CD](cicd.md) | GitHub Actions, envs, quality gates, manual deploy |
| [Continuity / DR](continuity.md) | Backup, restore, migration, recovery plans |
| [Environments](environments.md) | Config, flags, secret hygiene |
| [Troubleshooting](troubleshooting.md) | Common failures |
| [Changelog](changelog.md) | Version history |
| [Roadmap](roadmap.md) | Done / in progress / planned |

## In-app Docs Center

Super Admin → **Developer Docs** (`/docs`) — searchable UI over the same markdown assets.

When you edit handbook pages, copy them into the package assets:

```powershell
Copy-Item docs\developer\*.md apps\admin_core\assets\docs\ -Force
```

## Related top-level docs

- [WEB_ADMIN_ARCHITECTURE.md](../WEB_ADMIN_ARCHITECTURE.md)
- [WEB_ADMIN_DESIGN.md](../WEB_ADMIN_DESIGN.md)
- [WEB_ADMIN_PRODUCTION.md](../WEB_ADMIN_PRODUCTION.md)
- [WEB_ADMIN_I18N_A11Y.md](../WEB_ADMIN_I18N_A11Y.md)
- [ADMIN_USERS_SCHEMA.md](../ADMIN_USERS_SCHEMA.md)
- [IMPLEMENTATION_STATUS.md](../IMPLEMENTATION_STATUS.md)

## Security

Never document real API keys, OAuth client secrets, service-account JSON, or signing keystores. Use placeholders:

```text
YOUR_FIREBASE_API_KEY
YOUR_OAUTH_CLIENT_ID
path/to/service-account.json  # gitignored
```
