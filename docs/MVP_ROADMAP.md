# CrickFlow MVP Roadmap



## Phase 1 — Complete ✅



| Area | Status |

|------|--------|

| Flutter project + folder structure | Done |

| Dark broadcast UI theme | Done |

| Firebase models & repositories | Done |

| Google + Phone auth | Done |

| Single match create & rules | Done |

| Ball-by-ball scoring engine | Done |

| Real-time overlay sync | Done |

| Teams, players, tournaments CRUD | Done |

| All 14+ screens | Done |

| Badge service (client-side) | Done |

| RTMP stream UI scaffold | Done |

| Express API skeleton | Done |

| Architecture documentation | Done |



## Phase 1.5 — Pre-Production



**Tracker:** see `docs/IMPLEMENTATION_STATUS.md` (update when continuing work).



- [x] `flutterfire configure` + production Firebase project

- [x] Firestore security rules hardening + indexes

- [x] Cloud Functions: stats aggregation on match complete

- [x] Native RTMP publisher integration (`rtmp_broadcaster`)

- [x] Firestore offline persistence

- [x] FCM push for match events (token + match topics)

- [x] Player picker in scoring (striker/bowler selection)

- [x] Undo last ball (full reverse in repository)

- [x] Tournament fixture generator
- [x] Team-linked match creation
- [x] Team roster / add players
- [x] End innings & second innings flow
- [x] In-app notifications list



## Phase 2 — Growth (1–2 months)

- [x] Location filter UI (home matches)
- [x] Team logo upload (Firebase Storage)
- [x] Share scorecard text
- [x] Wicket type picker
- [x] Tournament NRR in Cloud Functions
- [x] Location filters on teams / tournaments
- [x] Web admin dashboard (`public/admin/` + Firebase Hosting)
- [x] Knockout bracket visualization
- [x] Player photo upload
- [x] Share deep links
- [x] Viewer-only mode optimizations
- [x] Native RTMP publisher



## Phase 3 — Advanced



- [ ] AI highlights & auto commentary

- [ ] Multi-camera / drone integration

- [ ] Ball tracking

- [ ] Fantasy cricket

- [ ] WebRTC low-latency stream



## Setup Checklist for Developers



1. `flutter pub get`

2. `dart pub global activate flutterfire_cli && flutterfire configure`

3. Enable Auth: Google, Phone in Firebase Console (+ SHA-1 for Android)

4. `firebase deploy --only firestore:rules,firestore:indexes,functions`

5. `cd backend && npm install && npm run dev`

6. `flutter run`



## Agent handoff



Read **`AGENTS.md`** and **`docs/IMPLEMENTATION_STATUS.md`** before continuing.

