# Phase 3 — Advanced features

Phases **1**, **1.5**, and **2** are complete. Phase 3 builds on the live scoring + RTMP foundation.

## Recommended order

| Sub-phase | Theme | Effort | Depends on |
|-----------|--------|--------|------------|
| **3.1** | Highlights + auto commentary (rule-based) | 1–2 weeks | Ball events, FCM |
| **3.2** | In-app stream viewer (YouTube / HLS embed) | 1–2 weeks | `match.stream`, hosting |
| **3.3** | WebRTC low-latency publish/view | 3–6 weeks | Signaling, TURN/STUN, native plugins |
| **3.4** | Multi-camera (2nd RTMP / PiP) | 2–4 weeks | 3.2 or 3.3 |
| **3.5** | Fantasy leagues | 4–8 weeks | Stats CF, new collections |
| **3.6** | Ball tracking + AI highlights | 8+ weeks | Video pipeline, ML (Vertex / custom) |

Ship **3.1** before Play Store if you want “highlights” in marketing; **3.2** improves viewers without replacing YouTube RTMP.

---

## 3.1 — Highlights & commentary ✅

**Goal:** Automatic “moments” from scoring — no ML yet.

- [x] Classify boundaries, sixes, wickets as highlights
- [x] Richer auto-commentary on each ball
- [x] Match Highlights screen (timeline from `ball_events`)
- [x] Share highlight as text + deep link
- [x] Stream timestamps on highlights when `stream.startedAt` is set
- [x] Cloud Function: `matches/{id}/highlights/{eventId}`

**Later (true AI):** speech-to-text on stream audio, LLM summary, auto clip export — needs 3.6.

---

## 3.2 — In-app viewing ✅

- [x] YouTube watch URL on `match.stream` (Go Live settings)
- [x] In-app embed on Match Center when stream is live
- [x] Public web scorecard at `/live/{matchId}` (Firestore `public/scorecard`)
- [ ] HLS restream (FFmpeg on Cloud Run) — optional

---

## 3.3 — WebRTC (in progress)

See [WEBRTC.md](WEBRTC.md).

- [x] Firestore signaling room + Go Live toggle
- [x] Viewer screen (beta) + join signaling
- [x] Client-side public scorecard sync (fallback if CF slow)
- [ ] `flutter_webrtc` peer connection (offer/answer/ICE)
- [ ] TURN server for production NAT traversal

---

## 3.4 — Multi-camera ✅

See [MULTI_CAMERA.md](MULTI_CAMERA.md).

- [x] `secondaryYoutubeWatchUrl` on match stream
- [x] Go Live fields + viewer segmented switch (app + web)
- [ ] In-app PiP layout (optional polish)

---

## 3.5 — Fantasy cricket ✅ (MVP)

See [FANTASY.md](FANTASY.md).

- [x] `fantasy_leagues` + `entries` subcollection
- [x] Points engine from `ball_events`
- [x] Join code, squad picker, leaderboard
- [ ] Tournament multi-match leagues
- [ ] CF auto-scoring on each ball

---

## 3.6 — Ball tracking & AI

- Camera ML (TensorFlow Lite / MediaPipe) or cloud video API
- Train on local tennis-ball / hard-ball datasets
- Auto-mark ball events; human scorer confirms
- Highlight reels from detected boundaries

---

## Agent handoff

When continuing Phase 3:

1. Read this file + `docs/IMPLEMENTATION_STATUS.md`
2. Finish open checkboxes in **3.1** before starting 3.2
3. Do not block Play Store on 3.3–3.6
