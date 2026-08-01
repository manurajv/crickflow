# Android release signing

## 1. Create a keystore (once)

**Windows (recommended):**

```powershell
.\scripts\create-release-keystore.ps1
```

Creates `%USERPROFILE%\Documents\keys\crickflow\crickflow-release.keystore` (outside the repo) and helps set `key.properties`.

Override location:

```powershell
$env:CRICKFLOW_KEYSTORE_PATH = "D:\secure\crickflow-release.keystore"
.\scripts\create-release-keystore.ps1
```

**Manual:**

```bash
keytool -genkey -v -keystore crickflow-release.keystore -alias crickflow -keyalg RSA -keysize 2048 -validity 10000
```

Keep the keystore **outside** the git repo (e.g. `Documents\keys\crickflow\`).

## 2. Configure Gradle

1. Ensure `android/key.properties` exists (gitignored)
2. Set `storeFile` to the **absolute** keystore path (forward slashes OK on Windows)
3. Set `storePassword` / `keyPassword` to the passwords you typed in `keytool` (usually the same)

Example:

```properties
storePassword=...
keyPassword=...
keyAlias=crickflow
storeFile=C:/Users/manur/Documents/keys/crickflow/crickflow-release.keystore
```

`android/app/build.gradle.kts` loads `key.properties` automatically when present.

## 3. Register SHA fingerprints in Firebase

```powershell
.\scripts\get-android-sha.ps1
```

Add **SHA-1** and **SHA-256** for **debug** and **upload/release** keystores to Firebase Console → Project settings → Your apps → Android.

After the first Play upload (App Signing enabled), also add the **App signing key** fingerprints from Play Console (Classical / the cert that actually signs user installs). Those differ from your upload keystore. Missing them causes Google Sign-In `ApiException: 10` on Internal testing / production while debug still works.

Verify the live Play APK with `apksigner verify --print-certs` if unsure which Play cert is active.

## 4. Build release

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`
