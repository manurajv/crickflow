# Android release signing

## 1. Create a keystore (once)

```bash
keytool -genkey -v -keystore crickflow-release.keystore -alias crickflow -keyalg RSA -keysize 2048 -validity 10000
```

Store the keystore outside the repo (e.g. `C:\Users\You\keys\crickflow-release.keystore`).

## 2. Configure Gradle

1. Copy `android/key.properties.example` → `android/key.properties`
2. Set `storeFile` to the keystore path (relative to `android/` folder)
3. Add passwords

`android/app/build.gradle.kts` loads `key.properties` automatically when present.

## 3. Register SHA fingerprints in Firebase

```powershell
.\scripts\get-android-sha.ps1
```

Add **SHA-1** and **SHA-256** to Firebase Console → Project settings → Your apps → Android.

## 4. Build release

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`
