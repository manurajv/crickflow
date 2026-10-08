# Admin auth seed data (Firestore)

> **Update (2026-10-08): the Organization Admin panel (`apps/admin`, hosting site
> `crickflow-admin`) was retired.** `apps/superadmin` is the only web admin panel
> and is for CrickFlow platform staff (super admins, moderators, tournament admins,
> support, viewers); each role sees only what its permissions allow, and
> `firestore.rules` enforces the same permissions. Organization, club and series
> administration lives in the mobile app (`lib/features/series`). References to
> the Org Admin panel below are historical. See `docs/PLATFORM_ADMIN_SCOPE_PLAN.md`.

Additive collections only — do **not** change mobile `users`.

Firestore rules for `admin_users` / `admin_roles` are deployed to **crickflow-b06bc**.

## Create a Super Admin (recommended)

### 1. Create the Auth user

Firebase Console → [Authentication → Users](https://console.firebase.google.com/project/crickflow-b06bc/authentication/users) → **Add user**

- Email + password (or sign in once with Google on the Super Admin login page so Auth creates the user)

Copy the **User UID**.

### 2. Seed role definitions

Firestore → create collection `admin_roles` (if missing), then document **`superAdmin`**:

```json
{
  "label": "Super Admin",
  "description": "Platform owner — full access",
  "allowedPanel": "superAdmin",
  "isSystem": true,
  "permissions": {
    "canViewDashboard": true,
    "canViewProfile": true,
    "canManageAccount": true,
    "canManageUsers": true,
    "canManageTeams": true,
    "canManagePlayers": true,
    "canManageMatches": true,
    "canManageTournaments": true,
    "canManageGrounds": true,
    "canManageBroadcast": true,
    "canManageAds": true,
    "canModerateCommunity": true,
    "canSendNotifications": true,
    "canViewAnalytics": true,
    "canViewSystemHealth": true,
    "canManageSupport": true,
    "canManageAiOps": true,
    "canManageSecurity": true,
    "canManageDeployments": true,
    "canManageContinuity": true,
    "canManageCms": true,
    "canViewReports": true,
    "canManageSettings": true,
    "canViewLogs": true,
    "canManageOrganizations": true,
    "canAccessGlobalData": true,
    "canManageDiscover": true
  }
}
```

(Optional but recommended) Also add docs `admin`, `moderator`, `tournamentAdmin`, `support`, `viewer` — or run the seed script below.

If `admin_roles/superAdmin` is missing, the app still uses a built-in fallback permission map.

### 3. Link the admin profile

Create collection `admin_users`, document ID = **Auth UID** from step 1:

```json
{
  "email": "you@example.com",
  "displayName": "Platform Owner",
  "roleId": "superAdmin",
  "organizationId": null,
  "organizationName": null,
  "permissionOverrides": {},
  "isActive": true,
  "claimsVersion": 0
}
```

### 4. Sign in

```powershell
cd apps/superadmin
flutter run -d chrome
```

Use that email/password (or Google with the same account).

---

## CLI seed (optional)

Requires [Application Default Credentials](https://cloud.google.com/docs/authentication/application-default-credentials) (`gcloud auth application-default login`).

```powershell
# Seed all admin_roles only
node scripts/seed-admin-roles.cjs

# Seed roles + create/link Super Admin Auth user
node scripts/seed-admin-roles.cjs --email you@example.com --password "YourSecurePass!" --name "Platform Owner"
```

---

## Org Admin note

Retired. The `admin` role has no panel; the one legacy record was revoked on
2026-10-08 (reason "org admin panel retired"). Organization / club / series
admins are managed in the mobile app (`series_admins`, `series_club_admins`).

## Admins & Access (Super Admin panel)

Route `/admins` in `apps/superadmin` (nav: Management > Admins & Access,
permission `canManageSecurity`). Manages platform staff in `admin_users/{uid}`:

| Action | Writes |
|--------|--------|
| Add admin (by email or Auth UID) | New doc: `email`, `displayName`, `roleId`, `permissionOverrides`, `isActive: true`, `accessStatus: active`, `createdAt/By`, `updatedAt/By`, `claimsVersion` +1 (`organizationId` / `organizationName` are written as null) |
| Change role / overrides | Same fields, `permissionOverrides` replaced wholesale |
| Suspend | `isActive: false`, `accessStatus: suspended`, `statusReason`, `statusChangedAt/By` |
| Revoke | `isActive: false`, `accessStatus: revoked` (doc kept; rules deny delete) |
| Restore | `isActive: true`, `accessStatus: active` |

Every change writes `admin_audit_logs` (`admin.access_granted`, `admin.access_updated`,
`admin.suspended`, `admin.revoked`, `admin.reactivated`).

Guards (client): you cannot change your own role or status, and the last active Super
Admin cannot be demoted, suspended or revoked. Only roles with
`allowedPanel: superAdmin` can be assigned. On the server, only `isSuperAdminUser()` may
write `admin_users`.

The person must already have a Firebase Auth account (mobile app, website, or Google /
email on the admin login page). The Access denied page shows their UID to share.

### Platform staff roles and rules (2026-10-08)

`superAdmin`, `moderator`, `tournamentAdmin`, `support` and `viewer` all have
`allowedPanel: superAdmin`. The panel shows only the nav items and actions their
permissions allow, and the landing page is the dashboard, or Profile if they have no
dashboard.

`firestore.rules` checks the same permissions with `hasAdminPermission(p)`. A permission
is resolved in this order:

1. `admin_users.permissionOverrides[p]`
2. `admin_roles/{roleId}.permissions[p]`
3. The built-in default (`builtinAdminRolePermissions`, which mirrors
   `DefaultAdminRolePermissions`)

Super Admins have every permission. Inactive, suspended or revoked records (`isActive`
false, or `accessStatus` not `active`) and the retired `admin` role get none.

| Data | Permission |
|------|------------|
| Community moderation, post delete, reports | `canModerateCommunity` (reports also `canViewReports`) |
| Discover/opportunity moderation | `canManageDiscover` or `canModerateCommunity` |
| `users` admin fields | `canManageUsers` |
| `teams` / `players` / `matches` / `tournaments` admin fields | `canManageTeams` / `canManagePlayers` / `canManageMatches` / `canManageTournaments` |
| `grounds` | `canManageGrounds` |
| `notifications` read (all), `admin_notification_*` | `canSendNotifications` (read also `canViewSystemHealth`) |
| `home_promotions` | `canManageAds` or `canSendNotifications` |
| `admin_ad*`, `admin_advertisers`, `admin_sponsored_content` | `canManageAds` |
| `admin_support_*` | `canManageSupport` |
| `admin_ai_*` | `canManageAiOps` |
| `admin_security_*` | `canManageSecurity` |
| CMS / legal page writes | `canManageCms` |
| `admin_audit_logs` read | `canViewLogs`, `canManageSecurity` or `canManageUsers` |
| `admin_users` read (others) | `canManageUsers` or `canManageSecurity` |
| Org moderation (`series` status + `platformHold`, `series_clubs` suspend/restore, series approvals/registrations/audit reads) | `canManageOrganizations` |
| `organizations` (legacy, unused) | Super Admin only |

Emulator tests for all of this are in `firestore-tests/`.

## Custom claims (later)

Cloud Function can set `adminRoleId` / `organizationId` on the ID token. Client already refreshes tokens after login.

## User Management (additive fields)

Admin panels read mobile `users/{uid}` and may **merge** only these admin-managed fields (Firestore rules enforce key allow-list):

| Field | Purpose |
|-------|---------|
| `accountStatus` (also mirrored as `status`) | Soft lifecycle: `active` / `suspended` / `banned` / `deleted` / `pendingVerification` / `inactive` |
| `deletedAt` | ISO timestamp when soft-deleted (cleared on restore) |
| `deletedBy` | Admin UID who soft-deleted (cleared on restore) |
| `adminVerified` | Platform verification badge |
| `organizationId` | Org Admin scoping (empty until orgs assigned) |
| `lastLoginAt` | Optional; used for Online summary |
| profile edits | `displayName`, `mobile`/`phoneNumber`, `bio`, `country`, `location`, `updatedAt` |

**Soft delete only:** Admin User Management never hard-deletes `users/{uid}`. Soft-deleted profiles keep match history, teams, tournaments, scorecards, and stats intact and can be restored.

## Tournament Management (additive fields)

Admin panels read mobile `tournaments/{id}` and may merge only:

| Field | Purpose |
|-------|---------|
| `adminFeatured` | Platform featured flag |
| `adminApprovalStatus` | `pending` / `approved` / `rejected` |
| `adminRecordStatus` | Soft lifecycle: `active` / `deleted` / `archived` |
| `adminDeletedAt` / `adminDeletedBy` | Soft-delete metadata |
| `organizationId` | Org Admin scoping |
| Managed edits | `status` (cancel), `name`, `description`, `entryFee`, `winningPrize`, `updatedAt` |

Mobile tournament create/edit flows are unchanged. Soft-delete never removes the tournament document (matches, points, history stay).

## Match Management (additive fields)

Admin panels read mobile `matches/{id}` and may merge only:

| Field | Purpose |
|-------|---------|
| `adminFeatured` | Platform featured flag for operational surfacing |
| `adminPaused` | Admin-only monitoring pause state; does not touch scoring engine |
| `adminStatus` | Admin-side overlay state such as `cancelled` / `delayed` when needed |
| `adminRecordStatus` | Soft lifecycle: `active` / `deleted` / `archived` |
| `adminDeletedAt` / `adminDeletedBy` | Soft-delete metadata |
| `organizationId` | Org Admin scoping |
| Managed edits | `status` (abandoned), `title`, `venue`, `updatedAt` |

**Scoring is off-limits:** Admin Match Management must never overwrite `ball_events`, `innings`, runs, wickets, overs, dismissals, or player statistics. Those remain scorer-controlled. Streaming implementation and overlays also remain untouched.

## Team Management (additive fields)

Admin panels read mobile `teams/{id}` and may merge only:

| Field | Purpose |
|-------|---------|
| `adminFeatured` | Platform featured flag |
| `adminVerified` | Platform verification badge |
| `adminStatus` | Soft lifecycle: `active` / `pendingVerification` / `verified` / `suspended` |
| `adminRecordStatus` | Soft lifecycle: `active` / `deleted` / `archived` |
| `adminDeletedAt` / `adminDeletedBy` | Soft-delete metadata |
| `adminCategory` | Optional classification (club / school / university / …) |
| `adminBallType` | Optional ball preference for admin filtering |
| `organizationId` | Org Admin scoping |
| Managed edits | `name`, `coachName`, `contactNumber`, `updatedAt` |

**Do not touch from admin:** `playerIds`, `memberCount`, `captainId`, `viceCaptainId`, `createdBy`, `stats.*`, `teamCode`, `qrUrl`, `profileViewsCount`, roster/follow graph.

Mobile team create/edit and Team Profile UI are unchanged. Soft-delete never removes the team document.

## Ground Management (`grounds` collection)

Additive admin registry and/or **derived catalog** from tournament `grounds[]`
(free-text names). Location fields come from each tournament’s `location` map
(city / state / country / coords). Match `venue` is **not** used.

| Field | Purpose |
|-------|---------|
| `name`, `groundCode`, `description` | Identity |
| `photoUrl`, `galleryUrls` | Media |
| `address`, `city`, `stateProvince`, `country`, `pinCode` | Location text |
| `latitude`, `longitude` | Map / nearby-ready coordinates |
| `contactPerson`, `contactNumber`, `email`, `website` | Contact |
| `ownerId`, `ownerName` | Owner linkage |
| `groundType`, `pitchType`, `ballTypes`, `availability` | Classification |
| `facilities`, `floodlights`, `parking`, `capacity`, `boundarySize` | Amenities |
| `matchesHosted`, `rating`, `reviewCount` | Aggregate stats (admin / future sync) |
| `tournamentIds` | Tournaments that list this ground name |
| `source` | `tournament` (derived) or `registry` (manual admin create) |
| `adminFeatured` | Platform featured flag |
| `adminVerified` | Platform verification badge |
| `adminStatus` | `active` / `pendingVerification` / `verified` / `suspended` |
| `adminRecordStatus` | Soft lifecycle: `active` / `deleted` / `archived` |
| `adminDeletedAt` / `adminDeletedBy` | Soft-delete metadata |
| `organizationId` | Org Admin scoping (required for org-admin create) |
| `createdBy`, `createdAt`, `updatedAt` | Provenance |

Admin Ground Management lists unique tournament grounds automatically. Admin
actions (verify, feature, …) materialize a `grounds/{stableId}` doc on first
write. Mobile tournament create/edit flows are unchanged.

Audit actions: `ground.created`, `ground.edited`, `ground.verified`, `ground.unverified`, `ground.suspended`, `ground.unsuspended`, `ground.featured`, `ground.unfeatured`, `ground.soft_deleted`, `ground.restored`, `ground.archived`.

## Broadcast Management (monitor `matches.stream`)

Read-only monitor of mobile stream metadata on `matches/{id}.stream`. No separate broadcasts collection. Streaming engine / YouTube / Facebook / RTMP / OAuth / overlays are untouched.

| Shown | Source |
|-------|--------|
| Status / platform / watch URLs | `stream.status`, `stream.destination`, `youtubeWatchUrl` |
| Heartbeat / health proxy | `stream.lastHeartbeatAt` (stale >90s → Poor while live) |
| Orientation / cameras / viewers | `broadcastOrientation`, labels, `viewerCount` |
| Admin feature / soft-delete | Existing `adminFeatured`, `adminRecordStatus` on match |

**Never expose in UI:** `stream.streamKey`, raw `stream.rtmpUrl` path/key, `streaming_credentials/*` OAuth tokens.

**Never allow from admin:** stop/end live stream (mobile-only control).

Audit actions: `broadcast.featured`, `broadcast.unfeatured`, `broadcast.soft_deleted`, `broadcast.restored`, `broadcast.archived`.

## Community & Discover Moderation

Admin-only moderation hub (`ModerationScreen`) at `/community` and `/discover`. Mobile Community/Discover feeds, create flows, chats, and APIs are unchanged.

| Surface | Collection | Admin behavior |
|---------|------------|----------------|
| Community posts | `community_posts` | Soft status via additive `adminStatus`, `adminFeatured` (mobile ignores until wired) |
| Discover posts | `opportunity_posts` | Uses existing `status` / `isFeatured` / `isPinned` |
| Reports | `community_post_reports`, `opportunity_post_reports` | Resolve / dismiss; status updates only |
| Chats | `chats` | Metadata only — never message bodies |

Permissions: `canModerateCommunity`, `canManageDiscover`. Org admins scoped by `organizationId` when present.

**Never expose:** private chat message content (only when a separate reported-message flow exists).

Audit actions: `community.hidden`, `community.removed`, `community.restored`, `community.archived`, `community.approved`, `community.featured`, `community.unfeatured`, plus discover / report equivalents.

## Notification & Announcement Management

Admin hub (`NotificationsScreen`) at `/notifications`. Mobile inbox generation, FCM bridge (`onNotificationCreated`), and client token registration are unchanged.

| Surface | Collection | Admin behavior |
|---------|------------|----------------|
| Campaigns / scheduled / history | `admin_notification_campaigns` | Draft, schedule, queue, archive; org-scoped via `organizationId` |
| Templates | `admin_notification_templates` | Reusable copy |
| Segments | `admin_notification_segments` | Audience definitions (future fan-out) |
| Announcements | `home_promotions` | CRUD carousel ads/announcements |
| Auto notifications | `notifications` | Read-only monitor |

**Send behavior:** Specific users (≤50) write in-app `notifications` docs (existing FCM bridge may push). Larger audiences are **queued** for a future delivery worker — admin never reads `users.fcmToken`.

Permission: `canSendNotifications`.

Audit actions: `notification.created`, `notification.edited`, `notification.scheduled`, `notification.cancelled`, `notification.sent`, `notification.queued`, `notification.duplicated`, `notification.archived`, `notification.deleted`, plus announcement / template / segment keys.

## Advertisement Management

Admin hub (`AdsScreen`) at `/ads`. Mobile AdMob (`AdMobConfig`, `google_mobile_ads`, banner placements) is unchanged.

| Surface | Collection | Admin behavior |
|---------|------------|----------------|
| Campaigns / custom ads | `admin_ad_campaigns` | Draft → approval → active/pause/archive; org-scoped |
| Advertisers | `admin_advertisers` | Company profiles |
| Sponsored content | `admin_sponsored_content` | Promote tournament/team/post/etc. |
| AdMob config mirror | `admin_admob_config/settings` | Unit IDs / test mode for future sync — not read by mobile yet |
| Home carousel | `home_promotions` | Approved home-placement ads sync as `kind: advertisement` |

Permission: `canManageAds`.

**Never store:** AdMob publisher secrets / OAuth. Unit IDs only.

Audit actions: `ad.created`, `ad.approved`, `ad.rejected`, `ad.paused`, `ad.resumed`, `ad.archived`, `ad.deleted`, `admob.config_updated`, plus advertiser / sponsored keys.

## Orgs & Series oversight

Superadmin route `/orgs` ("Orgs & Series", permission `canManageOrganizations`). Read and
moderate the mobile org model (`series` with `kind`, `series_admins`, `series_clubs`,
`series/{id}/approvals`, `series_audit_logs`).

| Action | Writes |
|--------|--------|
| Suspend / archive org | `series.status` = `suspended` / `archived`, `platformHold: true`, `updatedAt` |
| Restore org | `series.status: active`, `platformHold: false` |
| Suspend / restore club | `series_clubs.status` = `suspended` / `approved` |

Every action writes `series_audit_logs` (`ENTITY_SUSPENDED` / `ENTITY_ARCHIVED` /
`ENTITY_RESTORED`, actorRole `platformAdmin`) and `admin_audit_logs` (`org.*`). While
`platformHold` is true, owners can't reactivate, archive or transfer the org from the
mobile app.

The legacy `organizations/{id}` collection (0 docs) is locked to Super Admin and has no
UI.

## Analytics & Reports

Read-only hub at `/analytics` (`AnalyticsScreen`, permission `canViewAnalytics`). Does not mutate mobile collections or scoring/streaming APIs.

| Concern | Behavior |
|---------|----------|
| Super Admin | Platform-wide counts + optional organizationId filter |
| Org Admin | Forced `organizationId` scope — never global totals |
| Data source | Firestore `count()` + capped samples (≤400/collection) + short TTL cache |
| Charts | `fl_chart` line/bar cards |
| Export | CSV (clipboard) now; Excel/PDF/scheduled email stubs |
| Future | Swap `AnalyticsRepository` for BigQuery / AdMob / billing warehouse without UI redesign |

Admin platform roles stay in `admin_users` — never overwrite mobile `users.role`.

Audit trail: `admin_audit_logs` (create by active admin; immutable). Action key for soft delete: `user.soft_deleted`.

## CMS & Platform Settings

Hubs: `/settings` (`SettingsScreen`, `canManageSettings`) and `/cms` (`CmsScreen`, `canManageCms`). **Writes are Super Admin only** (UI + Firestore rules). Org Admin may read when permission is granted.

| Collection | Purpose |
|------------|---------|
| `admin_platform_settings/global` | General, branding, contact, social, system prefs |
| `admin_feature_flags/{key}` | Feature toggles |
| `admin_remote_config/{key}` | Remote config mirror (Firebase RC integration later) |
| `admin_app_versions/{id}` | Soft / force update history |
| `admin_maintenance/current` | Maintenance mode |
| `admin_cms_pages/{kind}` | CMS content pages |
| `admin_legal_pages/{kind}` | Legal **content only** — never stores or overwrites Privacy/Terms URLs |

**Never modified by this module:** Privacy Policy URL, Terms URL, OAuth, live streaming, overlays, notification logic, Firebase project config, API secrets.

Audit actions: `settings.updated`, `feature_flag.enabled` / `.disabled`, `remote_config.updated` / `.deleted`, `app_version.updated`, `maintenance.started` / `.ended` / `.updated`, `cms.page_updated`, `legal.page_updated`.

## Audit Logs & Activity Monitoring

Hub at `/logs` (`AuditScreen`, permission `canViewLogs`). Reads immutable `admin_audit_logs` written by every admin module.

| Concern | Behavior |
|---------|----------|
| Super Admin | Platform-wide logs + filters |
| Org Admin | Scoped to `metadata.organizationId` — never platform-wide |
| Write path | Existing module `_writeAudit` + shared `AuditLogger` (auth + future modules) |
| Sections | Dashboard, Timeline, Audit Logs, Login History, Security, Permissions, Data Changes, System, Export |
| Immutability | Firestore rules: create by actor only; **update/delete false** |
| Secrets | Never logged (passwords, tokens, API keys stripped) |

Auth actions: `auth.login_success`, `auth.login_failed`, `auth.logout`, `auth.password_reset_requested`.

## System Monitoring & Platform Health

Read-only hub at `/monitoring` (`MonitoringScreen`, permission `canViewSystemHealth`). Operations-center UI only — does **not** deploy, stop streams, mutate Firebase config, or expose secrets.

| Concern | Behavior |
|---------|----------|
| Super Admin | Platform-wide probes + service status mirrors |
| Org Admin | Forced `organizationId` scope — never global infrastructure totals |
| Data source | Firestore `count()` / capped samples + 2‑min TTL cache (no permanent listeners) |
| Sections | Overview, Firebase Services, Live Status, Firestore, Auth, Functions, Storage, Hosting, FCM, Streaming (monitor only), Database, Performance, Errors, Scheduled Jobs, Background Tasks, Health Timeline |
| Streaming | Health metrics only — **no** stream control |
| Hosting | Domain status display (`admin.crickflow.app`, `superadmin.crickflow.app`) — **never** deploys |
| Alerts | Architecture ready (email / push / Slack stubs) — not implemented |
| Future | Swap `MonitoringRepository` for Cloud Monitoring, Crashlytics, BigQuery, Grafana, Datadog, Sentry without UI redesign |

Health timeline / errors derive from `admin_audit_logs` (failed / security / maintenance / settings events). Scheduled jobs are architecture placeholders only.

## Support Center & Ticket Management

Help desk hub at `/support` (`SupportScreen`, permission `canManageSupport`). Additive collections only — does **not** touch community chats, private messaging, mobile feedback APIs, or existing report systems.

| Collection | Purpose |
|------------|---------|
| `admin_support_tickets` | Tickets (+ `messages` subcollection for support threads / internal notes) |
| `admin_support_kb` | Knowledge-base articles (draft / publish / archive) |
| `admin_support_faqs` | FAQ Q&A + keywords (separate from CMS FAQ page) |
| `admin_support_announcements` | Known issues, maintenance, disruptions |
| `admin_support_meta` | Ticket sequence counters |

| Concern | Behavior |
|---------|----------|
| Super Admin | All tickets + org filter |
| Org Admin | Forced `organizationId` scope |
| Support role | Assigned tickets only (unless broader perms) |
| Internal notes | `visibility: internal` — never for end users |
| Streaming / chat | Monitor-style tickets only — no stream control; no private chats |
| Export | CSV now; Excel/PDF stubs |
| Future | Email / WhatsApp / Slack / Discord / CRM / AI assistant via `channel` field |

Audit actions: `support.ticket_created`, `.ticket_assigned`, `.ticket_transferred`, `.ticket_escalated`, `.ticket_resolved`, `.ticket_closed`, `.ticket_reopened`, `.internal_note_added`, `.kb_updated`, `.faq_updated`, `.announcement_updated`.

## AI Operations & Automation Center

Hub at `/ai-ops` (`AiOpsScreen`, permission `canManageAiOps`). Future-ready operations intelligence — **not a chatbot**. No external AI APIs are called from the client; providers plug in later via `AiProviderAdapter` + Cloud Functions.

| Collection | Purpose |
|------------|---------|
| `admin_ai_recommendations` | Recommendation queue (approve / reject / archive) |
| `admin_ai_rules` | Automation rules + `workflowGraph` for future visual builder |
| `admin_ai_jobs` | Scheduled / manual batch scan jobs |
| `admin_ai_logs` | AI ops activity (immutable-ish create) |
| `admin_ai_settings/global` | Feature flags; mirrors `admin_feature_flags` |

| Concern | Behavior |
|---------|----------|
| Super Admin | Platform-wide + AI settings write + seed demo queue |
| Org Admin | Org-scoped recommendations / rules only |
| Auto-mutate | **Never** — every recommendation needs admin approval |
| Secrets | Provider API keys never stored in admin client |
| Performance | No continuous Firestore scans — job queue for Cloud Functions |
| Providers | OpenAI / Gemini / Vertex / Firebase AI / Azure / Claude / Local registry stubs |

Audit: `ai.recommendation_*`, `ai.rule_*`, `ai.job_scheduled`, `ai.settings_updated`.

## Security Operations Center (SOC)

Hub at `/security` (`SecurityScreen`, permission `canManageSecurity`). Platform security, access control, and disaster-recovery architecture — **not** mobile auth or Firebase project reconfiguration.

| Collection | Purpose |
|------------|---------|
| `admin_security_alerts` | Security alerts (severity / status / affected user) |
| `admin_security_blocks` | Block lists (users, devices, emails, IPs, domains) |
| `admin_security_ips` | IP whitelist / blacklist / country rules (Super Admin write) |
| `admin_security_devices` | Device registry (trusted / re-verify ready) |
| `admin_security_access` | Temporary / emergency / read-only access grants |
| `admin_security_backups` | Backup schedule metadata only |
| `admin_security_restores` | Restore points / history (preview only) |
| `admin_security_sessions` | Optional session registry (terminate marks docs) |
| `admin_security_policies/global` | Password / session / lockout policy flags |

Also reuses `admin_roles` (Super Admin CRUD via Security Center) and `admin_audit_logs` for login sessions / threat signals.

| Concern | Behavior |
|---------|----------|
| Super Admin | Roles, IP rules, policies, backup metadata writes; platform-wide views |
| Org Admin | Org-scoped alerts / blocks / sessions / grants where `organizationId` present |
| Secrets | Never stores or displays passwords, OAuth tokens, API keys, Firebase / AdMob / YouTube / Facebook credentials |
| Restore | Architecture + preview only — **no** destructive restore from client |
| Backup | Metadata / schedule stubs — does **not** trigger Firebase backups |
| Threats | Recommendations only — no auto-mutation |
| Sessions | Derived from audit + optional registry; terminate writes audit |
| Future | App Check, Cloud Armor, reCAPTCHA Enterprise, SSO, 2FA, Security Center APIs without redesign |

Audit: `security.role_*`, `security.permission_changed`, `security.session_terminated`, `security.block_added`, `security.ip_*`, `security.access_granted`, `security.backup_created`, `security.policy_updated`, plus existing `security.*` / `auth.*` events.

## DevOps & Release Center

Hub at `/devops` (`DevOpsScreen`, permission `canManageDeployments`). **Super Admin only** — not wired into Org Admin nav. Metadata and monitoring only.

| Collection | Purpose |
|------------|---------|
| `admin_devops_releases` | Release drafts / notes / status |
| `admin_devops_deployments` | Deployment log events (CI later) |
| `admin_devops_builds` | Build monitor stubs |
| `admin_devops_rollouts` | Gradual rollout plans (Remote Config later) |
| `admin_devops_rollbacks` | Prepared rollback intents (never auto-executes) |
| `admin_devops_domains` | Domain / SSL / DNS monitor entries |
| `admin_devops_env_vars` | Env **key** metadata only (values never stored) |
| `admin_devops_timeline` | Release / env timeline |
| `admin_devops_settings/global` | Active env, versions, quality gates |

| Concern | Behavior |
|---------|----------|
| Auto-deploy | **Never** — no Firebase Hosting / Cloud Build / GitHub Actions trigger from client |
| Auto-rollback | **Never** — prepare architecture only |
| Secrets | Env vars show masked placeholders; OAuth / Firebase credentials never stored |
| Org Admin | No access (`canManageDeployments` Super Admin only) |
| Future | GitHub Actions, Firebase CLI, Cloud Build, Cloud Deploy, Vercel, Netlify adapters |

Audit: `devops.release_*`, `devops.feature_rollout`, `devops.rollback_prepared`, `devops.environment_updated`, `devops.env_var_meta_updated`.

## Continuity & Disaster Recovery Center

Hub at `/continuity` (`ContinuityScreen`, permission `canManageContinuity`). **Super Admin only** — not wired into Org Admin nav. Metadata and safe workflows only — see [developer/continuity.md](developer/continuity.md).

| Collection | Purpose |
|------------|---------|
| `admin_continuity_backups` | Backup job metadata (no payloads / secrets) |
| `admin_continuity_restores` | Restore preview requests (`previewOnly`) |
| `admin_continuity_migrations` | Migration dry-runs / planned jobs |
| `admin_continuity_plans` | Recovery plans |
| `admin_continuity_timeline` | Continuity timeline |
| `admin_continuity_settings/global` | Hub settings |

| Concern | Behavior |
|---------|----------|
| Auto-restore | **Never** — preview + typed confirmation only |
| Auto-migration | **Never** — dry-run by default |
| Secrets | Never stored in continuity documents |
| Org Admin | No access (`canManageContinuity` Super Admin only) |
| Future | Google Cloud Backup, Firestore Export/Import, schedules, multi-region DR |

Audit: `continuity.backup_*`, `continuity.restore_requested`, `continuity.migration_started`, `continuity.plan_updated`, `continuity.validation_performed`.


### Scope note (2026-10-08)

The Super Admin panel is for platform staff only. Organization, club and series
administration lives in the mobile app (`series_admins`, `series_club_admins`).
Admins & Access no longer offers organization-scoped roles for new grants. See
`docs/PLATFORM_ADMIN_SCOPE_PLAN.md`.
