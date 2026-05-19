# CrickFlow — Agent Instructions

1. Read **`docs/PRODUCT_ARCHITECTURE.md`** for vision, navigation, and roadmap.
2. Read **`docs/IMPLEMENTATION_STATUS.md`** for what is done vs pending.
3. Read **`docs/RELEASE_CHECKLIST.md`** for full ship steps (Firebase, signing, QA).
4. iOS: **`docs/IOS_SETUP.md`** — `GoogleService-Info.plist` is required on device.
5. Store copy: **`docs/STORE_LISTING.md`** — privacy URL, descriptions.
6. For backend work, read **`docs/FUNCTIONS.md`** — Cloud Functions under `functions/src/`.
7. Follow **`docs/MVP_ROADMAP.md`** and **`docs/PHASE3_ROADMAP.md`** for phase scope.
8. Match patterns: Riverpod, `lib/features/*`, repositories in `lib/data/repositories/`.
9. Firebase project: **crickflow-b06bc** — options in `lib/config/firebase_options.dart`.
10. After changes: `flutter analyze`, update `IMPLEMENTATION_STATUS.md`.
11. Deploy: `.\scripts\deploy-firebase.ps1` (Windows) or see RELEASE_CHECKLIST.
12. Release AAB: `.\scripts\build-release.ps1`
13. Do not commit unless the user asks. Never commit `android/key.properties` or keystores.
