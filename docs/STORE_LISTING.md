# Play Store & App Store listing

Use this when submitting **CrickFlow** v1.0.0.

## URLs (ready)

| Item | URL |
|------|-----|
| Privacy policy | https://crickflow-b06bc.web.app/privacy.html |
| Marketing site | https://crickflow-b06bc.web.app |
| GitHub | https://github.com/manurajv/crickflow |

Privacy / terms live at Firebase Hosting (`public/privacy.html`, `public/terms.html`). Redeploy hosting after content edits.

**Account deletion:** In-app at Settings → Delete Account (required by Google Play).

## Short description (Play, 80 chars)

Live cricket scoring & YouTube streaming for Sri Lanka — tennis & standard formats.

## Full description (template)

CrickFlow is built for local cricket in Sri Lanka: ball-by-ball scoring, live scorecards, tournaments, and optional YouTube RTMP streaming with on-screen overlays.

**Features**
- Google & phone sign-in — one account to score, play, and stream
- Create matches with custom rules (overs, wides, tennis ball, etc.)
- Teams, squads, and invite links
- League and knockout tournaments with brackets
- Share scorecards via deep link
- Live stream to YouTube with score overlay (organizers)

**Permissions**
- Camera & microphone: only when you start a live stream
- Notifications: match updates (optional)

Data is stored securely in Firebase. See our privacy policy for details.

## Category

Sports

## Content rating

Complete the Play questionnaire (no gambling; user-generated sports content).

## Build upload

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
