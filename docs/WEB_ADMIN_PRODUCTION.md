# CrickFlow Web Admin — Production Readiness

Performance, scalability, cost, and maintainability guide for Super Admin and Organization Admin.

This is **not** a feature redesign. Mobile `lib/` is out of scope.

See also: [WEB_ADMIN_ARCHITECTURE.md](WEB_ADMIN_ARCHITECTURE.md) · [WEB_ADMIN_DESIGN.md](WEB_ADMIN_DESIGN.md)

---

## Goals

| Area | Approach |
|------|----------|
| Performance | Cursor pagination, one-shot detail fetches, capped summary scans |
| Scalability | Shared `AdminCache`, query budgets (`AdminQueryLimits`) |
| Cost | Fewer permanent listeners, lower sample caps, unused package removal |
| Maintainability | Shared logger / errors / debouncer / image helper |
| Safety | No business-logic changes; no secret exposure |

---

## Shared infrastructure

| API | Path | Use |
|-----|------|-----|
| `AdminCache` | `core/cache/admin_cache.dart` | TTL in-memory cache (`getOrLoad`, prefix invalidate) |
| `AdminLogger` | `core/logging/admin_logger.dart` | Debug/info/warn/error — Crashlytics-ready |
| `AdminErrors` | `core/errors/admin_errors.dart` | User-facing messages (Auth / Firestore / network) |
| `AdminQueryLimits` | `core/constants/admin_query_limits.dart` | Page size + summary/analytics/grounds caps |
| `AdminDebouncer` | `core/utils/admin_debouncer.dart` | Search debounce (350ms default) |
| `CfNetworkImage` | `shared/widgets/cf_network_image.dart` | Lazy / progressive network images |

---

## Realtime listener policy

**Keep realtime**

- Auth session (`authState`, `idToken`, `adminUser`, `roleDefinition`)
- Support ticket message threads
- Live match / broadcast detail panels (status can change while open)

**One-shot (converted)**

- User / org / team / tournament / ground detail
- Ads / notifications campaigns
- Moderation post detail
- Audit timeline (refresh via hub pull-to-refresh)

---

## Firestore cost levers

| Pattern | Recommendation |
|---------|----------------|
| List tables | Already cursor-paginated (`pageSize` 25) — keep |
| Summary KPI cards | Cap at `AdminQueryLimits.summaryScanMax` (250); prefer `count()` when filters allow |
| Grounds catalog | Cached 2 min; tournament scan ≤ 500 (was 1000) |
| Role usage counts | Cached 5 min via `AdminCache` |
| Analytics / monitoring | Existing TTL caches + sample caps |
| Permanent listeners | Only where UX requires live updates |

### Future cost wins (no code yet)

1. Cloud Function nightly rollups for dashboard KPIs → zero client sample scans  
2. Composite indexes for org-scoped audit queries (drop client over-fetch ×3)  
3. BigQuery export for analytics series  
4. Firebase App Check on admin web hosts  
5. Move provision script OAuth client secret out of the repo (env / Secret Manager)

---

## Dependencies

Removed unused FlutterFire packages from `admin_core` (not imported):

- `firebase_storage`, `firebase_messaging`, `cloud_functions`, `firebase_analytics`, `firebase_remote_config`

Re-add when a feature needs them. Keeps web bundle smaller.

---

## Security checklist

- [x] Client permission gates are UX-only — Firestore rules remain source of truth  
- [x] Audit logger redacts secret-like keys  
- [x] Security Center never displays tokens / passwords / API keys  
- [x] Firebase web API keys in `firebase_options.dart` are expected client keys — protect with Auth domains + App Check  
- [ ] Provision script still embeds Firebase CLI OAuth client credentials — ops-only; rotate / externalize when practical  

---

## Error & logging

```dart
try {
  ...
} catch (e, st) {
  AdminLogger.error('Failed to load users', module: 'users', error: e, stackTrace: st);
  // UI:
  CfSnack.error(context, AdminErrors.userMessage(e));
}
```

---

## Testing readiness (architecture only)

Suggested layout (not implemented):

```
apps/admin_core/test/
  unit/          # repositories, filters, AdminErrors
  widget/        # CfButton, CfEmptyState, PermissionGate
  golden/        # shell chrome
apps/superadmin/integration_test/
```

Prefer fakes for Firestore; keep providers `autoDispose`.

---

## CI/CD readiness (architecture only)

Suggested GitHub Actions jobs (not implemented):

1. `flutter analyze` on `admin_core`, `admin`, `superadmin`  
2. `flutter test`  
3. `flutter build web --release` for both apps  
4. Deploy to Firebase Hosting targets (`superadmin` / `admin`) with environment separation  

Version via `pubspec.yaml` + git tags. Never commit `android/key.properties` or service accounts.

---

## Environment / release

| Item | Guidance |
|------|----------|
| Debug vs release | `AdminLogger` is quiet for info/debug in release |
| Feature flags | Use existing `admin_feature_flags` / Settings hub |
| Hardcoded secrets | Forbidden in client; AdMob unit IDs are public-ish config only |
| Release builds | `flutter build web --release` for Hosting |

---

## Opportunistic follow-ups

Do **not** block production on these:

- Migrate domain status badges → `CfStatusBadge`  
- Prefer `showCfConfirmDialog` / `CfSnack` in remaining raw dialogs  
- Replace remaining summary sample scans with `count()` where exact  
- Persist theme mode in `shared_preferences`  
- Virtualize ultra-long client-side lists (grounds catalog) with `ListView.builder` where not already  

---

## Folder map (admin_core)

```
lib/
  core/           # theme, cache, logging, errors, router, constants
  shared/widgets/ # Cf* design system
  services/       # auth, roles, admin users
  features/       # one folder per hub (data / models / providers / presentation)
  models/         # shared admin models
```
