# Developer Guide

## Purpose

Get a new engineer productive on CrickFlow Admin in one session.

## Prerequisites

- Flutter SDK matching repo (`environment.sdk` in pubspecs)
- Chrome for web
- Firebase CLI (for rules/deploy)
- Access to Firebase project `crickflow-b06bc` (console) — **no key material in git**
- Read [AGENTS.md](../../AGENTS.md) and [WEB_ADMIN_ARCHITECTURE.md](../WEB_ADMIN_ARCHITECTURE.md)

## First-day checklist

1. Clone repo; open in Cursor/VS Code.
2. `cd apps/admin_core; flutter pub get`
3. `cd ../superadmin; flutter pub get; flutter run -d chrome`
4. Sign in with a provisioned Super Admin (see `scripts/provision-super-admin.cjs`).
5. Open **Developer Docs** in the sidebar (`/docs`).
6. Skim Architecture → Auth → State Management → Features.

## Implementation workflow

1. **Design** — confirm panel (Super vs Org), permission, collections.
2. **Models** — enums/filters/entities with `fromMap` / `toMap` as needed.
3. **Repository** — queries with `AdminQueryLimits`, org scoping, audit writes.
4. **Providers** — hub controller + list/detail providers.
5. **UI** — screen + table + detail panel using `Cf*` widgets.
6. **Wire** — route, `AdminRoutePermissions`, nav, exports, rules, docs status.
7. **Verify** — `flutter analyze`, manual permission denial, empty/error states.

## Code examples

### Read session + permission

```dart
final session = ref.watch(adminSessionProvider);
final can = ref.watch(permissionCheckerProvider).can(AdminPermission.canManageUsers);
```

### Navigate

```dart
context.go(AdminRoutePaths.users);
```

### Localized string

```dart
Text(context.l10n.actionSave);
```

### Format timestamp

```dart
ref.watch(adminFormattersProvider).formatDateTime(log.timestamp);
```

## Best practices

- Prefer one-shot fetches for detail panels.
- Always `dispose` TextEditingControllers and cancel Timers.
- After `await`, check `mounted` / `context.mounted` before setState/SnackBars.
- Log admin mutations via `AuditLogger`.

## Common mistakes

- Skipping Firestore rules when adding collections.
- Hardcoding English in new shell chrome (use ARBs).
- Committing `android/key.properties`, service accounts, or `.env` secrets.

## Future improvements

- Codelab-style “add a module” sample PR template.
- Golden tests for shell breakpoints.
