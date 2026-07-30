# Feature Documentation

## Purpose

Catalog every admin hub: purpose, architecture, data, permissions, navigation.

## Shared hub pattern

```text
features/<name>/
  data/<name>_repository.dart
  models/
  providers/<name>_providers.dart
  presentation/<name>_screen.dart
  presentation/widgets/
```

Permissions: `AdminPermission` + route map + `PermissionGate`.  
Nav: `apps/admin` / `apps/superadmin` `nav_config.dart`.

---

## Dashboard

| | |
|--|--|
| **Purpose** | KPIs, quick links, recent activity |
| **Route** | `/` |
| **Permission** | `canViewDashboard` |
| **Data** | Aggregated counts via dashboard repository (scoped for Org) |
| **Realtime** | Refresh / one-shot |

## Users

| | |
|--|--|
| **Purpose** | Manage mobile user accounts (status, verification, org link) |
| **Route** | `/users` |
| **Permission** | `canManageUsers` |
| **Collections** | `users`, audit |
| **UI** | Table, filters, detail panel |

## Organizations

| | |
|--|--|
| **Purpose** | Super Admin CRUD for boards/clubs/academies |
| **Route** | `/organizations` |
| **Permission** | `canManageOrganizations` |
| **Collections** | `organizations` |

## Teams / Players / Grounds / Tournaments / Matches

| Feature | Route | Permission | Notes |
|---------|-------|------------|-------|
| Teams | `/teams` | `canManageTeams` | Mobile `teams` |
| Players | `/players` | `canManagePlayers` | List + detail; soft admin meta |
| Grounds | `/grounds` | `canManageGrounds` | Catalog + map preview; TTL cache |
| Tournaments | `/tournaments` | `canManageTournaments` | Additive admin fields |
| Matches | `/matches` | `canManageMatches` | Live detail allowed; no scoring engine changes |

## Broadcasts

| | |
|--|--|
| **Purpose** | **Monitor** streams / metadata |
| **Route** | `/broadcast` |
| **Permission** | `canManageBroadcast` |
| **Non-goals** | Do not control RTMP/YouTube/Facebook/scorebug |

## Community / Discover / Reports

| Feature | Route | Permission |
|---------|-------|------------|
| Community | `/community` | `canModerateCommunity` |
| Discover | `/discover` | `canManageDiscover` |
| Reports queue | `/reports` | any of viewReports / community / discover |

Moderation: posts, reports, chats metadata — no message body exfiltration.

## Advertisements

| | |
|--|--|
| **Route** | `/ads` |
| **Permission** | `canManageAds` |
| **Collections** | `admin_ad_campaigns`, advertisers, AdMob config, sponsored |

## Revenue

| | |
|--|--|
| **Route** | `/revenue` |
| **Permission** | `canAccessGlobalData` (**Super Admin** only) |
| **Collections** | reads ads/sponsored estimates; optional `admin_revenue_ledger` |
| **Non-goals** | No payment gateway, card charging, or live AdMob/Stripe API calls from the client |

## Notifications

| | |
|--|--|
| **Route** | `/notifications` |
| **Permission** | `canSendNotifications` |
| **Collections** | `admin_notification_*` |
| **Non-goals** | Do not modify mobile FCM generation pipelines |

## Support / Analytics / CMS / Audit

| Feature | Route | Permission |
|---------|-------|------------|
| Support | `/support` | `canManageSupport` (messages may be realtime) |
| Analytics | `/analytics` | `canViewAnalytics` |
| CMS | `/cms` | `canManageCms` |
| Audit logs | `/logs` | `canViewLogs` |

## Security / AI / Monitoring / DevOps / Settings

| Feature | Route | Permission | Notes |
|---------|-------|------------|-------|
| Security | `/security` | `canManageSecurity` | Org: scoped sections only |
| AI Center | `/ai-ops` | `canManageAiOps` | |
| Monitoring | `/monitoring` | `canViewSystemHealth` | |
| DevOps | `/devops` | `canManageDeployments` | **Super Admin app only** |
| Continuity & DR | `/continuity` | `canManageContinuity` | **Super Admin only** — never auto-restore |
| Settings | `/settings` | `canManageSettings` | Writes often Super-only |
| Developer Docs | `/docs` | authenticated Super Admin panel | This handbook |

## Profile / Account

| Route | Permission |
|-------|------------|
| `/profile` | `canViewProfile` |
| `/account-settings` | `canManageAccount` |

## Best practices

- Document new features here when shipping.
- Keep Super-only modules out of Org router/nav.

## Common mistakes

- Enabling destructive match actions for Org roles without product intent.
- Mixing broadcast **control** into monitoring UI.
