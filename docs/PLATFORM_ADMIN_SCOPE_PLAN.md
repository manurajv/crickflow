# Platform admin scope: plan

Status: proposed, nothing destructive done yet. Last updated: 2026-10-08.

## Decision

- `apps/superadmin` (https://crickflow-superadmin.web.app) is the **only** web admin
  panel. It covers the whole CrickFlow platform: users, teams, players, grounds,
  matches, tournaments, community/discover moderation, reports, notifications, ads,
  CMS, analytics, revenue, monitoring, support, AI ops, security, DevOps, DR, audit,
  and **Admins & Access** for platform staff (super admins, moderators, support,
  viewers).
- Organization / club / association / series administration is a feature of the
  **mobile app** (the existing `lib/features/series` "Orgs" feature). It is not a web panel.
- `apps/admin` (Organization Admin panel, hosting site `crickflow-admin`) is
  retired.

## Current state (verified 2026-10-08)

| Area | Web org model (`apps/admin`) | Mobile org model (`lib/features/series`) |
| --- | --- | --- |
| Entity | `organizations/{orgId}` (0 docs in prod) | `series/{id}` with `kind` (association/federation/club/company/series/league/cup/other) |
| Who administers | `admin_users` roleId `admin` + `organizationId` | `series.superAdminUserId`/`createdBy` (owner) + `series_admins/{seriesId_uid}` status `active`; clubs via `series_club_admins` |
| Scope stamp on data | `organizationId` on users/teams/players/matches/tournaments/grounds | `seriesId` on matches/tournaments; `series_clubs`, `series_memberships`, `series_competitions` |
| Writes | Direct Firestore (rules: `isOrgAdminUser()`) | Callables in `functions/src/series/seriesFunctions.js` (Admin SDK) + limited draft creates |

The two models don't share any data. In production there are no `organizations` docs. The
only `roleId: admin` record has no `organizationId`, so it can't use any panel.
Retiring `apps/admin` therefore loses no live data.

### Super Admin panel items that are org/series-specific

- **Organizations** (`features/organizations`): full CRUD on the unused
  `organizations` collection, plus link/unlink org admin and ownership transfer.
  This belongs to the web org model.
- **Series** (`features/series`, `SeriesInvestigationScreen`): read-only
  investigation of mobile `series` + platform suspend/restore (rules already allow
  super admin status-only updates). This is platform oversight, so keep it.
- Org-scoping code paths in shared repositories (`AdminAppType.organizationAdmin`
  branches in users/teams/broadcasts/moderation/dashboard/analytics/security
  repositories, `adminOrgAccessProvider`, `organizationSuspended` session state).
  These are only exercised by `apps/admin`.
- Admins & Access: the "Admin (organization)" role + org picker. **Done in this
  change:** org-scoped roles are hidden for new grants (still editable on a legacy
  record), there's no default role, and the copy says org/series admins live in the mobile app.

### Gap: platform staff roles can't enter the Super Admin panel

`moderator`, `tournamentAdmin`, `support` and `viewer` have `allowedPanel: none`
(both in `AdminRole.allowedPanel` and the seeded `admin_roles` docs). Most admin
writes in `firestore.rules` also check `isSuperAdminUser()` (47 uses) rather than
a permission. Today only super admins can really use the panel.

## Plan (prioritized)

1. **Super Admin panel scope (code, low risk)**
   - Replace the **Organizations** screen with read/moderate oversight of mobile
     orgs: a list of `series` grouped by kind (Associations / Clubs / Series), with
     owner/admins, clubs, approvals, audit, and suspend/restore. Merge it with the existing
     Series investigation screen into one "Orgs & Series" nav item. Remove
     create/edit/link-admin/transfer on `organizations`.
   - Optional: add restore (`suspended -> active`) and archive to the oversight
     screen (rules already allow status-only changes for super admins).
2. **Platform staff access (code + prod data + rules, needs approval)**
   - Set `allowedPanel: superAdmin` for moderator/support/viewer/tournamentAdmin in
     `AdminRole.allowedPanel` and `scripts/seed-admin-roles.cjs`, and update the 4
     prod `admin_roles` docs.
   - Rules: add `hasAdminPermission(p)` (reads `admin_roles/{roleId}.permissions`
     + `admin_users.permissionOverrides`) and switch moderation/support/content
     collections from `isSuperAdminUser()` to the matching permission. Keep
     `admin_users`/`admin_roles` writes super-admin only.
3. **Mobile org/series management (the replacement for `apps/admin`)**
   Already in mobile: create org/series (`series_create_screen.dart`), settings
   (`series_settings_screen.dart`), admins (`series_admins_screen.dart`), approvals,
   clubs + club admins, registrations, add/remove player, propose match/tournament,
   competitions, rankings, audit log, orgs directory.
   To add (`lib/features/series/presentation/` + `lib/data/services/series_functions_service.dart`
   + `functions/src/series/seriesFunctions.js`):
   - Ownership transfer (`transferSeriesOwnership` callable; owner only; audit).
   - Reactivate/archive lifecycle for owners (today the only option is `suspendSeriesEntity`).
   - Org dashboard: member/club/match/competition counts plus recent activity
     (`series_org_dashboard_screen.dart`).
   - Member announcements to series members (callable that fans out FCM via
     existing notification utils, `series_notification_types.dart`).
   - Optional: role tiers on `series_admins` (`admin` / `scorer` / `viewer`) with
     `canManageSeries` checking the role.
4. **Rules changes (needs approval to deploy)**
   - Remove the `isOrgAdminUser()` branches (users, teams, players, matches,
     tournaments, grounds, organizations) after `apps/admin` is retired. Then
     restrict `organizations` to super-admin read only (or drop it).
   - Narrow `admin_users` read to own doc or super admin (and permissioned staff).
   - Mobile org features keep using the existing `series_*` rules + callables. New
     callables need no client-write rules.
5. **Retire `crickflow-admin` and `apps/admin` (needs approval)**
   - Remove the `admin` target from `firebase.admin.json` / `.firebaserc`, then
     `firebase hosting:disable --site crickflow-admin` (or delete the site).
   - Delete `apps/admin`, drop the org-only branches from `apps/admin_core`
     (`AdminAppType.organizationAdmin`, `adminOrgAccessProvider`,
     `organizationSuspended`, `organizations` feature), and update CI/workflows.
   - Move the one `roleId: admin` record (no org) to a platform role or revoke it.
