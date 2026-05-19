# Remaining features (honest scope)

CrickFlow **core product** (scoring, teams, tournaments, streaming, fantasy, community, match hub) is implemented. The items below need **external infrastructure**, **store accounts**, or **ML pipelines** — not only Flutter UI.

## Shippable now (your manual steps)

| Item | Action |
|------|--------|
| Firebase deploy | `.\scripts\deploy-firebase.ps1` |
| Firestore indexes | Included in deploy |
| Release signing | `docs/ANDROID_RELEASE_SIGNING.md` |
| Device QA | `docs/DEVICE_QA.md` |
| Play Store listing | `docs/PLAY_STORE_READINESS.md` |

## In-app — done in latest pass

| Feature | Status |
|---------|--------|
| Discover (matches, tournaments, teams by location) | Done |
| Analytics (filtered stats + nav from Profile) | Done |
| Player detail `/players/:id` | Done |
| Badge gallery (Profile + player) | Done |
| Fantasy auto-scoring on each ball (Cloud Function) | Done |
| Store / PRO roadmap screen | Done (no IAP) |
| Settings offline sync info | Done |

## Requires additional engineering

| Feature | Why not “one PR” |
|---------|------------------|
| **WebRTC peer video** | `flutter_webrtc` + TURN server + Android/iOS build matrix with RTMP |
| **HLS restream** | FFmpeg on Cloud Run, CDN, player integration |
| **AI ball tracking / clips** | Video pipeline, labeled datasets, Vertex or custom ML |
| **In-app purchases (PRO)** | Play Console / App Store products, receipt validation |
| **Community marketplace** | Payments, bookings, messaging beyond posts |
| **Tournament multi-match fantasy** | New league model + CF batch jobs |

## Recommended order after ship

1. WebRTC media OR keep YouTube/RTMP as primary and hide beta label  
2. Play Store release with current MVP  
3. IAP for PRO when monetization is ready  
4. AI highlights when video budget exists  

See [PHASE3_ROADMAP.md](PHASE3_ROADMAP.md) and [WEBRTC.md](WEBRTC.md).
