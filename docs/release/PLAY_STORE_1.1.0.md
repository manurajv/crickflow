# Play Store update — CrickFlow 1.1.0 (versionCode 12)

Use this checklist to update the existing listing for `com.mavixas.crickflow`.
This is an **update**, not a new app.

- **versionName:** `1.1.0`
- **versionCode:** `12` (repo was `1.0.0+11`; the live Play listing shows version **1.0.0**, last updated **15 Sep 2026**. The public listing does not show versionCode; 12 is higher than the repo’s previous 11. If Play Console already has a versionCode ≥ 12, bump again before uploading.)
- **Application ID:** `com.mavixas.crickflow`
- **App bundle:** `C:\Users\manur\StudioProjects\crickflow\build\app\outputs\bundle\release\app-release.aab` (after the release build)
- **Target SDK:** 36 (Android 16) — meets Google Play’s 31 Aug 2026 requirement that updates target API 36+
- **Min SDK:** 26 (Android 8.0)
- **AdMob:** release builds use production units (`forceTestAds` is false). Only debug builds, or an explicit `admin_admob_config/settings.testMode == true`, use Google test units.
- **Crashlytics / Analytics:** Crashlytics is enabled in non-debug builds.

## Release notes (en-US, under 500 characters)

```
Organize series and clubs with document-backed join requests. Message CrickFlow support from Help, or reach us by email and WhatsApp. Cricket profiles now show the same trophies, badges, and play styles as the app. Live-stream mic starts at zero so you set your own level. Notification preferences also work on the website, with reliability fixes throughout.
```

Character count: 358 (including spaces, excluding the wrapping fences).

Shorter alternative if the console rejects line length:

```
Series and club join requests, CrickFlow Help and support chat, richer cricket profiles, a quieter live-stream mic default, website notification settings, and reliability fixes.
```

## Data safety form — what to change

The current Play listing already declares in-transit encryption and that users can request deletion. Update **Data safety** for data this update newly collects or newly emphasizes. Do **not** mark data as sold. Do **not** use these types for advertising personalization unless you later change the product.

### 1. Support chat messages (NEW)

Play category: **Messages → Other in-app messages** (and, if the form still lists it separately, **User-generated content → Other user-generated content**).

| Question | Answer |
| --- | --- |
| Is this data collected? | Yes |
| Is this data shared? | Yes — with CrickFlow support staff who have the Support permission. Not shared with advertisers or sold. |
| Is this data processed ephemerally? | No — messages are stored in `support_threads` so the user and staff can continue the conversation. |
| Required or optional? | Optional. A signed-in user starts a thread from CrickFlow Help. Guests can still see contact emails and WhatsApp. |
| Why is it collected? | App functionality; Customer support |
| Is it encrypted in transit? | Yes |
| Can users request deletion? | Yes, by deleting their account or by asking support. Staff may keep a limited copy if needed to finish an open case, then delete it. |

### 2. Series / organization registration documents and photos (NEW since the 1.0.0 store build)

Collected only when a series or organization asks for them as part of a join or add-player request.

Play categories to review and enable if not already declared:

- **Photos and videos → Photos** (ID photos / document images)
- **Files and docs → Files and docs** (uploaded registration documents)
- **Personal info → User IDs** (already collected) and, if a series asks for it, **Government ID** (national ID / passport number)

| Question | Answer |
| --- | --- |
| Is this data collected? | Yes, when that series/organization requires it |
| Is this data shared? | Yes — with organizers and staff of that series/organization only, so they can review the request. Not sold. Not used for ads. |
| Required or optional? | Optional at the app level. Required only for that specific registration if the organizer turns the field on. |
| Why is it collected? | App functionality (eligibility and registration) |
| Is it encrypted in transit? | Yes |
| Can users request deletion? | Yes, by asking the organizer or CrickFlow support, or by deleting their account |

### 3. Already collected — confirm, do not remove

These were already part of CrickFlow and should stay declared if they already are:

- Name, email, phone number, date of birth (account / profile)
- Approximate or precise location (optional nearby filters and venues; both `ACCESS_COARSE_LOCATION` and `ACCESS_FINE_LOCATION` are in the manifest)
- Photos (profile and team images)
- App activity / diagnostics (Crashlytics in release)
- Device or other IDs (Firebase Auth, FCM, AdMob)

