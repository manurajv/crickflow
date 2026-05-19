# CrickFlow — Complete Release Checklist

Work through **every** section before Play Store / production demo.

---

## 1. Local setup

```bash
flutter pub get
dart pub global activate flutterfire_cli
flutterfire configure   # project: crickflow-b06bc
```

- [ ] `lib/config/firebase_options.dart` matches your Firebase project
- [ ] `android/app/google-services.json` present

---

## 2. Firebase deploy

```powershell
cd c:\Users\Admin\StudioProjects\CrickFlow
.\scripts\deploy-firebase.ps1
```

Or manually:

```bash
cd functions && npm install && cd ..
firebase deploy --only firestore:rules,firestore:indexes,storage,functions,hosting
```

- [ ] Firestore rules deployed
- [ ] Indexes deployed (no 400 errors)
- [ ] Storage rules deployed
- [ ] Cloud Functions deployed
- [ ] Hosting deployed (`public/.well-known`, admin page)

After hosting, open Firebase Console → Hosting → note URL (e.g. `https://crickflow-b06bc.web.app`).

- [ ] Update `public/.well-known/assetlinks.json` with real SHA-256, redeploy hosting
- [ ] For custom domain `crickflow.app`: connect in Hosting + DNS

---

## 3. Android signing

Follow [ANDROID_RELEASE_SIGNING.md](ANDROID_RELEASE_SIGNING.md).

- [ ] Keystore created
- [ ] `android/key.properties` configured (not committed)
- [ ] Release SHA added to Firebase
- [ ] `flutter build appbundle --release` succeeds

```powershell
.\scripts\get-android-sha.ps1
```

---

## 4. iOS signing

- [ ] Xcode team selected
- [ ] `Runner.entitlements` Associated Domains enabled in Xcode
- [ ] `GoogleService-Info.plist` in `ios/Runner/`
- [ ] `flutter build ipa` or Archive in Xcode

---

## 5. Auth QA

Full matrix: [DEVICE_QA.md](DEVICE_QA.md)

- [ ] Google Sign-In (Android device)
- [ ] Google Sign-In (iOS device)
- [ ] Phone OTP (Android)
- [ ] Phone OTP (iOS)
- [ ] Role picker: Organizer / Player / Viewer on first sign-up

---

## 6. Core app QA

- [ ] Onboarding → Get started → Login
- [ ] Home: match feed, filters, create match (organizer only)
- [ ] Create match → score ball-by-ball → undo ball
- [ ] End innings / 2nd innings / complete match
- [ ] Teams: add existing player + new walk-in player
- [ ] Team invite link → Join team banner
- [ ] Tournaments: league fixtures + knockout bracket + winner advance
- [ ] Scorecard share includes deep link
- [ ] Notifications inbox
- [ ] Profile role change → Player creates `players/{uid}`

---

## 7. RTMP QA (physical device)

- [ ] Camera + mic permissions
- [ ] YouTube RTMP URL + key → Go Live
- [ ] Overlay visible on preview
- [ ] End stream → match stream metadata updated

---

## 8. Backend API (optional)

```bash
cd backend && npm install && npm run dev
```

- [ ] `GET http://localhost:3000/health` returns OK
- [ ] Hosted admin: `/admin/index.html` shows API status when API is running

---

## 9. Store listing prep

- [ ] App name, description, screenshots
- [ ] Privacy policy URL
- [ ] Version bumped in `pubspec.yaml`
- [ ] Upload AAB (Play) / IPA (App Store Connect)

---

## 10. Post-release

- [ ] Monitor Firebase Crashlytics (if enabled later)
- [ ] Monitor Cloud Functions logs for `onMatchCompleted`
- [ ] Community test with 1 real tournament
