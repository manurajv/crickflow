# CrickFlow Broadcast Module

Professional live streaming for cricket — native camera RTMP, OBS/external encoder mode, TV overlays, and pluggable destinations (YouTube, Facebook, Twitch, custom RTMP).

**Entry route:** `/match/:id/stream` → `StreamingDashboardScreen`  
**Public API:** `import '.../features/streaming/broadcast_module.dart';`

---

## Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                     BroadcastSessionController                   │
│  credentials (OAuth/API) → native RTMP or external encoder live  │
└────────────┬───────────────────────────────┬────────────────────┘
             │                               │
   Native mode│                               │OBS / external mode
             ▼                               ▼
┌────────────────────────┐       ┌──────────────────────────────┐
│ StreamService          │       │ RTMP URL + key + overlay URL │
│ camera → RTMP encoder  │       │ (OBS streams; app syncs score)│
└────────────┬───────────┘       └──────────────────────────────┘
             │
             ▼
┌────────────────────────┐       Firestore overlay + ball_events
│ StreamStudioCompositor │◄────── (same scoring module, no duplicate)
│ scorebug + event GFX   │
└────────────────────────┘
             │
             ▼
        RTMP → YouTube / Facebook / Twitch / custom server
```

**Phase 3 (done):** GPU overlay burn-in — Flutter captures overlay PNG at encoder resolution → native pedro `ImageObjectFilterRender` on **`OpenGlView`** (`SafeOpenGlView`). `LightOpenGlView.setFilter()` is a no-op in pedro 1.9.6 and must not be used for burn-in.

---

## Module layout

```
lib/features/streaming/
├── broadcast_module.dart          # Barrel exports
├── studio/
│   └── broadcast_session_controller.dart   # Go live / end / credentials
├── camera/
│   └── presentation/professional_camera_panel.dart
├── encoder/                       # StreamService remains in lib/data/services/
├── overlay/                       # Compositor + scorebug widgets (presentation/)
├── graphics/                      # Event detector, sponsor rotation (domain/)
├── youtube/                       # YouTubeDestinationProvider
├── facebook/                      # FacebookDestinationProvider
├── twitch/                        # TwitchDestinationProvider
├── rtmp/                          # CustomRtmpDestinationProvider
├── obs/
│   ├── obs_encoder_utils.dart
│   └── presentation/obs_setup_section.dart
├── chat/                          # YouTube live chat panel
├── analytics/
│   └── broadcast_analytics_service.dart
├── settings/
│   └── presentation/stream_mode_selector.dart
├── data/                          # Config, repos, models
├── domain/                        # Enums, permissions, destinations
├── services/                      # Platform CF client (legacy name)
└── presentation/                  # Dashboard, providers, widgets
```

Add new providers (Instagram, Kick, SRT) by implementing `StreamDestinationProvider` and registering in `StreamDestinationRegistry`.

---

## Streaming modes

| Mode | Description |
|------|-------------|
| **Native camera** | Phone camera → hardware H.264 → RTMP. Default. |
| **OBS / external** | App provides RTMP + browser overlay URL; encoder runs in OBS/vMix. |

Configure in **Stream setup → Broadcast mode**.

---

## Destinations

| Platform | OAuth auto-create | Manual RTMP |
|----------|-------------------|-------------|
| YouTube | ✅ `createYouTubeLiveStream` CF | ✅ |
| Facebook | Stub CF | ✅ default RTMP URL |
| Twitch | Stub CF | ✅ |
| Custom RTMP | — | ✅ saved servers |

---

## Camera

- Physical lens switching via `CameraLensCatalog` + native `PedroCameraBridge`
- Digital zoom only when a single back sensor is reported
- Pro controls: exposure, focus lock, tap-to-focus, white balance, HDR, stabilization (config persisted; native wiring incremental)

---

## Overlays

- **Preview:** `StreamStudioCompositor` stacks scorebug + animated event graphics
- **OBS:** Browser source → `/live/{matchId}` public scorecard page
- **Events:** `StreamEventDetector` maps ball events; extended enum for powerplay, rain, victory, DRS, etc.
- **Sponsors:** Tournament sponsors rotate on scorebug (15s)

---

## Integration (reuse, no duplication)

| Existing module | Used for |
|-----------------|----------|
| `ball_events` / scoring | Overlay updates, replay markers |
| `overlay/current` Firestore | Scorebug state |
| `match.stream` metadata | Live status, RTMP, YouTube URL |
| `StreamPermissionService` | Who can go live |
| `onStreamStatusChanged` CF | Follower notifications |
| Tournament sponsors / officials | Overlay branding |

---

## Stream pipeline debug (logcat)

Filter Android Studio Logcat or adb:

```text
adb logcat -s CrickFlowStream
```

| Log line | Meaning |
|----------|---------|
| `PREVIEW_LOCKED` | In-app preview GL size/rotation frozen |
| `GO_LIVE` | `prepareVideo` size + `setStreamRotation` (landscape = same preview + rotate 90° left) |
| `STREAM_ROTATION` | Encoder rotation applied (0 portrait, 270 landscape) |
| `PIPELINE_LINKED` | Preview restored after go-live; `rtmpAdvertised=` is what YouTube receives |
| `OVERLAY_BURNIN` | Score overlay PNG composited onto encoder |

Flutter overlay capture uses the same tag in debug builds: `[CrickFlowStream]`.

**Landscape model:** portrait already works — encoder reads the **same** preview GL frame (`720×1280`), then `setStreamRotation(270)` rotates 90° left for YouTube 16:9. Preview is unchanged.

---

## Deferred (roadmap)

- Facebook/Twitch OAuth + API live create
- SRT ingest
- Replay buffer / instant replay clips
- Viewer analytics (YouTube Analytics API)
- Chat send + moderation
- Sponsor logo images / video ads on stream
- Full tap-to-focus native API on all devices

See [STREAMING_BACKLOG.md](STREAMING_BACKLOG.md) and [STREAMING_SETUP.md](STREAMING_SETUP.md).