Email, phone, and date of birth are being **copied** to a private `users/{uid}/private/profile` subdocument. They are **still also on the public user document** in this release so the current Play Store app (1.0.0) keeps working. Do **not** tell the form that this PII is no longer collected or is no longer visible to the backend. A later update can remove it from the public document after users have upgraded.

### 4. Advertising (AdMob)

Release builds serve production AdMob banners/native ads on non-critical screens. Declare **App activity** / **Device or other IDs** as collected and shared with advertising partners if that is not already set. Ads are not shown on scoring, streaming, auth, or payments screens.

## Permission declarations

Justify any Play Console permission declaration that is missing or newly flagged. Current Android manifest permissions and why:

| Permission | Why it is needed |
| --- | --- |
| `CAMERA` | Live streaming and profile/registration photos |
| `RECORD_AUDIO` | Live streaming commentary |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CAMERA`, `FOREGROUND_SERVICE_MICROPHONE` | Keep the camera/mic stream running while the app is in the background during a broadcast |
| `POST_NOTIFICATIONS` | Match, team, follower, and support-reply alerts |
| `INTERNET` | Online scoring, streaming, auth, and sync |
| `WAKE_LOCK` | Keep a live stream or scoring session from sleeping |
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | Optional nearby matches/grounds; user can decline |
| `WRITE_EXTERNAL_STORAGE` (legacy, max SDK limited in the manifest) | Saving images on older Android versions |
| `ACCESS_MEDIA_LOCATION` | Reading EXIF when the user picks a photo |

No new dangerous permission was added solely for this 1.1.0 update. Reconfirm camera, microphone, notifications, and location in the Play App content / Permissions forms if Console prompts you.

## Content rating and target audience

- The existing listing is **Everyone**. This update does not add gambling, dating, or graphic violence.
- The app already has community posts, chat, and now **support chat** plus organizer-review of ID documents. In the content rating questionnaire, confirm **Users Interact** / user-generated content is declared if the form asks. If that box was empty on the 1.0.0 submission, complete it before rolling out to Production.
- Target audience does not need to change for this update unless you previously excluded a category that now applies to UGC. Keep the same target age group you already selected.

## Play Console upload checklist

1. Open [Play Console](https://play.google.com/console) → CrickFlow (`com.mavixas.crickflow`) → **Testing** or **Production** (this is an update to the existing app).
2. Recommended path: upload first to **Internal testing** or **Closed testing**, install on a real device, confirm ads are not labeled “Test Ad”, Google Sign-In works, Help/support chat sends, and a release build is signed.
3. Then promote to **Production** with a **staged rollout**: start at **20%**, then 50%, then 100% after a day or two of Crashlytics looking clean.
4. Create the release, upload `app-release.aab` (version 1.1.0, versionCode 12).
5. Paste the en-US release notes above.
6. Complete **Data safety** changes in the table above. Save and review the declaration.
7. Recheck **Content rating**, **Target audience**, **Ads**, and **News app** declarations.
8. Confirm the upload certificate in Play Console still matches the upload keystore used to sign this AAB (SHA-256 is also printed after the release build; never share keystore passwords).
9. After Play App Signing, the install cert on users’ devices is Play’s app-signing key, which may differ from the upload key. Keep both SHA-1/SHA-256 values in Firebase (Android app) and in the Maps API key restriction if used.
10. Submit the release for review. Do not turn off the previous production release until this one is approved and rolling out.

## What you must do manually

- Upload the AAB and submit the Play Console release (this repo cannot complete the Console form).
- Paste release notes and update Data safety / content rating as above.
- On a physical phone, install the testing-track build and confirm production AdMob (no “Test Ad” label) and Google Sign-In.
- Add the **upload key** SHA-1 / SHA-256 to Firebase and Maps if they are not already there. After the first Play App Signing upload, also add the **app signing** cert from Play Console.
- A **mobile app rebuild / store rollout** is required for Help, hidden PRO nav, support chat, private-profile reads, and this version bump. The website and Super Admin panel are deployed separately to Firebase Hosting.
- iOS is not part of this Android update.
- Later: after most users are on 1.1.0, a follow-up can remove email / phone / date of birth from the public `users/{uid}` document and tighten those rules. Do not do that while 1.0.0 is still widely installed.

## Build and signing notes (already prepared in the repo)

- Signing uses `android/key.properties` (gitignored) and the upload keystore on this PC. Passwords are not stored in the repo.
- Build command: `flutter build appbundle --release`
- Do not force-push this branch. Do not enable `AdMobConfig.forceTestAds`.
