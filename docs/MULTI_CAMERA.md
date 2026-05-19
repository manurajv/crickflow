# Multi-camera viewing (Phase 3.4)

## Overview

Broadcasters can attach a **second YouTube live URL** (drone, stump cam, side view) alongside the main RTMP/YouTube stream.

## Broadcaster setup

1. **Go Live** → enter main **YouTube watch link** (from your primary stream).
2. Optionally enter **2nd camera YouTube link** (second YouTube live event or channel).
3. Viewers switch between angles in the app.

Each angle uses a separate YouTube live broadcast (two stream keys in YouTube Studio, or two devices).

## Viewer UI

- **Match Center** — segmented control: Main camera | Camera 2
- **Low latency (beta)** — same dual-camera embed
- **Web** — `https://crickflow-b06bc.web.app/live/{matchId}` shows both embeds when configured

## Firestore

On `match.stream`:

| Field | Description |
|-------|-------------|
| `youtubeWatchUrl` | Primary angle |
| `secondaryYoutubeWatchUrl` | Optional second angle |
| `cameraALabel` | Default `Main camera` |
| `cameraBLabel` | Default `Camera 2` |

Synced to `public/scorecard` for the website (no secrets).

## Future

- In-app PiP (picture-in-picture) layout
- Second RTMP publisher from the same phone (not supported by `rtmp_broadcaster` today)
- WebRTC multi-track single peer connection
