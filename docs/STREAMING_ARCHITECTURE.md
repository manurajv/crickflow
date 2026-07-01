# Live Streaming Architecture

> **Full broadcast module spec:** [BROADCAST_MODULE.md](BROADCAST_MODULE.md)

## Studio module (Phase 2+)

```
┌─────────────────────────────────────────────────────────────────┐
│                    StreamingDashboardScreen                      │
│  Camera preview │ Match info │ Platform │ Quality │ Overlays  │
│  Orientation lock (required before Go Live)                      │
└────────────┬────────────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────┐     ┌──────────────────────────────────┐
│ StreamService        │────▶│ RTMP (rtmp_broadcaster)          │
│ lens switch          │     │ YouTube / Facebook / Twitch / RTMP│
│ orientation lock     │     └──────────────────────────────────┘
│ health / reconnect   │
└──────────┬───────────┘
           │
           │  Firestore: matches/{id}/overlay/current
           │  ball_events → StreamEventDetector → animated overlays
           ▼
┌──────────────────────┐
│ StreamStudioCompositor│  TV scorebug + event graphics on preview
└──────────────────────┘
```

### Flutter layout

```
lib/features/streaming/
├── broadcast_module.dart     # Public barrel
├── studio/                   # BroadcastSessionController
├── camera/                   # Pro camera controls
├── youtube|facebook|twitch|rtmp/   # StreamDestinationProvider per platform
├── obs/                      # External encoder (OBS) setup + QR
├── analytics/                # Network telemetry
├── settings/                 # Mode selector, config models
├── domain/                   # Enums, permissions, event detector
├── data/                     # Models, stream_studio_repository
├── services/                 # stream_platform_service (Cloud Functions client)
└── presentation/             # StreamingDashboardScreen, widgets
```

### Components

1. **Streaming Dashboard** — pre-live setup: camera, platform, quality, audio, overlays, health.
2. **StreamService** — enhanced RTMP publisher with lens catalog, orientation lock, local record+stream, auto-reconnect on `rtmp_retry`.
3. **Broadcast overlays** — `BroadcastScoreboardOverlay` + `StreamEventOverlayWidget` composited on preview.
4. **Permissions** — `StreamPermissionService` (organizer, assigned streamer, scorer, creator).
5. **Replay markers** — `matches/{id}/replayMarkers` for highlight generation.
6. **Cloud Functions** — `onStreamStatusChanged`, `createYouTubeLiveStream` (OAuth wiring pending).

See **[STREAMING_BACKLOG.md](STREAMING_BACKLOG.md)** for full done / pending checklist.  
**Setup (Google Cloud + deploy): [STREAMING_SETUP.md](STREAMING_SETUP.md)**

### Stream metadata (Firestore)

On `match.stream`:
- `status`: idle | connecting | live | ended | error
- `destination`: youtube | customRtmp
- `rtmpUrl`, `streamKey`, `youtubeWatchUrl`, `startedAt`

### Overlay burn-in (RTMP output)

Preview stacks Flutter widgets over `CameraPreview`. **Burning overlays into the RTMP bitstream** requires native OpenGL compositing (planned Phase 3) or server-side FFmpeg. Architecture uses `StreamStudioCompositor` so native sink can replace preview-only compositing without UI rewrites.

### YouTube auto RTMP

1. Client obtains Google OAuth refresh token → `storeStreamingOAuthToken` callable stores in `streaming_credentials/{uid}` (server-only).
2. Deploy `createYouTubeLiveStream` with YouTube Data API v3 + `YOUTUBE_CLIENT_ID` / `YOUTUBE_CLIENT_SECRET`.
3. Client calls via `StreamPlatformService.createYouTubeLive()` — no manual stream key when configured.

Facebook/Twitch use the same pattern via `createFacebookLiveStream` / `createTwitchLiveStream` (stubs until API keys added). Manual RTMP paste works today.

### Overlay extras

- **Sponsor rotation** — tournament `tournament_sponsors` rotate on the scorebug banner every 15s when enabled.
- **Score ticker** — marquee line above scorebug when `showTicker` is on in overlay settings.
- **Auto replay markers** — ball events (wicket, four, six, milestones) write `replayMarkers` during live stream when enabled.

### Multi-camera / OBS (future)

- `StreamService` lens list abstracts camera IDs → second USB/drone camera adds another `CameraLensInfo`.
- Custom RTMP + saved servers supports OBS/Wowza relay today.
- WebRTC / NDI / SRT: see [WEBRTC.md](WEBRTC.md).

### Monitoring

- Heartbeat every 30s while live
- `getStreamStatistics()` → bitrate, dropped frames
- Auto-reconnect on connectivity restore + plugin `rtmp_retry` events
