# Web ↔ App parity matrix (t40u)

Status after this pass. Mobile remains source of truth for device-only flows.

| Area | Before | After | Notes |
|------|--------|-------|-------|
| Home | Done | Done | |
| Matches list / hub / scorecard | Done | Done | Live scoring **Deferred** (device) |
| Tournaments | Done | Done | |
| Teams / players | Done / Partial create | Same | Create team stays app CTA |
| Community / Discover | Done | Done | |
| Notifications | Done | Partial | Priority/General tabs still thinner than app |
| My Cricket | Partial | Partial | Route exists; depth below app |
| Search | Done | Done | |
| Orgs directory | Partial | Partial | Associations/Clubs/Series filters still basic |
| Org detail tabs | Partial (overview/players/approvals/clubs/fixtures/admins) | Improved | Teams label; pending banner; permission actions |
| Org Overview (announcements, recent activity) | Missing | Partial | Pending approvals banner added; announcements/activity still thin |
| Tab FABs Start/Propose | Missing / Propose only for admins | **Done** (permission-aware Start/Request) | Uses ported OrgCompetitionAccess |
| Approvals UI polish | Partial | Partial | Filters/confirm still lighter than app |
| Org settings permissions | Missing | **Done** | updateSeriesCompetitionPolicy + walk-ins |
| Admin welcome tip | Missing | Missing | App-only tip (SharedPreferences) |
| Guest + Sign in prompts | Done | Done | |
| Stale match rule | Done | Done | |
| Org badge / Teams wording | Partial | Improved | Clubs → Teams on org detail |
| **Permissions engine** | Missing on web | **Done** | `lib/cricket/org-competition-access.ts` + vitest parity |
| Theme / colors | Close | **Closer** | CSS vars aligned to CfColors light/dark |
| Navigation | Crowded top nav | **Improved** | Primary + More; mobile bottom nav (Home/Matches/Orgs/Discover/Me) |

## Intentionally not on web
- Live scoring / streaming studio / camera
- Store / IAP
- Admin welcome “don’t show again” (local prefs)

## Still to deepen (not blocking deploy of this pass)
- Full org tab parity (Matches/Tournaments/Leaderboard/About as first-class tabs)
- Announcements + recent activity cards on Overview
- Approvals filter chips + confirm dialogs
- Notifications Priority/General exact layout
- Richer My Cricket / Associations·Clubs·Series directory chrome
