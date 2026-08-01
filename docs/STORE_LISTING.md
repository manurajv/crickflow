# Play Store & App Store listing

Use this when submitting **CrickFlow** v1.0.0.

**Suggested Play Console app name (≤30 chars):** `CrickFlow - Cricket Scoring`  
**On-device label:** `CrickFlow` (AndroidManifest — leave as-is)

## URLs (ready)

| Item | URL |
|------|-----|
| Privacy policy | https://crickflow-b06bc.web.app/privacy.html |
| Terms | https://crickflow-b06bc.web.app/terms.html |
| Marketing site | https://crickflow-b06bc.web.app |
| GitHub | https://github.com/manurajv/crickflow |

Privacy / terms live at Firebase Hosting (`public/privacy.html`, `public/terms.html`). Redeploy hosting after content edits.

**Account deletion:** In-app at Settings → Delete Account (required by Google Play).

---

## Short description (Play, ≤80 chars)

```
Score, stream, connect & watch cricket—all in one powerful platform.
```

(Character count: 69)

---

## Full description (Play Console — paste as-is)

```
CrickFlow – Your complete cricket platform.

CrickFlow is a cricket ecosystem for players, teams, organizers, scorers, umpires, clubs, schools, academies, and fans. Score a local match, run a tournament, or broadcast live—CrickFlow brings scoring, streaming, teams, and community together in one modern app.

Built for Sri Lankan cricket and ready to scale globally. Supports tennis ball, leather ball, indoor cricket, and custom match formats and rules.

KEY FEATURES

Professional live scoring
• Ball-by-ball scoring with undo
• Real-time scorecards shared with viewers
• Detailed batting, bowling & fielding stats
• Partnerships, over history & match insights
• Wagon wheel and match analytics where enabled
• Custom playing conditions (overs, extras, powerplays, and more)
• Tennis ball & leather ball support
• Offline-friendly scoring with sync when you’re back online

Live streaming
• Stream to YouTube (automatic setup when you link your channel, or manual RTMP)
• Custom RTMP for other destinations
• Live score overlays burned into the stream (Android)
• Match markers, highlights & in-app seek on recorded moments
• Watch live (and past) streams inside the match hub
• OBS / external encoder support with browser-source overlay URL

Tournament management
• League and knockout tournaments
• Fixtures, brackets & points tables
• Team registration and join/invite flows
• Tournament stats and live updates
• Officials and organizer tools

Teams & players
• Cricket profiles and team profiles
• Career stats and match history
• Achievements & badges
• Follow players and teams
• Team invites, join requests & squad management

Community & discover
• Cricket community feed (posts, comments, likes)
• Discover players, teams, scorers, umpires & tournaments
• Opportunities board for cricket roles and openings
• Chat with other users
• Follow your cricket network

Rankings & statistics
• Batting, bowling & fielding leaderboards
• Match and tournament analytics
• Career statistics and performance insights

Smart notifications
• Match and tournament updates
• Innings and result alerts
• Follows, team invites & join requests
• Milestones, awards & badge unlocks

Secure sign-in
• Google Sign-In
• Phone number (OTP)
• Secure Firebase Authentication

PERMISSIONS

CrickFlow only asks for permissions when needed:

Camera & microphone — only when you start a live stream or broadcast.
Notifications — match updates, tournament alerts and important announcements.
Location — optional, to help with grounds, nearby discovery and location-based features.

PRIVACY & SECURITY

Your data is stored securely with Firebase.

CrickFlow only accesses your YouTube account when you choose to connect it to create and manage live broadcasts on your own channel. We do not access or change unrelated YouTube content.

Delete your account anytime in Settings → Delete Account.

Privacy policy: https://crickflow-b06bc.web.app/privacy.html
Terms: https://crickflow-b06bc.web.app/terms.html

BUILT FOR CRICKET

Village tournaments, school championships, academy leagues, club cricket, or streamed exhibition games—CrickFlow helps you score, stream, manage, and grow the game.

Score. Stream. Connect.
Everything cricket, one platform.
```

---

## Category

Sports

## Content rating

Complete the Play questionnaire (no gambling; user-generated sports content).

## Build upload

Full ops checklist (signing, Maps key, deploy rules): [PLAY_STORE_LAUNCH.md](PLAY_STORE_LAUNCH.md).

```powershell
.\scripts\build-release.ps1
```

Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console.

## Screenshots (capture on device)

1. Login (Google / phone)
2. Home / match list
3. Live scoring
4. Scorecard
5. Tournament bracket
6. Live stream (landscape)

## iOS

See [IOS_SETUP.md](IOS_SETUP.md) for `GoogleService-Info.plist` and Associated Domains.
