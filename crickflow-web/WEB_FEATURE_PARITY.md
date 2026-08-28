# CrickFlow Web — Feature Parity Matrix

Mobile is the functional source of truth. Web is a **web-native viewer/creator** sharing the same Firebase data. Scoring and broadcast *production* remain on mobile.

| Mobile Feature | Web Status | Web Route | Backend Used | Implementation Notes | Status |
|----------------|------------|-----------|--------------|----------------------|--------|
| Splash / onboarding | Partial | `/` `/register` | `users` | Web uses login + profile completion, not native splash | Partial |
| Google sign-in | Implemented | `/login` | Firebase Auth | Popup, then redirect if the popup is blocked | Completed |
| Phone OTP | Implemented | `/login` | Firebase Auth | reCAPTCHA verifier | Completed |
| Email / password | Implemented | `/login` | Firebase Auth | Web convenience; requires the method enabled in Console | Completed |
| Home feed | Implemented | `/` `/home` | `matches`, `tournaments`, `community_posts`, `home_promotions`, follows | Desktop grid; live scores via snapshot | Completed |
| Matches list | Implemented | `/matches` | `matches` | Live / upcoming / completed | Completed |
| Match hub | Implemented | `/matches/[matchId]` | `matches`, overlay, ball_events | Match Centre layout | Completed |
| Live score | Implemented | `/matches/[matchId]/live` | match doc + overlay | Realtime when live | Completed |
| Live scoring (scorer UI) | Not on web | — | Scoring engine | Intentionally not ported | Deferred |
| Scorecard | Implemented | `/matches/[matchId]/scorecard` | `innings` on match | RH/RO, extras, FOW | Completed |
| Commentary | Implemented | `/matches/[matchId]/commentary` | `ball_events` | Sequence order + wicket/boundary/extra filters | Completed |
| Highlights | Implemented | Match Centre tab | `highlights` + ball events | Clips plus boundaries/wickets | Completed |
| Match stats / insights | Implemented | `/matches/[matchId]/stats` | innings + events | Manhattan, partnerships | Completed |
| Wagon wheel | Implemented | Match Centre tab | `ball_events.wagonWheel` | SVG plot | Completed |
| Squads | Implemented | Match Centre tab | `setup` on match | Read-only | Completed |
| Teams list / profile | Implemented | `/teams` `/teams/[id]` | `teams` | Tabs: matches, leaderboard, stats, members, trophies, profile | Completed |
| Create team | Partial | `/teams` | Play Store CTA | Create remains mobile; web lists + search | Partial |
| Players directory | Implemented | `/players` | `players` | | Completed |
| Player profile | Implemented | `/players/[id]` | `players`, `users`, `matches` | Stats, follow, share, recent matches | Completed |
| Cricket ID / QR | Implemented | Player profile | `playerId` | Share URL + QR; follow uses the player's Firebase user id | Completed |
| Grounds | Implemented | `/grounds` `/grounds/[id]` | Derived from matches/tournaments | Admin `grounds` not public | Completed |
| Community feed | Implemented | `/community` | `community_posts` | Likes, comments, create, Saved filter, JPEG photos | Completed |
| Community post | Implemented | `/community/[postId]` | same | OG share, media, likes, saves | Completed |
| Discover | Implemented | `/discover` | `opportunity_posts` | Categories, filters, share, report, save, views, Saved filter, JPEG photos | Completed |
| Chat | Implemented | `/chat` `/chat/[id]` | `chats`, `messages`, `chat_blocks` | Requests accept/decline; block | Completed |
| Notifications | Implemented | `/notifications` | `notifications` | Categories + type-aware deep links | Completed |
| Search | Implemented | `/search` + Ctrl+K | Client index of public collections | Players, teams, matches, tournaments, posts, Discover, grounds | Completed |
| Analytics / statistics | Implemented | `/statistics` | players/teams/matches | Totals plus run/wicket bar charts | Completed |
| Player rankings | Implemented | `/rankings` | completed `matches` + `players` | Leather/tennis/indoor, year, overs; batting/bowling from innings; fielding when innings.fielders exist | Completed |
| Settings | Implemented | `/settings` | `users` + Storage | Theme, profile, photo, log out | Completed |
| Location filters | Implemented | Shared filter | `location` maps | Opt-in geolocation | Completed |
| Sharing / deep links | Implemented | All public entities | Web Share + copy | `crickflow.web.app` URLs | Completed |
| Store / IAP | Not on web | — | — | Mobile roadmap | Deferred |
| Player onboarding | Implemented | `/register` | `users`, `players`, `app_meta/cf_player_ids` | 5-step flow (photo optional; role, batting, bowling required); global guard blocks skip | Completed |

Legend: **Completed** = web viewer/action shipped · **Partial** = view or subset · **Deferred** = mobile-only by design.
