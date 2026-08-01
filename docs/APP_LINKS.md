# App Links (`https://crickflow.app`)

Custom scheme links work today:

- `crickflow://match/{id}/scorecard`
- `crickflow://teams/{id}`

## Firebase Hosting (included in repo)

Files live in `public/`:

- `public/.well-known/assetlinks.json`
- `public/apple-app-site-association`

Deploy:

```bash
firebase deploy --only hosting
```

Default URL: `https://crickflow-b06bc.web.app` until you connect custom domain `crickflow.app`.

`assetlinks.json` should list **every** cert that can install the app:

| Cert | Where from | Why |
|------|------------|-----|
| Debug | `scripts/get-android-sha.ps1` | Local `flutter run` |
| Upload / release keystore | Same script / `keytool` | Sideloaded release APKs |
| **Play App signing** | Play Console → App signing, or `apksigner` on a Play-installed APK | **Store / Internal testing installs** (users get this cert) |

Play re-signs AABs. The upload keystore SHA alone is **not** enough for production App Links or Google Sign-In on Play builds.

## 1. Host `assetlinks.json` (Android)

At: `https://crickflow.app/.well-known/assetlinks.json` (and Firebase hosting mirror).

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.mavixas.crickflow",
      "sha256_cert_fingerprints": [
        "DEBUG_SHA256",
        "UPLOAD_KEYSTORE_SHA256",
        "PLAY_APP_SIGNING_SHA256"
      ]
    }
  }
]
```

Get upload/debug fingerprints:

```bash
keytool -list -v -keystore your-release.keystore -alias your-alias
.\scripts\get-android-sha.ps1
```

Get Play App signing SHA-256 from Play Console, or from a Play install:

```bat
apksigner verify --print-certs play-base.apk
```

## 2. iOS Universal Links

Host `https://crickflow.app/apple-app-site-association` and enable Associated Domains in Xcode.

## 3. Verify Android

```bash
adb shell pm get-app-links com.mavixas.crickflow
```

Manifest already includes `android:autoVerify` for `https://crickflow.app`.
