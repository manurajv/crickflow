# Play Store launch — what you must do yourself

Code fixes for AdMob, FCM privacy, stream keys, notification spam, and Crashlytics are already in the repo. Complete the steps below before (or right after) uploading the AAB.

---

## 0. Deploy backend changes (required)

From the repo root (Firebase CLI logged into `crickflow-b06bc`):

```powershell
firebase deploy --only firestore:rules,functions
```

Or:

```powershell
.\scripts\deploy-firebase.ps1
```

Without this, new clients write FCM tokens to `users/{uid}/private/fcm` but Functions still need the updated `pushUtils.js`, and notification/stream rules will not match the app.

---

## 1. AdMob (already flipped in code)

- `AdMobConfig.forceTestAds` is now **`false`**.
- Confirm in [AdMob console](https://admob.google.com/) that these units exist and are linked to app `com.mavixas.crickflow`:
  - App ID: `ca-app-pub-7062464075957292~8431810313` (already in `AndroidManifest.xml`)
  - Banner: `…/6280169559`
  - Native: `…/7930227377`
- After first release build, use a **real device** (not debug) and confirm ads are not Google “Test Ad” labels.

---

## 2. Google Maps API key (GCP console)

1. Open [Google Cloud Console](https://console.cloud.google.com/) → project linked to Firebase `crickflow-b06bc`.
2. **APIs & Services → Credentials** → select the Maps key (or create one).
3. Enable: **Maps JavaScript API**, **Geocoding API**, **Places API**.
4. **Application restrictions → Android apps**:
   - Package: `com.mavixas.crickflow`
   - SHA-1: your **release** keystore SHA-1 (from step 3 below)
5. **API restrictions**: limit to the three Maps APIs above.
6. Optional but recommended when building:

```powershell
$env:GOOGLE_MAPS_API_KEY = "your-restricted-key"
.\scripts\build-release.ps1
```

---

## 3. Android release signing

1. If you do not have a keystore yet:

```powershell
.\scripts\create-release-keystore.ps1
```

2. Ensure `android/key.properties` exists (gitignored) with passwords and `storeFile` path. See `docs/ANDROID_RELEASE_SIGNING.md`.
3. Print fingerprints:

```powershell
.\scripts\get-android-sha.ps1
```

4. Firebase Console → Project settings → Your apps → Android `com.mavixas.crickflow` → add **SHA-1** and **SHA-256** (release).
5. Also add the same SHA-1 under the Maps key restriction (step 2).

**Back up the keystore and passwords offline.** Losing them blocks updates under the same Play signing key (unless you use Play App Signing upload key reset).

---

## 4. Build the AAB

```powershell
# optional:
$env:GOOGLE_MAPS_API_KEY = "your-restricted-key"
.\scripts\build-release.ps1
```

Output:

`build\app\outputs\bundle\release\app-release.aab`

Release builds use **R8 minify + resource shrinking** (`android/app/build.gradle.kts`). After enabling, smoke-test a release install (sign-in, scoring, ads, go-live).

Keep the R8 mapping file for Crashlytics / deobfuscation:

`build\app\outputs\mapping\release\mapping.txt`

If `assetlinks.json` changed, redeploy hosting:

```powershell
firebase deploy --only hosting
```

---

## 5. Play Console listing

1. Create app (if needed): package **`com.mavixas.crickflow`**, name **CrickFlow**.
2. Upload AAB to **Internal testing** first (recommended), then Closed / Production.
3. Store listing copy: `docs/STORE_LISTING.md`
4. Privacy policy URL: `https://crickflow-b06bc.web.app/privacy.html`
5. Terms (if asked): `https://crickflow-b06bc.web.app/terms.html`
6. High-res icon: `docs/store/playstore-icon.png`
7. Screenshots (device): login, home, live scoring, scorecard, tournament, live stream
8. Complete **Content rating**, **Data safety** (Auth, location, ads/AdMob, notifications), **Target audience**
9. Confirm in-app **Settings → Delete Account** works (Play policy)

---

## 6. Auth smoke test on a release build

Install the Internal testing build (or `flutter install --release`) and verify:

- [ ] Google Sign-In
- [ ] Phone OTP (needs release SHA in Firebase)
- [ ] Create match → score a few balls
- [ ] Go live (stream key stays local; match doc must **not** show `stream.streamKey` in Firestore console)
- [ ] Follow a player → notification appears for the other user
- [ ] Ads load without “Test Ad”
- [ ] Delete Account

---

## 7. Firebase Console extras (recommended)

1. **Crashlytics**: enable the Crashlytics product for the Android app (first crash report may take a few minutes).
2. **App Check** (still manual / optional for closed beta): Play Integrity for Android — enable when you are ready for public traffic.
3. Confirm Phone Auth and Google Sign-In providers are enabled.

---

## What was fixed in code (no action needed)

| Item | Change |
|------|--------|
| C4 AdMob | `forceTestAds = false` |
| C1 FCM | Token → `users/{uid}/private/fcm`; stripped from parent user doc |
| C2 Stream | `streamKey` / `rtmpUrl` no longer written to public match docs; rules reject them |
| C3 Notifications | Creates require typed allowlist + `addedByUserId == auth.uid` |
| Crashlytics | Wired in `main.dart` + Android Gradle plugin |
| Maps | Docs + `build-release.ps1` supports `GOOGLE_MAPS_API_KEY` |

---

## Suggested order today

1. Deploy rules + functions  
2. Create/configure keystore + Firebase SHA + Maps key restriction  
3. Build AAB → Internal testing  
4. Smoke test checklist  
5. Promote to Production when Internal testing looks good  
