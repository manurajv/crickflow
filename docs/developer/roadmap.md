# Roadmap

## Purpose

Track Admin platform direction without committing to dates.

## Completed

- Dual-panel architecture (`superadmin` / `admin` / `admin_core`)
- Auth + RBAC + route guards
- Major management & moderation hubs
- Design system + production cost controls
- Security Center + DevOps Release Center
- Continuity & DR Center (backup/restore metadata — never auto-restore)
- i18n/a11y foundation
- Developer documentation module

## In progress

- Incremental ARB migration for remaining module strings
- Firestore audit log org-rule hardening (queries + indexes)
- Broader automated test coverage

## Planned

- Staging Firebase project / environment banner
- Export pipelines (CSV/Excel/PDF) using `AdminExportLocalizer`
- Custom claims sync for rules
- Widgetbook for `Cf*` components
- ~~CI: analyze + test + web preview hosting~~ → **Done** ([cicd.md](cicd.md)); preview channels optional next
- Additional languages (fr, es, de, pt, zh, ja, ur, he)

## Future ideas

- Admin GraphQL/HTTPS gateway
- Advanced threat detection integrations (architecture-only today)
- Deeper Maps/Places ground tooling
- Command palette across all modules
- Accessibility audit automation (axe / screen reader CI)

## Non-goals (preserve)

- Rewriting mobile scoring / streaming / FCM generation from admin PRs
- Auto-deploy / auto-rollback without human confirmation
- Storing secrets in Firestore or client docs
