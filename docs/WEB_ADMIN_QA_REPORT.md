# CrickFlow Web Admin — Enterprise QA Report

**Date:** 2026-07-30  
**Scope:** `apps/admin_core`, `apps/admin`, `apps/superadmin` only (mobile app excluded)  
**Objective:** Production readiness validation — bugs, permissions, security, performance policy, memory — **not** new features

---

## Executive summary

A full-module audit was performed against auth, roles, navigation, CRUD hubs, realtime policy, security, and dispose hygiene. **Verified Critical/High defects were fixed** in this pass. Several **High security improvements** (Firestore rules for audit logs) remain intentionally deferred because they require coordinated query changes to avoid breaking Org Admin Audit Center.

Automated unit tests were added for route any-of permissions and SOC section visibility (foundation for a larger QA harness).

---

## Fixes applied this pass

| Priority | Issue | Fix |
|----------|--------|-----|
| **Critical** | Org Admin session list included platform / unscoped auth events (`organizationId == null`) | Strict org filter; empty list if org missing; applied to primary + fallback query |
| **High** | Org Admin could open unscoped SOC sections (roles, IPs, backups, DR, policies…) | `SocHubSection.isPlatformOnly` + chip filtering + load/setSection guards |
| **High** | `/reports` router required only `canViewReports` while UI allowed community/discover | `AdminRoutePermissions.anyOf` + `isAllowed` used by `auth_redirect` |
| **High** | Match commentary `TextEditingController` created in `build` | Stateful section with single disposed controller |
| **High** | DevOps filter sheet recreated controllers on every keystroke | Controllers owned for dialog lifetime + disposed in `finally` |
| **Medium** | Match action dialog controllers never disposed | `try/finally` dispose |
| **Low** | Login Google redirect await lacked post-await `mounted` guard | Guard added |

---

## Remaining issues (not auto-fixed)

### High (deferred — needs coordinated change)

| Issue | Why deferred | Recommendation |
|-------|----------------|----------------|
| `admin_audit_logs` readable by any active admin (`firestore.rules`) | Tightening rules without `.where('organizationId' == …)` on every list query causes Firestore to reject Org Admin queries entirely | Add composite indexes + org-scoped queries in `AuditRepository` / security session fetch, then restrict rules to Super Admin **or** matching `organizationId` |
| Dead `watch*` snapshot APIs on repositories | Unused after one-shot conversion; low runtime risk today | Mark `@Deprecated` or remove in a dedicated cleanup PR |

### Medium

| Issue | Recommendation |
|-------|----------------|
| Dialog `TextEditingController` leaks in announcements / advertisers / segments / user detail | Dispose in `finally` after `showDialog` (same pattern as match actions) |
| `AdminSessionStatus.loading` → redirect `null` can briefly show shell chrome | Holding splash route until `authorized` / `unauthenticated` |
| Revenue / Players hubs rely on router gate + session scope | Optional in-page `PermissionGate` |

### Low

| Issue | Recommendation |
|-------|----------------|
| Fixed-height empty cards (e.g. broadcasts 240px) | Prefer `ConstrainedBox(minHeight:)` as empty content grows |
| Zero widget/integration tests beyond new unit tests | Expand scaffolding listed below |
| Deprecated `DropdownButtonFormField.value` | Migrate when Flutter API stabilizes |

---

## Module validation matrix

| Module | Auth/perm | CRUD / actions | Realtime policy | Notes |
|--------|-----------|----------------|-----------------|-------|
| Dashboard | OK | Read | One-shot + refresh | |
| Authentication | OK (mounted fixes) | — | Auth stream (required) | |
| Authorization / roles | OK | Role merge healthy | — | DevOps perm Super-only |
| Users | OK | OK | One-shot detail | |
| Organizations | OK | OK | One-shot detail | |
| Teams | OK | OK | One-shot detail | |
| Players | Placeholder | — | — | Router-gated |
| Grounds | OK | OK | One-shot + catalog TTL | |
| Tournaments | OK | OK | One-shot detail | |
| Matches | OK | OK | Live detail OK | Commentary controller fixed |
| Broadcasts | OK | Monitor-only | Live detail OK | No streaming interference |
| Community / Discover / Reports | OK | Moderation | One-shot | Reports any-of fixed |
| Ads | OK | OK | One-shot | |
| Notifications | OK | Campaigns only | One-shot | Mobile generation untouched |
| Analytics | OK | Read/filter | One-shot | |
| Support | OK | OK | Messages realtime OK | |
| CMS | OK | OK | — | |
| Audit Logs | OK (client filter) | Read | One-shot | Rules still global-read |
| Security Center | Fixed | Org vs platform | One-shot | Platform chips hidden for Org |
| AI Center | OK | OK | — | |
| Monitoring | OK | Read | Polled | |
| DevOps | Super-only | Manual only | One-shot | Not in Org Admin router |
| Global Search / Settings | OK | Settings write Super | — | |

---

## Production checklist

| Area | Status |
|------|--------|
| Authentication (login / logout / Google / forgot / remember) | Pass (code review + prior fixes) |
| Session / role routing / access denied | Pass |
| Permission gates aligned with router | Pass for `/reports` after fix; others single-perm OK |
| Realtime limited to policy surfaces | Pass |
| Org data scoping (client) | Pass for sessions after fix; audit rules still open |
| No secrets in SOC / DevOps UI | Pass |
| Dispose hygiene (screens) | Pass; dialogs residual Medium |
| Responsive / empty-state overflow | Mostly Pass (`CfEmptyState` FittedBox) |
| Dark / light theme tokens | Pass (design system) |
| Automated tests | Partial (new unit tests; expand) |
| Critical bugs | Cleared in this pass |
| Firestore audit rule hardening | **Open** (High deferred) |

---

## Recommended test scaffolding (next)

```
apps/admin_core/test/core/router/auth_redirect_test.dart
apps/admin_core/test/models/role_definition_merge_test.dart
apps/admin_core/test/models/default_admin_role_permissions_test.dart
apps/admin_core/test/features/security/security_session_org_filter_test.dart
apps/admin_core/test/features/auth/admin_session_provider_test.dart
apps/admin/test/config/org_router_excludes_devops_test.dart
apps/superadmin/test/config/superadmin_router_includes_devops_test.dart
```

Run: `cd apps/admin_core && flutter test`

---

## Future improvements (non-blocking)

1. Server-side org scoping for `admin_audit_logs` (rules + queries + indexes).
2. Export architecture (CSV/Excel/PDF) via shared `AdminExportService` stub.
3. Golden / widget tests for `PermissionGate` and shell breakpoints.
4. Remove unused `watch*` repository methods.
5. CI job: `flutter analyze` + `flutter test` for admin packages on every PR.
6. Accessibility pass (focus order, contrast, screen reader labels on tables).

---

## Explicit non-goals respected

- No new product features  
- No UI redesign  
- No mobile app changes  
- No streaming / scorebug / overlay / RTMP changes  
- No mobile notification generation changes  
- Uncertain issues documented, not blindly patched  
