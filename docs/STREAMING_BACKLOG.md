# Streaming Studio — Backlog & Roadmap

Track what is **done**, **deferred**, and **planned**.  
Setup guide: **[STREAMING_SETUP.md](STREAMING_SETUP.md)** · Architecture: [STREAMING_ARCHITECTURE.md](STREAMING_ARCHITECTURE.md)

---

## Done (code complete)

| Area | Item |
|------|------|
| Dashboard | Pre-live setup — camera, platform, quality, audio, overlays, health |
| RTMP | `StreamService` — lens, orientation lock, record+stream, health, reconnect |
| Overlays | Scorebug, event graphics, sponsor rotation, score ticker |
| Permissions | `StreamPermissionService` |
| Replay | Manual + auto markers → `replayMarkers` |
| Highlights | Merged events + markers; YouTube `t=` links; chapter export |
| YouTube API | `linkYouTubeAccount`, `createYouTubeLiveStream`, `listYouTubeChannels`, `getYouTubeLiveChat`, `exportYouTubeChapters` |
| OAuth | Server auth code → refresh token in `streaming_credentials/{uid}` |
| Platforms UI | YouTube / Facebook / Twitch / custom RTMP + saved servers |
| Live studio | Fullscreen compositor, health, chat panel, replay flag, end stream |
| Notifications | `onStreamStatusChanged` fan-out |
| Safety | Serialized camera ops; platform view teardown on lens switch |

---

## Deferred (polish / native — not blocking MVP)

| Item | Notes |
|------|-------|
| UI/camera polish | Lens switch on Oppo/Samsung, form controllers, tap-to-focus |
| Digital zoom | After max optical — needs native camera API |
| RTMP overlay burn-in | Done — Flutter PNG → `SafeOpenGlView` + `glInterface.setFilter` on Android (requires OpenGlView; LightOpenGlView filters are no-ops) |
| Facebook/Twitch auto RTMP | Manual paste works; API stubs return clear errors |
| Sponsor logo images | Text rotation done; logo URLs on scorebug pending |
| Chat moderation | Read-only chat done |
| Multi-camera / OBS docs | Custom RTMP works; extended docs in backlog |
| WebRTC viewer | See [WEBRTC.md](WEBRTC.md) |
| Stream scheduling | YouTube scheduled broadcast + reminders |

---

## Your manual steps (required once)

See **[STREAMING_SETUP.md](STREAMING_SETUP.md)** sections 1–2:

1. Enable **YouTube Data API v3**
2. Configure **OAuth consent** + test users
3. Set **`YOUTUBE_CLIENT_ID`** / **`YOUTUBE_CLIENT_SECRET`** secrets
4. **`firebase deploy --only functions,firestore:rules`**
5. Verify YouTube channel is **live-enabled**

---

*Implementation complete in repo — remaining work is deployment, Google Cloud config, and optional polish.*
