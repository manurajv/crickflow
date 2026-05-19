# CrickFlow — Agent Instructions

1. Read **`docs/IMPLEMENTATION_STATUS.md`** first — single source of truth for what is done vs pending.
2. Read **`docs/RELEASE_CHECKLIST.md`** for full ship steps (Firebase, signing, QA).
3. iOS: **`docs/IOS_SETUP.md`** — `GoogleService-Info.plist` is required on device.
4. Store copy: **`docs/STORE_LISTING.md`** — privacy URL, descriptions.
5. For backend work, read **`docs/FUNCTIONS.md`** — Cloud Functions under `functions/src/`.
6. Follow **`docs/MVP_ROADMAP.md`** and **`docs/PHASE3_ROADMAP.md`** for phase scope.
7. Match patterns: Riverpod, `lib/features/*`, repositories in `lib/data/repositories/`.
8. Firebase project: **crickflow-b06bc** — options in `lib/config/firebase_options.dart`.
9. After changes: `flutter analyze`, update `IMPLEMENTATION_STATUS.md`.
10. Deploy: `.\scripts\deploy-firebase.ps1` (Windows) or see RELEASE_CHECKLIST.
11. Release AAB: `.\scripts\build-release.ps1`
12. Do not commit unless the user asks. Never commit `android/key.properties` or keystores.
