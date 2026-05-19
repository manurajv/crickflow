# CrickFlow — Agent Instructions

1. Read **`docs/IMPLEMENTATION_STATUS.md`** first — single source of truth for what is done vs pending.
2. Read **`docs/RELEASE_CHECKLIST.md`** for full ship steps (Firebase, signing, QA).
3. For backend work, read **`docs/FUNCTIONS.md`** — Cloud Functions under `functions/src/`.
4. Follow **`docs/MVP_ROADMAP.md`** for phase scope.
5. Match patterns: Riverpod, `lib/features/*`, repositories in `lib/data/repositories/`.
6. Firebase project: **crickflow-b06bc** — options in `lib/config/firebase_options.dart`.
7. After changes: `flutter analyze`, update `IMPLEMENTATION_STATUS.md`.
8. Deploy: `.\scripts\deploy-firebase.ps1` (Windows) or see RELEASE_CHECKLIST.
9. Do not commit unless the user asks. Never commit `android/key.properties` or keystores.
