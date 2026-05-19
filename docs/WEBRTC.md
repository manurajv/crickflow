# WebRTC low-latency streaming (Phase 3.3)

## Current (beta)

| Piece | Status |
|-------|--------|
| Firestore signaling room `matches/{id}/webrtc/room` | Done |
| Broadcaster toggle on **Go Live** | Done |
| Viewer screen `/match/{id}/webrtc` | Done |
| `flutter_webrtc` peer media | **Not started** |

RTMP + YouTube remain the production path. WebRTC is optional signaling for testing.

## Signaling document

`matches/{matchId}/webrtc/room`:

| Field | Description |
|-------|-------------|
| `publisherId` | Firebase Auth uid of broadcaster |
| `status` | `open` \| `closed` |
| `viewerCount` | Incremented when viewers tap Join |
| `updatedAt` | Server timestamp |

## Broadcaster flow

1. **Go Live** → enable **WebRTC beta (signaling)**
2. **Go Live** → opens room + RTMP as today
3. **End stream** → closes room

## Viewer flow

1. Match Center → **Low latency (beta)** (when enabled)
2. **Join signaling room** — registers viewer count
3. YouTube embed still shown until peer media ships

## Next implementation steps

1. Add `flutter_webrtc` (verify Android/iOS build with `rtmp_broadcaster`)
2. STUN: `stun:stun.l.google.com:19302` (dev); TURN for production (Twilio / Cloudflare)
3. Exchange SDP offer/answer via subcollection `webrtc/room/candidates`
4. Publisher: second video track or replace RTMP for beta users

## Security

- Signaling writes: match scorers + signed-in viewers (increment only)
- No stream keys in `public/` or `webrtc/` docs
- Tighten viewer write rules before production WebRTC media
