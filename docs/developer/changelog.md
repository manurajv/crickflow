# Changelog

All notable changes to the **CrickFlow Admin** ecosystem.

Format: version, date, summary. Breaking changes called out explicitly.

## Unreleased

### Added

- Continuity & Disaster Recovery Center (`/continuity`, Super Admin)
- Admin CI/CD architecture (GitHub Actions PR/main/security/release + **manual** deploy)
- `firebase.admin.json` Hosting targets (mobile Hosting untouched)
- `AdminEnvConfig` / environment matrix (`config/admin/environments.yaml`)
- Developer Documentation handbook (`docs/developer/`)
- In-app Developer Docs Center (`/docs`, Super Admin)
- Accessibility + i18n/l10n foundation (en/si/ta/hi, ar RTL scaffold)
- Enterprise QA report + Critical/High fixes (SOC org session filter, reports any-of, controller leaks)
- DevOps & Release Center (Super Admin)
- Security Operations Center
- Production readiness (cache, query limits, one-shot details)

## 0.1.0 — 2026-07

### Added

- Super Admin + Organization Admin Flutter web apps
- Shared `admin_core` (auth, shell, permissions, design system)
- Feature hubs: dashboard, users, orgs, teams, tournaments, matches, grounds, broadcasts, moderation, ads, notifications, support, analytics, CMS, audit, AI ops, monitoring, settings
- Additive Firestore admin collections + rules
- Provision script for Super Admin

### Notes

- Mobile app remains a separate codebase (`lib/`).
- Admin authorization uses `admin_users` / `admin_roles`, not mobile roles.

## Migration notes

- When adding permissions: update enum, defaults, provision script, routes, nav, rules.
- When adding collections: update `AdminCollections`, rules, this handbook, IMPLEMENTATION_STATUS.
