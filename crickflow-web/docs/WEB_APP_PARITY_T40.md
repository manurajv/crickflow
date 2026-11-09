# Web ↔ App parity matrix (t40u)

Status after the continuation pass that closed org hub, notifications, My Cricket, and directory gaps. Mobile remains source of truth for device-only flows.

| Area | Status | Notes |
|------|--------|-------|
| Home | Done | |
| Matches list / hub / scorecard | Done | Live scoring **mobile-only** |
| Tournaments | Done | |
| Teams / players | Done / Partial create | Create-team CTA remains strongest on app |
| Community / Discover | Done | |
| Notifications | **Done** | Priority / General tabs, unread badges, mark-all, related mark-read on open; approvals mark related pending-read |
| My Cricket | **Done** | Matches / Tournaments / Teams / Stats / Highlights hub (not a profile alias) |
| Search | Done | |
| Orgs directory | **Done** | Associations / Clubs / Series filter chips + back to All orgs |
| Org detail tabs | **Done** | Overview / Matches / Tournaments / Teams / Leaderboard / About; legacy players/approvals/clubs/fixtures/admins/dashboard → Overview or mapped tabs |
| Approvals / Admins pages | **Done** | Linked from Overview; not org tabs |
| Org Overview layout | **Done** | Status, pending approvals, description, stats, announcements (2)+See all, my requests, admins, recent activity (5)+See all |
| Tab FABs | **Done** | Start/Propose match on Matches; Start/Propose tournament on Tournaments; + Team on Teams — permission-aware |
| Approvals polish | **Done** | Type filter chips, rich cards, confirm, per-item loading, centered “All caught up” |
| Org settings | **Done** | Sticky Save (enabled when dirty), beforeunload + leave warn, full competitionPolicy + walk-ins + squad |
| Admin welcome tip | **Done** | After create (`?welcome=1`), admins only; Don’t show again via localStorage per uid; once per org |
| Guest + Sign in prompts | Done | |
| Stale match rule | Done | |
| Permissions engine | **Done** | `lib/cricket/org-competition-access.ts` + vitest |
| Theme / colors | Done | CfColors CSS vars |
| Navigation | Done | Primary + More; mobile bottom nav |

## Intentionally not on web (mobile-only)
- Live scoring / ball-by-ball scoring UI
- Camera capture for highlights
- Streaming studio / RTMP publish
- Store / IAP
- Push notification OS permissions (web uses in-app list)

## Feasible gaps still thinner than app (accepted for web)
- My Cricket ownership filters use recent public lists until personal match indexes are exposed on web
- Highlights tab deep-links completed matches rather than a dedicated clip feed
- Org announcements create UI stays admin/Firestore-backed; no rich editor parity

## Quality gate (this pass)
- `tsc --noEmit` pass
- `eslint` pass
- `vitest run` 195 pass
- `next build` (static export) pass
- Signed-out smoke on `/`, `/series`, `/matches`, `/my-cricket`, `/notifications`, `/login`, `/home`, `/discover`, `/series/_`, approvals/settings/admins shells — HTTP 200
