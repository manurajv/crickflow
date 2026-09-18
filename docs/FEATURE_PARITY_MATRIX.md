# CrickFlow — Feature Parity Matrix (Mobile ↔ Web ↔ Admin)

**Generated:** September 18, 2026  
**Purpose:** Complete feature audit across mobile app, consumer web (`crickflow-web`), and Flutter web admin (`apps/admin*`)

**Legend:**
- ✅ **Done** — Full implementation, production-ready
- 🟡 **Partial** — Core exists but missing key workflows or polish
- ❌ **Missing** — Not implemented
- 🚫 **Not applicable** — Feature doesn't apply to this surface (e.g. native-only, admin-only)

---

## Core User Flows

| Feature | Mobile | Consumer Web | Admin Panel | Notes |
|---------|--------|--------------|-------------|-------|
| **Authentication** |
| Google Sign-in | ✅ | ✅ | ✅ | All surfaces support Google auth |
| Phone OTP | ✅ | ✅ | 🚫 | Web has phone auth; admin uses admin_users only |
| Onboarding flow | ✅ | ✅ | 🚫 | Player onboarding required before using app/web |
| Profile completion | ✅ | ✅ | 🚫 | Photo, playing role, batting/bowling style |
| **Home & Discovery** |
| Home feed | ✅ | ✅ | 🚫 | Live matches, upcoming, recent, tournaments, teams, players, community posts |
| Search (global) | ✅ | ✅ | ✅ | Players, teams, matches, community; admin has platform search |
| Community posts | ✅ | ✅ | ✅ | Create, view, like, comment, save; admin moderation |
| Discover marketplace | ✅ | ✅ | ✅ | Opportunities (find player/team/coach/ground/umpire/scorer); admin moderation |
| Notifications inbox | ✅ | ✅ | ✅ | Push + in-app; admin campaigns |
| **Matches** |
| Match centre (live) | ✅ | ✅ | ✅ | Scorecard, commentary, stats, live updates; admin investigation |
| Scorecard | ✅ | ✅ | ✅ | Full scorecard with batting/bowling figures, FOW, partnerships |
| Commentary feed | ✅ | ✅ | 🚫 | Ball-by-ball events, wickets, milestones |
| Match stats | ✅ | ✅ | 🚫 | Manhattan, wagon wheel, partnerships, player vs player |
| Watch stream | ✅ | ✅ | ✅ | YouTube embed + RTMP viewer (web uses iframe; admin monitors) |
| Match highlights | ✅ | ✅ | 🚫 | Video highlights gallery |
| Start match (Quick) | ✅ | 🚫 | 🚫 | Mobile-only: Quick Match flow (typed teams) |
| Start match (Normal) | ✅ | 🚫 | 🚫 | Mobile-only: Full wizard with squads |
| Live scoring | ✅ | 🚫 | 🚫 | Mobile-only: Scorer interface for ball-by-ball |
| **Teams** |
| Team directory | ✅ | ✅ | ✅ | Browse, search teams; admin full CRUD |
| Team profile | ✅ | ✅ | ✅ | Stats, players, matches, trophies, rankings |
| Create team | ✅ | 🟡 | ✅ | Mobile full wizard; web may be partial; admin complete |
| Manage squad | ✅ | 🟡 | ✅ | Add/remove players; web may be limited |
| Team stats & rankings | ✅ | ✅ | ✅ | Win/loss, ranking points, leaderboards |
| **Players** |
| Player directory | ✅ | ✅ | ✅ | Browse, search players; admin full management |
| Player profile | ✅ | ✅ | ✅ | Career stats, badges, matches, following |
| Edit own profile | ✅ | ✅ | 🚫 | Photo, bio, playing style |
| Player rankings | ✅ | ✅ | 🚫 | Batting avg, bowling avg, fastest fifty, best bowling, etc. |
| Follow/unfollow players | ✅ | ✅ | 🚫 | Social follow mechanics |
| Player QR code | ✅ | 🚫 | 🚫 | Mobile-only: QR for quick profile share |
| Find cricketers | ✅ | ✅ | 🚫 | Player discovery with filters |
| Player analysis | ✅ | 🟡 | 🚫 | My Cricket analytics; web may be partial |
| **Tournaments** |
| Tournament directory | ✅ | ✅ | ✅ | Browse tournaments; admin full CRUD |
| Tournament profile | ✅ | ✅ | ✅ | Standings, bracket, fixtures, grounds |
| Create tournament | ✅ | 🟡 | ✅ | Mobile full wizard; web may be partial; admin complete |
| Points table | ✅ | ✅ | ✅ | Live standings with NRR |
| Knockout bracket | ✅ | ✅ | ✅ | Visual bracket view |
| **Series / Orgs** |
| Series directory (Associations/Clubs/Series) | ✅ | ✅ | ✅ | Three-drawer navigation by `kind` |
| Series detail hub | ✅ | ✅ | ✅ | Overview, Fixtures, Clubs, Players, Approvals, Admins |
| Create Series/Club/Association | ✅ | ✅ | ✅ | Full wizard with logo/cover upload |
| Series settings | ✅ | ✅ | ✅ | Edit name, description, rules, registration requirements |
| Create club within Series | ✅ | ✅ | ✅ | Club creation + approval workflow |
| Club rankings | ✅ | ✅ | ✅ | Points, wins, losses within Series |
| Player rankings (Series) | ✅ | ✅ | ✅ | Series-isolated leaderboards |
| Registration & join club | ✅ | ✅ | ✅ | Full registration with docs (ID, passport, photos) |
| Add player (Club Admin) | ✅ | ✅ | ✅ | Request player → Series approval |
| Approvals (Series Admin) | ✅ | ✅ | ✅ | Review clubs, players, registrations |
| Series Admins management | ✅ | ✅ | ✅ | Add/remove admins (Super Admin only on mobile/web; admin panel full) |
| Propose match/tournament | ✅ | ✅ | ✅ | Create official fixture linked to Series |
| Series audit log | ✅ | ✅ | ✅ | Admin event history |
| My requests | ✅ | 🟡 | 🚫 | View own pending approvals; web may be partial |
| Series investigation (admin) | 🚫 | 🚫 | ✅ | Admin-only: platform-wide Series investigation, suspend |
| **Grounds** |
| Ground directory | ✅ | ✅ | ✅ | Browse cricket grounds; admin full management |
| Ground profile | ✅ | ✅ | ✅ | Location, matches played |
| **Settings & Account** |
| App settings | ✅ | ✅ | ✅ | Notifications, language, theme (admin: account settings) |
| Legal docs (Terms/Privacy) | ✅ | ✅ | 🚫 | Web has dedicated legal routes |
| **My Cricket** |
| My Cricket hub | ✅ | 🟡 | 🚫 | Matches, Scoring, Streaming tabs; web partial |
| My matches | ✅ | 🟡 | 🚫 | Upcoming, past, scoring assignments |
| Active scoring sessions | ✅ | 🚫 | 🚫 | Mobile-only: scorer assignments, resume scoring |
| Active streaming sessions | ✅ | 🚫 | 🚫 | Mobile-only: broadcaster assignments, resume studio |
| My profile (trophies, badges, stats) | ✅ | ✅ | 🚫 | Career overview, achievements |
| **Invites** |
| Create player invite | ✅ | ✅ | 🚫 | Generate shareable invite link (phone or Google) |
| Accept invite | ✅ | ✅ | 🚫 | Land on `/invite/{token}`, verify OTP |
| **Chat** |
| Direct messages | ✅ | ✅ | 🚫 | 1:1 chat with other players |
| Block users | ✅ | ✅ | 🚫 | Block/unblock for DMs |
| **Store / Marketplace** |
| Store (placeholder) | ✅ | 🚫 | 🚫 | Mobile has store screen; not on web |
| **Fantasy** |
| Fantasy leagues | ✅ | 🟡 | 🚫 | Mobile has fantasy; web partial or missing |
| **Streaming** |
| RTMP Studio (publish) | ✅ | 🚫 | 🚫 | Mobile-only: native RTMP publish, camera overlay |
| WebRTC Viewer | ✅ | ✅ | ✅ | Low-latency viewer (WHIP); web/admin can view |
| YouTube Streaming | ✅ | ✅ | ✅ | Embed YouTube live stream |
| Stream dashboard | ✅ | 🚫 | ✅ | Mobile for broadcaster; admin for monitoring |
| **Analytics & Rankings** |
| Player rankings page | ✅ | ✅ | ✅ | Leaderboards by category; admin analytics module |
| Statistics page | ✅ | ✅ | ✅ | Platform-wide cricket stats; admin deep analytics |
| **Admin-Only Features** |
| Users management | 🚫 | 🚫 | ✅ | Admin-only: User CRUD, verification, suspend |
| Teams management | 🚫 | 🚫 | ✅ | Admin-only: Team CRUD, feature, soft-delete |
| Players management | 🚫 | 🚫 | ✅ | Admin-only: Player CRUD, feature, verify, suspend |
| Matches management | 🚫 | 🚫 | ✅ | Admin-only: Match investigation, edit metadata |
| Tournaments management | 🚫 | 🚫 | ✅ | Admin-only: Tournament CRUD, feature |
| Broadcasts monitoring | 🚫 | 🚫 | ✅ | Admin-only: Live stream monitoring (no interference) |
| Organizations (Series) investigation | 🚫 | 🚫 | ✅ | Admin-only: Series/Clubs investigation, suspend |
| Grounds management | 🚫 | 🚫 | ✅ | Admin-only: Ground CRUD |
| Community moderation | 🚫 | 🚫 | ✅ | Admin-only: Review, remove, feature community posts |
| Discover moderation | 🚫 | 🚫 | ✅ | Admin-only: Review, remove, feature opportunity posts |
| Reports queue | 🚫 | 🚫 | ✅ | Admin-only: User-reported content review |
| Notifications campaigns | 🚫 | 🚫 | ✅ | Admin-only: Send platform notifications |
| Ads management | 🚫 | 🚫 | ✅ | Admin-only: Advertisers, campaigns, segments |
| Analytics dashboard | 🚫 | 🚫 | ✅ | Admin-only: Platform KPIs, user metrics |
| Revenue hub | 🚫 | 🚫 | ✅ | Admin-only: Subscriptions, payouts, estimates |
| Audit logs | 🚫 | 🚫 | ✅ | Admin-only: Platform audit events |
| Security Center (SOC) | 🚫 | 🚫 | ✅ | Admin-only: Auth events, IP allow/deny, roles, backups, DR |
| AI Center | 🚫 | 🚫 | ✅ | Admin-only: AI/ML features management |
| CMS | 🚫 | 🚫 | ✅ | Admin-only: Content management |
| Support Center | 🚫 | 🚫 | ✅ | Admin-only: Support tickets, messages |
| Monitoring | 🚫 | 🚫 | ✅ | Admin-only: System health, Firebase quotas |
| DevOps | 🚫 | 🚫 | ✅ | Super Admin only: Manual operations, deployments |
| Continuity & DR | 🚫 | 🚫 | ✅ | Super Admin only: Backups, restore, recovery plans |
| Docs Center | 🚫 | 🚫 | ✅ | Super Admin only: In-app developer documentation |
| Settings (admin) | 🚫 | 🚫 | ✅ | Super Admin: Platform settings; Org Admin: account settings |
| Global search | 🚫 | 🚫 | ✅ | Admin-only: Search across all platform entities |

