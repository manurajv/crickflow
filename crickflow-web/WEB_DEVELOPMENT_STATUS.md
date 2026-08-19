# CrickFlow Web — Development Status

**Project:** `crickflow-web` (independent of mobile / Admin / Super Admin)  
**Last updated:** 2026-08-19

Do not mix this file with `docs/IMPLEMENTATION_STATUS.md` (mobile) or web-admin tracking.

---

## Completed

| Item | Notes |
|------|--------|
| Phase 1 — project init | Next.js, TypeScript, Tailwind, design system, Firebase client, routing |
| Phase 2 — home, nav, search, auth, profile | Public homepage + shell |
| Phase 3 — matches / live / scorecard / commentary / stats | Viewer only; no scoring engine |
| Phase 4 — tournaments, teams, players, grounds, profiles | Grounds derived from public match/tournament venues |
| Phase 5 — Watch Live | YouTube / existing `stream` metadata |
| Phase 6 — rankings, statistics | Rankings aggregate completed matches with ball/year/overs filters |
| Phase 7 — community, discover, chat, notifications | Existing collections |
| Phase 8 — sharing, SEO, location | OG, sitemap, Web Share |
| Phase 9 — a11y, tests, security headers | Skip-to-content, error boundaries, CSP/HSTS, mapper tests, GA |
| Phase 10 — deploy config | Hosting site `crickflow` (`https://crickflow.web.app`). Static export; home/lists fetch live in the browser. |
| Match highlights tab | Published clips + boundary/wicket events |
| Team profile tabs | Matches, leaderboard, stats, members, trophies, profile |
| Tournament knockout bracket | Reads `bracketRounds` from tournament docs |
| Structured data | SportsEvent / Person / SportsTeam JSON-LD |
| Dynamic sitemap | Public matches, players, teams, tournaments |
| Location opt-in | Community, Discover, Settings — never forced |
| Signed-in home Following | Followed teams/players plus their matches from the current lists |
| Community / Discover media | Images and videos from existing post fields |
| Directory fail-closed | Matches, teams, players, tournaments, grounds stop spinning if Firestore errors |
| Chat block | Same `chat_blocks` docs as mobile; hides blocked threads in inbox |
| Profile following | Lists followed teams and players |
| Directory load more | Matches, teams, players, tournaments |
| Notification deep links | Community posts, live/watch/scorecard match types, chat |
| Community save | Same `saves/{uid}` + `saveCount` as mobile; user index `saved_community_posts` |
| Discover share / report | Uses `opportunity_post_reports` |
| Email / password sign-in | Web convenience; fails clearly if the method is disabled in Console |
| Search grounds / Discover | Ctrl+K and `/search` |
| Statistics charts | Top run-scorers and wicket-takers from the public player pool |
| Match commentary filters | Wickets, boundaries, extras |
| Highlight clips | Plays published `mediaUrl` when present |
| Fantasy leagues (view) | Public leagues for a match; squad pick stays in the app |
| Live match snapshots | Home and `/matches?status=live` update scores without refresh |
| Discover save / views | Same `saves` + `viewCount` as mobile (signed-in); user index `saved_opportunity_posts` |
| Saved lists | Profile plus Community/Discover **Saved** filters |
| Photo uploads | Community / Discover / Settings — Storage CORS PUT applied on `crickflow-b06bc.firebasestorage.app` |
| Own post delete | Author can delete Community posts, comments, and Discover listings |
| Report reasons | Spam / harassment / misleading / inappropriate / other |
| Discover contact | Optional phone and WhatsApp on create |
| My posts / listings | Profile lists the signed-in user's Community and Discover docs |
| Followed matches | Profile lists `matchFollowers` |
| Chat search / archive | Inbox search plus per-user archive |
| Close Discover listing | Owner sets `status: removed` (stays out of the active feed) |

---

## In Progress

None — foundation implementation landed in this tree.

---

## Blocked

| Item | Reason |
|------|--------|
| Production DNS `www.crickflow.app` | Optional custom domain on site `crickflow`. Live URL is `https://crickflow.web.app`. Root hosting stays for App Links / `/live`. |
| Dedicated Firebase Web App ID | Optional; current public web client config works. Register in Console without editing mobile/admin source. |
| Phone Auth on production domain | Authorized domains now include `crickflow.web.app` and `crickflow.firebaseapp.com`. |
| Google Maps JS | Needs a web-restricted Maps key (`NEXT_PUBLIC_GOOGLE_MAPS_API_KEY`). Embed fallback used without a key. |
| App Check | Pending on mobile as well — not enabled from this project. |

---

## Planned

- Web scoring (explicitly out of scope until requested)
- Web RTMP ingest / broadcast start (mobile-only)
- Native WebRTC playback (signaling exists; media stack is mobile backlog)
- Fastest fifty/hundred rankings that require full ball-event replay (same deferral as mobile)

---

## Known Issues

See [EXTERNAL_DEPENDENCY_ISSUES.md](docs/EXTERNAL_DEPENDENCY_ISSUES.md).

---

## Technical Debt

- Rankings scan a capped pool of completed matches in the browser (same approach as mobile).
- Ground pages use a synthetic id (`venue` slug) rather than `grounds/{id}`.
- Email/password is a web convenience; mobile primary methods are Google + phone.
- List reads fail closed if Firestore is unreachable (CI / offline SSG)
- Player follow requires the player document to have `userId` (walk-ins cannot be followed)

---

## Future Improvements

- Attach `www.crickflow.app` to Hosting site `crickflow` if you want the branded domain
- App Check for web
- Playwright e2e against emulator
- Dedicated Firebase Web App ID if product wants isolation from the Admin web client
