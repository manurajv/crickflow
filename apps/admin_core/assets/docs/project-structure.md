# Project Structure

## Purpose

Describe every important folder in the admin ecosystem.

## Overview

```text
crickflow/
  apps/
    admin_core/          # Shared Flutter package
    admin/               # Organization Admin web app
    superadmin/          # Super Admin web app
  docs/
    developer/           # This handbook
  functions/             # Cloud Functions (shared project — touch carefully)
  firestore.rules
  firebase.json
  scripts/               # Provisioning, deploy helpers
```

## `apps/admin_core/lib/`

| Path | Purpose |
|------|---------|
| `core/config/` | App type (`superAdmin` / `organizationAdmin`), Firebase bootstrap |
| `core/constants/` | Collections, query limits, breakpoints |
| `core/theme/` | Colors, dimens, typography, motion, elevations, ThemeData |
| `core/extensions/` | `context.adminColors`, `adminDimens` |
| `core/router/` | Paths, permissions map, auth redirect, GoRouter refresh |
| `core/cache/` | TTL memory cache |
| `core/logging/` | `AdminLogger` |
| `core/errors/` | User-facing error mapping |
| `core/locale/` | Regional settings, formatters, language catalog |
| `core/l10n/` | MaterialApp l10n wiring, nav label resolver |
| `core/a11y/` | Accessibility helpers |
| `core/utils/` | Debouncer, small utilities |
| `l10n/` | ARB files + generated localizations |
| `models/` | Cross-cutting models (permissions, roles, nav, admin user) |
| `services/` | Auth, admin user/role services, session preferences |
| `shared/widgets/` | Reusable `Cf*` design-system widgets |
| `features/<name>/` | Feature modules (see below) |
| `crickflow_admin_core.dart` | Barrel exports |

### Feature module layout

```text
features/<feature>/
  data/           # *Repository — Firestore access
  models/         # Entities, enums, filters
  providers/      # Riverpod controllers + providers
  presentation/   # *Screen + widgets/
```

## `apps/admin` / `apps/superadmin`

| Path | Purpose |
|------|---------|
| `lib/main.dart` | `ProviderScope` overrides + `MaterialApp.router` |
| `lib/config/nav_config.dart` | Sidebar sections for that panel |
| `lib/config/router.dart` | GoRouter tree |
| `lib/config/firebase_options.dart` | Generated Firebase options (**no secrets in docs**) |

## `docs/`

Product and admin architecture markdown. Prefer linking rather than duplicating.

## Naming conventions (folders/files)

| Kind | Pattern | Example |
|------|---------|---------|
| Screen | `*_screen.dart` | `users_screen.dart` |
| Widget | descriptive / `*_panel.dart` | `user_detail_panel.dart` |
| Repository | `*_repository.dart` | `users_repository.dart` |
| Providers | `*_providers.dart` | `users_providers.dart` |
| Enums / filters | `*_enums.dart`, `*_filters.dart` | `user_filters.dart` |

## Best practices

- New features live under `features/<name>/`, not loose under `lib/`.
- Export public screens/providers from `crickflow_admin_core.dart` when host apps need them.
- Keep host apps thin (nav + router + bootstrap only).

## Common mistakes

- Putting Org-only routes into Super Admin (or vice versa) inconsistently.
- Creating widgets outside `shared/` that are clearly reusable.
- Bypass repositories with direct Firestore in widgets.