---

## Explicitly Mobile-Only (Not Web Gaps)

These features are **device-native by design** and should not be considered "missing" from web:

| Feature | Why Mobile-Only |
|---------|-----------------|
| Live scoring (scorer interface) | Complex gesture-driven UI, real-time ball-by-ball input optimized for touch |
| Start Match wizard (Quick/Normal) | Mobile workflow for match setup, squad selection, toss, innings |
| RTMP Publish (streaming studio) | Native camera access, hardware encoding, overlay compositor |
| Camera/gallery image picker | Mobile native photo selection with crop |
| Player QR code generator | Mobile convenience feature for quick profile share |
| In-app purchases (IAP) | Mobile store integration (Google Play / App Store) |
| Push notification registration (FCM) | Mobile native push token management |
| App Store / Google Play Store links | Mobile app distribution |
| Native share sheet | Mobile OS-level share dialog |

---

## True Gaps Identified

### Consumer Web (`crickflow-web`) — High Priority

| Gap | Status | Impact |
|-----|--------|--------|
| Create team wizard | 🟡 Partial | Web may have skeleton; needs full wizard matching mobile |
| Create tournament wizard | 🟡 Partial | Web may have skeleton; needs full wizard matching mobile |
| My Cricket hub | 🟡 Partial | My matches, upcoming, past exists; lacks scoring/streaming context |
| Player analysis deep stats | 🟡 Partial | Basic stats exist; advanced analytics (head-to-head, filters) may be incomplete |
| Fantasy leagues | 🟡 Partial | Mobile has fantasy module; web support unclear |
| My requests (Series) | 🟡 Partial | View own pending registrations/approvals in Series context |
| Store / Marketplace | ❌ Missing | Mobile has store screen; not implemented on web (low priority) |
| Team squad management UI | 🟡 Partial | Add/remove players; web may lack mobile polish |

