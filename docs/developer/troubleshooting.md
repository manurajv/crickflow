# Troubleshooting Guide

## Purpose

Fast runbooks for common Admin failures.

## Authentication issues

| Symptom | Checks |
|---------|--------|
| Stuck on loading | `admin_users/{uid}` missing/inactive; console errors |
| Access Denied | Wrong panel (Super vs Org); missing `organizationId` for Org Admin |
| Forbidden on route | Permission missing in `admin_roles` or overrides |
| Google Sign-In fails | Authorized domains; third-party cookies; popup blocked |
| Remember me ignored | Persistence path / prefs cleared |

## Firestore issues

| Symptom | Checks |
|---------|--------|
| permission-denied | Rules deployed? Active admin? Org match? |
| failed-precondition | Open index link; deploy indexes |
| Empty lists | Filters too strict; org scope; soft-delete flags |
| High cost | Unexpected `.snapshots()`; missing limits |

## Hosting / build issues

| Symptom | Checks |
|---------|--------|
| Blank page | Check browser console; base href; wrong site artifact |
| Old UI after deploy | Hard refresh / CDN cache |
| Analyze failures | Run `flutter pub get` in `admin_core` then host app |

## Broadcast / notifications

| Symptom | Checks |
|---------|--------|
| No live data | Listener only on detail; match actually live? |
| Campaign confusion | Admin campaigns ≠ mobile automatic notifications |

## Permission issues

- Confirm enum seeded (`DefaultAdminRolePermissions` merge).
- Confirm nav item permission matches route.
- Reports need any-of permissions (community/discover/viewReports).

## Localization issues

- Missing strings → run `flutter gen-l10n` in `admin_core`.
- RTL not flipping → locale not `ar` (or other RTL code).

## DevOps / Security / Continuity

- DevOps missing in Org Admin — expected.
- Continuity & DR missing in Org Admin — expected (`canManageContinuity` Super-only).
- Continuity never auto-restores; preview requests stay `awaitingConfirmation`.
- Org SOC missing roles/backups — expected (platform-only).

## Best practices

- Reproduce on a clean Chrome profile.
- Capture **request URL + rules version**, not secrets.

## Future improvements

- In-app “diagnostics” panel for Super Admin (session role, app type, locale).
