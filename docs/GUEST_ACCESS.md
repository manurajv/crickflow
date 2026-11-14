# Guest access (signed-out browse)

Signed-out users can **browse** CrickFlow and watch matches. Account actions open
a shared **Sign in required** sheet with a **contextual** body (never “log in”),
then the login screen with the same message.

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
`requireAuthVoid` with a `SignInPrompt`, or a protected route):

- Create / start / score / stream a match; takeover scoring
- Create a team; add players; edit profile
- Create an org; org settings; propose/start match or tournament; join/register;
  approvals; admins; announcements; my requests; add org team
- Notifications, chats, likes/comments/saves that mutate data
- Tournament create / join request

## Sign-in copy

Catalog: `lib/core/auth/sign_in_prompts.dart` (mirrored on web in
`crickflow-web/lib/auth/guest-access.ts`).

| Key | Message |
| --- | --- |
| `general` (default) | Sign in to your CrickFlow account to continue. |
| `create_post` | Sign in to create a post and join the conversation. |
| `create_opportunity` | Sign in to post an opportunity on Discover. |
| `like_comment` | Sign in to like and comment on posts. |
| `save_post` | Sign in to save posts for later. |
| `follow` | Sign in to follow players and build your cricket network. |
| `chat` | Sign in to send messages and start chats. |
| `report` | Sign in to report content and help keep CrickFlow safe. |
| `manage_post` | Sign in to manage this post. |
| `block_user` | Sign in to block users. |
| `notifications` | Sign in to view your notifications. |
| `notification_settings` | Sign in to manage notification preferences. |
| `manage_profile` | Sign in to manage your profile. |
| `my_cricket` | Sign in to see your matches, teams, stats, and highlights. |
| `start_match` | Sign in to start a match and keep score. |
| `score_match` | Sign in to score this match. |
| `stream_match` | Sign in to stream or broadcast this match. |
| `create_team` | Sign in to create a team. |
| `manage_team` | Sign in to manage this team. |
| `create_tournament` | Sign in to create a tournament. |
| `join_tournament` | Sign in to join this tournament. |
| `invite_player` | Sign in to invite a player to CrickFlow. |
| `create_org` | Sign in to create an organization. |
| `create_org_team` | Sign in to add a team to this organization. |
| `join_org` | Sign in to join this organization. |
| `propose_match` | Sign in to propose a match in this organization. |
| `propose_tournament` | Sign in to propose a tournament in this organization. |
| `org_manage` | Sign in to manage this organization. |
| `edit_profile` | Sign in to edit your profile. |

Sheet title: **Sign in required**. Buttons: **Sign in** / **Not now**.

## How it works

1. **`GuestRoutes`** — which paths guests may open.
2. **Router redirect** — protected path → `PendingAuthAction` with
   `SignInPrompt.forPath`, then `/login`.
3. **`requireLogin` / `requireAuth`** — shared sheet (`showSignInRequiredSheet`)
   then login; banner shows the same contextual message.
4. **Web** — `loginUrl(path, promptKey)` puts the **key** in `?msg=`; the login
   page resolves it via the whitelist (`resolveSignInMessage`).

## Tests

- `test/guest_access_test.dart` — routes + prompt catalog + path mapping
- Firestore emulator anon reads (`firestore-tests/rules.test.cjs`)