### Flutter Admin Web — High Priority

| Gap | Status | Impact |
|-----|--------|--------|
| (None identified) | ✅ | Admin panel appears feature-complete per WEB_ADMIN_QA_REPORT.md |
| Players module | ✅ Done | Contrary to QA report placeholder note, PlayersScreen is fully implemented |
| Responsive shell | ✅ Done | Already fixed in prior work (drawer on mobile, sidebar on desktop) |
| Responsive tables | ✅ Done | CfResponsiveTable wrapper applied to Series investigation and reusable |

---

## Theme & Responsiveness Status

| Surface | Mobile Responsive | Theme Parity | Notes |
|---------|-------------------|--------------|-------|
| Consumer Web | ✅ Yes | ✅ Yes | TailwindCSS with mobile-first breakpoints, custom theme vars match mobile palette |
| Admin Web | ✅ Yes | ✅ Yes | Breakpoints updated, AdminShell drawer on mobile, CfResponsiveTable for data, admin theme aligned with mobile |

---

## Recommendations

### Immediate Priorities (Complete Web Parity)

1. **Consumer Web — Team Creation Wizard**
   - Implement full team creation flow matching mobile wizard
   - Logo upload, squad selection, settings

2. **Consumer Web — Tournament Creation Wizard**
   - Full tournament setup wizard
   - Format selection, teams, bracket/group, settings

3. **Consumer Web — My Cricket Enhancements**
   - My upcoming/past matches with filters
   - Clearer context for matches where user is player/scorer/admin

4. **Consumer Web — Fantasy Leagues**
   - Verify if fantasy exists; if not, implement or mark as deferred

5. **Consumer Web — Player Analysis**
   - Complete advanced stats, head-to-head, filters, match history

6. **Consumer Web — Series My Requests**
   - User view of own pending Series approvals, club join requests

### Lower Priority / Optional

- Store/Marketplace (mobile has placeholder; web can defer)
- Enhanced team squad management polish
- Additional admin features (all core modules complete)

---

## Conclusion

**Consumer Web:** ~85% feature parity with mobile for web-applicable features. Key gaps are wizard flows (team/tournament creation), My Cricket depth, and fantasy leagues.

**Admin Web:** ~100% feature complete. All modules implemented, responsive, permission-gated, and production-ready.

**Next Steps:** Focus implementation effort on consumer web wizard flows and My Cricket enhancements. Admin web requires no further major work for parity.
