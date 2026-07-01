# CrickFlow Live Streaming — Setup Guide

Complete this **once** before using YouTube auto-RTMP, live chat, and chapter export.  
Architecture: [STREAMING_ARCHITECTURE.md](STREAMING_ARCHITECTURE.md) · Backlog: [STREAMING_BACKLOG.md](STREAMING_BACKLOG.md)

Firebase project: **crickflow-b06bc**

---

## 1. Google Cloud Console

Open [Google Cloud Console](https://console.cloud.google.com/) and select project **crickflow-b06bc** (same as Firebase).

### 1.1 Enable APIs

APIs & Services → **Library** → enable:

| API | Purpose |
|-----|---------|
| **YouTube Data API v3** | Create live broadcasts, RTMP keys, live chat |
| **YouTube Analytics API** | Optional — future stats |

### 1.2 OAuth consent screen

APIs & Services → **OAuth consent screen**:

1. User type: **External** (or Internal if Workspace-only).
2. App name: **CrickFlow**
3. Support email: your email
4. Scopes → **Add or remove scopes**:
   - `.../auth/youtube` (Manage your YouTube account)
   - `.../auth/youtube.force-ssl` (View YouTube account)
5. **Test users**: add Google accounts that will stream (required while app is in *Testing*).
6. For production: submit for **verification** (YouTube scopes require Google review).

### 1.3 OAuth client — **Firebase Web client** (not a separate GCP project)

Android Google Sign-In requires the **Web client ID from the same Firebase/GCP project** as your Android OAuth client. Check `android/app/google-services.json` → `oauth_client` with `"client_type": 3`.

For **crickflow-b06bc**, use:

`202403125129-vnidfiidc4dj9tks4btugh9ncnhn8oi5.apps.googleusercontent.com`

Defined in `lib/config/youtube_oauth_config.dart` as `kYouTubeWebClientId`.

**Do not** use a manually created Web client whose ID starts with a different project number (e.g. `447617533501-...`) — that causes **`ApiException: 10`** on Android after account picker.

In Google Cloud → **Credentials**, open the Web client named **Web client (auto created by Google Service)** (or the client ID above). Copy:

- **Client ID** → Firebase secret `YOUTUBE_CLIENT_ID`
- **Client secret** (`GOCSPX-...`; reset if unknown) → Firebase secret `YOUTUBE_CLIENT_SECRET`

#### Authorised JavaScript origins (add both if missing)

| URI |
|-----|
| `https://crickflow-b06bc.firebaseapp.com` |
| `https://crickflow-b06bc.web.app` |

#### Authorised redirect URIs (add **both**)

| URI |
|-----|
| `https://crickflow-b06bc.firebaseapp.com/__/auth/handler` |
| `https://crickflow-b06bc.web.app/__/auth/handler` |

Click **Save** at the bottom of the OAuth client page.

Also confirm **Android** OAuth client exists with package `com.mavixas.crickflow` and your SHA-1 (Firebase Console → Project settings → Your apps). Debug SHA-1 from your machine must match the certificate hash in `google-services.json`.

---

## 2. Firebase / Cloud Functions secrets

From repo root (PowerShell):

```powershell
# Option A — interactive (recommended): run each line, paste value when prompted, press Enter
firebase functions:secrets:set YOUTUBE_CLIENT_ID
firebase functions:secrets:set YOUTUBE_CLIENT_SECRET
```

```powershell
# Option B — pipe value (no second argument on the command line)
"YOUR_WEB_CLIENT_ID.apps.googleusercontent.com" | firebase functions:secrets:set YOUTUBE_CLIENT_ID --data-file -
"YOUR_GOCSPX_CLIENT_SECRET" | firebase functions:secrets:set YOUTUBE_CLIENT_SECRET --data-file -
```

Verify both exist:

```powershell
firebase functions:secrets:access YOUTUBE_CLIENT_ID
firebase functions:secrets:access YOUTUBE_CLIENT_SECRET
```

Each should print the value (not `404` / `not found`).

If you created wrongly named secrets in Secret Manager (e.g. `GOCSPX_1_...`), delete them in [Google Cloud → Secret Manager](https://console.cloud.google.com/security/secret-manager) and run the two commands above again.

Alternatively, for local emulator only, add to `functions/.env`:

```
YOUTUBE_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
YOUTUBE_CLIENT_SECRET=your-secret
```

Wire secrets in function definitions if not using `process.env` defaults — current code reads `process.env.YOUTUBE_CLIENT_ID` / `YOUTUBE_CLIENT_SECRET`. For production deploy, set via Firebase secrets or `firebase functions:config:set` legacy env (prefer secrets on v2).

**Deploy:**

```powershell
.\scripts\deploy-firebase.ps1
# or:
firebase deploy --only functions,firestore:rules
```

Functions exported:

| Function | Purpose |
|----------|---------|
| `linkYouTubeAccount` | OAuth link from app |
| `createYouTubeLiveStream` | Auto RTMP + watch URL |
| `listYouTubeChannels` | Linked channel |
| `getYouTubeLiveChat` | Live chat in studio |
| `exportYouTubeChapters` | Replay markers → YouTube description format |
| `onStreamStatusChanged` | Push when stream starts/ends |

---

## 3. Firestore rules

Deploy includes rules for:

- `matches/{id}/replayMarkers` — scorers create replay flags
- `streaming_credentials/{uid}` — **Admin SDK only** (OAuth tokens)

If stream writes fail with `PERMISSION_DENIED`, redeploy rules:

```powershell
firebase deploy --only firestore:rules
```

---

## 4. YouTube channel requirements

The Google account used in the app must:

1. Have a **YouTube channel** (not just a Google account).
2. Be **verified** for live streaming ([youtube.com/features](https://www.youtube.com/features) — no strikes, phone verified).
3. Wait **24 hours** after enabling live streaming for the first time (YouTube policy).

---

## 5. App workflow (streamer)

1. Open match → **Stream** (`/match/:id/stream`).
2. **Connect YouTube account** (Platform section).
3. Optional: **Create YouTube Live** (fills RTMP URL + stream key + watch URL).
4. **Lock orientation** (required).
5. **Start Stream** — if YouTube is selected and key is empty, app auto-creates a live broadcast.
6. While live: scorebug overlays on preview, replay markers, live chat panel (YouTube linked).
7. **End stream** → followers get notification via `onStreamStatusChanged`.

### Manual RTMP (no YouTube API)

Works without steps 1–2:

- **Custom RTMP**: paste URL + key (OBS, MediaMTX, etc.).
- **Facebook / Twitch**: paste stream key from their dashboards (auto-create stubs return helpful errors until API keys are added).

Default URLs in app:

| Platform | RTMP base |
|----------|-----------|
| YouTube | `rtmp://a.rtmp.youtube.com/live2` |
| Facebook | `rtmps://live-api-s.facebook.com:443/rtmp/` |
| Twitch | `rtmp://live.twitch.tv/app/` |

---

## 6. Highlights & YouTube chapters

During live stream, wickets/fours/sixes auto-save **replay markers** (if enabled).

After the match:

1. Match → **Highlights**
2. Tap **Export YouTube chapters** (list icon in app bar)
3. Paste copied lines into YouTube video **Description** (chapter format: `0:00 Label`)

Share highlight rows include `t=` seek links when `youtubeWatchUrl` is on the match.

---

## 7. Testing checklist

- [ ] Physical Android/iOS device (emulator camera/RTMP unreliable)
- [ ] Connect YouTube → channel name appears
- [ ] Create YouTube Live → RTMP key populated
- [ ] Go Live → YouTube Studio shows incoming stream
- [ ] Score a wicket → overlay + replay marker + highlights row
- [ ] End stream → `stream.status` = `ended` in Firestore
- [ ] Export chapters → clipboard has timestamp lines

---

## 8. Not implemented (future / manual workaround)

| Feature | Workaround |
|---------|------------|
| **Overlay burn-in on RTMP** | Overlays visible in app preview only; YouTube viewers see camera unless you use OBS browser source |
| **Facebook/Twitch auto RTMP** | Paste keys manually |
| **Digital zoom** | Use optical lens chips only |
| **Camera lens switch on some Oppo/Samsung** | Select lens before opening preview; UI polish pending |

See [STREAMING_BACKLOG.md](STREAMING_BACKLOG.md) for full roadmap.

---

## 9. Troubleshooting

| Issue | Fix |
|-------|-----|
| `ApiException: 10` / `sign_in_failed` after account picker | Web client ID must match Firebase project (`202403125129-vnidfi...` in app + secrets); SHA-1 registered in Firebase |
| `Set YOUTUBE_CLIENT_ID and YOUTUBE_CLIENT_SECRET` | Deploy secrets (section 2) |
| `YouTube not linked` | Tap Connect YouTube account |
| `No refresh token` | Google Account → Security → Third-party access → remove CrickFlow → link again |
| `PERMISSION_DENIED` on stream metadata | Deploy Firestore rules |
| Stream key works in OBS but not app | Check RTMP URL has no trailing key duplicated |
| Live chat empty | Chat appears after YouTube broadcast is **live** and has `activeLiveChatId` |
| App crashes on lens change | Known on some devices — pick lens before preview (see backlog) |

---

## 10. iOS note

Live streaming requires a **physical iPhone/iPad**. Ensure `GoogleService-Info.plist` is present ([IOS_SETUP.md](IOS_SETUP.md)). Add iOS OAuth client in Google Cloud if YouTube linking fails on iOS.

---

*After completing sections 1–2 and deploying, YouTube auto-RTMP is fully functional in code.*
