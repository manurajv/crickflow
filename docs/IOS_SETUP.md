# iOS setup (Firebase + App Links)

Required before `flutter run` on a physical iPhone or App Store submission.

## 1. GoogleService-Info.plist

This file is **not** in the repo (download per machine / team).

1. [Firebase Console](https://console.firebase.google.com/project/crickflow-b06bc/settings/general) → Your apps → **iOS** (`com.mavixas.crickflow`)
2. If no iOS app exists: **Add app** → bundle ID `com.mavixas.crickflow`
3. Download **GoogleService-Info.plist**
4. Place at: `ios/Runner/GoogleService-Info.plist`
5. In Xcode: drag into **Runner** target (copy if needed, ensure target membership)

Or run:

```bash
flutterfire configure
```

## 2. Xcode capabilities

1. Open `ios/Runner.xcworkspace`
2. **Signing & Capabilities** → select your Team
3. **+ Capability** → **Associated Domains** (if not present)
4. Domains (already in `Runner.entitlements`):
   - `applinks:crickflow-b06bc.web.app`
   - `applinks:crickflow.app` (optional custom domain)

## 3. Apple App Site Association

Update `public/apple-app-site-association`:

- Replace `TEAMID` with your Apple Developer Team ID
- Deploy hosting: `firebase deploy --only hosting`

## 4. CocoaPods

```bash
cd ios
pod install
cd ..
flutter run
```

## 5. Build for TestFlight

```bash
flutter build ipa --release
```

Or **Product → Archive** in Xcode.
