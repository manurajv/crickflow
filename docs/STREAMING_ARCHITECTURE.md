# Live Streaming Architecture

## Phase 1 (MVP)

```
┌──────────────┐     ┌─────────────────┐     ┌──────────────────┐
│ Phone Camera │────▶│ RTMP Publisher  │────▶│ YouTube / Custom │
│  (Flutter)   │     │ (native plugin) │     │   RTMP Server    │
└──────┬───────┘     └─────────────────┘     └──────────────────┘
       │
       │  Firestore: matches/{id}/overlay/current
       ▼
┌──────────────┐
│ Score Overlay│  Composited in-app preview (broadcast graphics)
└──────────────┘
```

### Components

1. **Flutter UI** — `LiveStreamScreen` (landscape), stream settings, Go Live / End.
2. **RTMP Publisher** — `rtmp_broadcaster` plugin (`StreamService` + `LiveStreamScreen`).
3. **Overlay Sync** — Scoring writes `overlay/current`; stream UI reads in real time.
4. **YouTube** — RTMP URL: `rtmp://a.rtmp.youtube.com/live2` + stream key from YouTube Studio.

### Stream Metadata (Firestore)

Stored on `match.stream`:
- `status`: idle | connecting | live | ended | error
- `destination`: youtube | customRtmp
- `rtmpUrl`, `streamKey`
- `viewerCount`, `startedAt`

## Phase 3.2 (viewers)

- Broadcaster pastes **YouTube watch URL** in Go Live → saved as `match.stream.youtubeWatchUrl`
- **Match Center** embeds `youtube.com/embed/{videoId}` via WebView for signed-in viewers
- **Highlights** show `Stream mm:ss` offset when `stream.startedAt` is set

## Phase 3.3+

- WebRTC for ultra-low latency
- Multi-camera switching
- Server-side compositing (overlay burned in via FFmpeg filter)
- HLS output for viewers in-app

## Monitoring

- Heartbeat every 30s while live
- Auto-reconnect on network drop
- Battery-optimized 720p30 default
