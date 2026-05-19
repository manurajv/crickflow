# Device QA — Google, Phone, RTMP

Run on **physical** Android and iOS devices before release.

## Prerequisites

- [ ] `flutter pub get`
- [ ] Firebase Auth: Google + Phone enabled
- [ ] SHA fingerprints in Firebase (Android) — run `scripts/get-android-sha.ps1`
- [ ] `firebase deploy` completed — run `scripts/deploy-firebase.ps1`

## Android

### Google Sign-In

1. Run `.\scripts\get-android-sha.ps1`
2. Firebase Console → Project settings → Android app → Add fingerprint (SHA-1 + SHA-256)
3. Download updated `google-services.json` if prompted → `android/app/`
4. `flutter run` on device
5. Login → **Continue with Google** → account picker → lands on Home

**Fail:** `DEVELOPER_ERROR` / sign-in cancelled → SHA mismatch or wrong package name.

### Phone OTP

1. Login → enter `+94XXXXXXXXX` → **Send OTP**
2. Enter SMS code → **Verify OTP**
3. New user profile created with chosen role

**Fail:** SMS not received → enable Phone auth, check quota, test with test numbers in Firebase.

### RTMP

1. Sign in as **Scorer/Organizer**
2. Create match → Match Center → **Go Live**
3. YouTube Studio → copy RTMP URL + stream key
4. **Go Live** → grant camera/mic → status **LIVE**
5. Confirm stream on YouTube Live Dashboard

## iOS

### Setup

1. Open `ios/Runner.xcworkspace` in Xcode
2. Signing & Capabilities → select Team
3. Enable **Associated Domains**: `applinks:crickflow.app` (see `Runner.entitlements`)
4. `pod install` in `ios/` if needed
5. `flutter run` on device

### Google Sign-In

Same as Android; add iOS URL scheme from `GoogleService-Info.plist` in Firebase.

### RTMP

Same flow as Android; confirm camera/mic prompts.

## Role matrix (quick)

| Action | Organizer | Player | Viewer |
|--------|-----------|--------|--------|
| Create match | Yes | No | No |
| Live scoring | Yes | No | No |
| View scorecard | Yes | Yes | Yes |
| Join team via link | Yes | Yes | Yes |
| RTMP stream | Yes | No | No |

## Deep links

```bash
adb shell am start -a android.intent.action.VIEW -d "crickflow://match/MATCH_ID/scorecard"
adb shell am start -a android.intent.action.VIEW -d "crickflow://teams/TEAM_ID"
```

After hosting: `https://crickflow-b06bc.web.app/...` (Firebase default domain) until custom domain connected.
