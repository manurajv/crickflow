# Guest access (signed-out browse)

Signed-out users can **browse** CrickFlow and watch matches. Any action that
needs an account opens the login screen with the message **Sign in to use this**.

## What guests can see

| Area | Access |
| --- | --- |
| Home, Discover, Matches list, Community feed, Profile tab (guest prompt) | Browse |
| Match hub, scorecard, live/completed score views (not scoring UI) | Read |
| Teams, players, player rankings, tournament dashboards | Read |
| **Orgs** (`/series`, `/associations`, `/clubs`): list, detail, Matches & Tournaments tabs, leaderboard/rankings, club detail | Read |
| Legal / settings (read-only bits) | Browse |

Firestore already allows public **read** for `series`, `series_clubs`,
`series_admins`, `series_memberships`, `series_competitions`, rankings,
`series_match_digests`, `matches`, `teams`, `players`, `tournaments`. Private
collections (notifications, registrations, approvals lists, audit logs,
announcements) stay signed-in only. Guests cannot write.

## What guests cannot do (gated)

Examples — all use the shared gate (`requireLogin` / `requireAuth` /
`requireAuthVoid`, or a protected route):

- Create / start / score / stream a match; takeover scoring
- Create a team; add players; edit profile
- Create an org; org settings; propose/start match or tournament; join/register;
  approvals; admins; announcements; my requests; add org team
- Notifications, chats, likes/comments/saves that mutate data
- Tournament create / join request

## How it works

1. **`GuestRoutes`** (`lib/core/auth/guest_routes.dart`) — which paths guests
   may open. Org browse paths are public; org write paths are protected.
2. **Router redirect** — a guest hitting a protected path is sent to `/login`
   after `PendingAuthAction.register` so the banner and return path work.
3. **`requireLogin` / `requireAuth`** (`lib/core/auth/auth_gate.dart`) — for
   in-screen buttons. Shows the shared **Sign in required** bottom sheet
   (`showSignInRequiredSheet`) with body **Sign in to use this**, then the
   login screen. After a successful login, the pending action / return path runs.
4. **Login screen** — banner with key `sign_in_to_use_this_banner` when a gated
   action is pending.

Web: `crickflow-web/lib/auth/guest-access.ts` (`SIGN_IN_TO_USE_THIS`, `loginUrl`).
Org list/detail are viewable while signed out; create/join CTAs send guests to
`/login?next=…&msg=Sign%20in%20to%20use%20this`.

## Tests

- `test/guest_access_test.dart` — public vs protected org routes + message copy
- Firestore emulator already asserts anon read of series / clubs / digests /
  org matches (`firestore-tests/rules.test.cjs`)
