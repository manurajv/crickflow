# Continuity — Backup, DR & Migration

Business Continuity Center for CrickFlow Admin (`/continuity`).

> **Scope:** Super Admin only. Metadata & workflows — never auto-restores or overwrites production.

## Purpose

Provide a Google Cloud Backup / AWS Backup–style control plane so operators can:

1. Queue backup jobs (metadata for future Cloud workers)
2. Preview restores with validation notes
3. Follow recovery plans
4. Dry-run migrations
5. Verify platform health after incidents

## Safety rules

| Rule | Behavior |
|------|----------|
| Auto-restore | **Never** from the client |
| Auto-migration apply | **Never** — dry-run by default |
| Production overwrite | Requires future Cloud Function + typed Super Admin confirmation |
| Secrets | Never stored in backup metadata (no API keys, OAuth, Firebase credentials) |
| Org Admin | No nav/route access (`canManageContinuity` Super-only) |

## Backup strategy

Supported types (metadata): Firestore, Storage, Remote Config, platform settings, CMS, roles, permissions, feature flags, app config, full platform.

Frequencies prepared (no scheduler yet): Manual, Daily, Weekly, Monthly, Before deployment / migration / config change.

Each backup records: timestamp, environment, version, created by, collections list, estimated size, integrity status.

## Restore workflow

1. Select backup + scope  
2. Operator types `PREVIEW` + reason  
3. System writes `previewOnly: true` / `awaitingConfirmation`  
4. Validation notes cover integrity, compatibility, mapping, storage, permissions  
5. **Apply** is not implemented — future worker only

## Recovery plans

Default plans cover platform failure, Firestore/Storage/hosting/config/deployment failure, accidental deletion, and security incidents — with ETA, steps, and responsible roles.

## Migration / import / export

- Migration Center: dry-run queue only  
- Import Center / Export Center: architecture stubs (JSON/CSV/Excel + entity exports) — no implementation yet  

## Health verification

Checklist: Firestore, Storage, Hosting, Authentication, Cloud Functions, Remote Config, Permissions, Configuration.

## Collections

| Collection | Purpose |
|------------|---------|
| `admin_continuity_backups` | Backup metadata |
| `admin_continuity_restores` | Restore preview requests |
| `admin_continuity_migrations` | Migration jobs |
| `admin_continuity_plans` | Recovery plans |
| `admin_continuity_timeline` | Continuity events |
| `admin_continuity_settings/global` | Hub settings |

## Audit actions

`continuity.backup_created`, `continuity.backup_validated`, `continuity.backup_deleted`, `continuity.restore_requested`, `continuity.migration_started`, `continuity.plan_updated`, `continuity.validation_performed` (+ timeline kinds).

## Future integrations (no redesign)

Google Cloud Backup, Cloud Storage snapshots, BigQuery export, Firestore Export/Import, scheduled backups, cross-region DR, multi-region replication.

## Related

- Permission: `canManageContinuity`
- Screen: `ContinuityScreen`
- Schema: [ADMIN_USERS_SCHEMA.md](../ADMIN_USERS_SCHEMA.md)
