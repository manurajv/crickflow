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

**Before production:** replace `REPLACE_WITH_SHA256_...` in `assetlinks.json` with your release SHA-256 (`scripts/get-android-sha.ps1`).

## 1. Host `assetlinks.json` (Android)

At: `https://crickflow.app/.well-known/assetlinks.json`

Template (replace SHA-256 fingerprint):

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.mavixas.crickflow",
      "sha256_cert_fingerprints": [
        "YOUR_RELEASE_SHA256_FINGERPRINT"
      ]
    }
  }
]
```

Get fingerprint:

```bash
keytool -list -v -keystore your-release.keystore -alias your-alias
```

## 2. iOS Universal Links

Host `https://crickflow.app/apple-app-site-association` and enable Associated Domains in Xcode.

## 3. Verify Android

```bash
adb shell pm get-app-links com.mavixas.crickflow
```

Manifest already includes `android:autoVerify` for `https://crickflow.app`.
