# CrickFlow — Implementation Status (Agent Handoff)



**Last updated:** Account deletion + release keystore script  

**Firebase project:** `crickflow-b06bc`  

**Android package:** `com.mavixas.crickflow`



---



## MVP feature status — Complete



| Area | Status |

|------|--------|

| Auth (Google, Phone, roles) | Done |

| Onboarding + splash routing | Done |

| Matches, scoring, undo, innings | Done |

| Teams, squads (existing + new players) | Done |

| Team join via invite link | Done |

| Tournaments (league + knockout + auto fixtures) | Done |

| Notifications, badges, stats (CF) | Done |

| Deep links + hosting (`/`, `/privacy`, `/open-app`) | Done |
| App Links (`crickflow-b06bc.web.app` + debug SHA in assetlinks) | Done |
| Settings → privacy (url_launcher) | Done |
| RTMP stream heartbeat (Firestore) | Done |

| RTMP (`rtmp_broadcaster`) | Done |

| Viewer / player read-only UX | Done |

| Web admin (hosted `/admin`) | Done |

| Release signing scaffold | Done |
| GitHub Actions (`flutter analyze` + test) | Done |
| Store listing doc + release build script | Done |



---



## Your action items (cannot be automated)



| Step | Doc / script |

|------|----------------|

| Firebase deploy | `scripts/deploy-firebase.ps1` |

| Paste / refresh SHA-256 in assetlinks | `scripts/get-android-sha.ps1`, `scripts/update-assetlinks-sha.ps1` |

| Create release keystore | `docs/ANDROID_RELEASE_SIGNING.md` |

| Device QA | `docs/DEVICE_QA.md` |

| Full release order | `docs/RELEASE_CHECKLIST.md` |

| iOS: enable Associated Domains in Xcode | `ios/Runner/Runner.entitlements` |

| Custom domain `crickflow.app` (optional) | `docs/APP_LINKS.md` |



---



## Key files (recent ship-prep)



| Feature | Files |

|---------|--------|

| Onboarding | `onboarding_screen.dart`, `splash_screen.dart`, `prefs_keys.dart` |

| Team join | `team_join_banner.dart` |

| RTMP | `stream_service.dart`, `live_stream_screen.dart` |

| Hosting | `firebase.json`, `public/index.html`, `public/open-app.html`, `public/privacy.html`, `public/.well-known/` |
| App Links | `deep_link_utils.dart`, Android manifest, `assetlinks.json`, `apple-app-site-association` |

| Signing | `android/app/build.gradle.kts`, `key.properties.example` |

| Scripts | `deploy-firebase.ps1`, `get-android-sha.ps1`, `update-assetlinks-sha.ps1`, `build-release.ps1`, `create-release-keystore.ps1` |
| CI | `.github/workflows/flutter.yml` |



---



## Deploy



```powershell

.\scripts\deploy-firebase.ps1

flutter pub get

flutter run

```



---



## Changelog



| Phase | Changes |

|-------|---------|

| Account deletion | Settings UI, auth repo, Firestore rules |
| Ship prep | GitHub CI, STORE_LISTING, IOS_SETUP, build-release.ps1, README |
| Hosting links | Firebase site root, HTTPS rewrites, privacy page, debug assetlinks, iOS associated domain |
| Ship-prep | Onboarding, hosting, admin, signing, join team, full checklists |

| 2f | RTMP, release docs, team invite |

| 2e | Login roles, viewer mode, match feed |

| 2d | Squad picker, bracket advance |

| 2c | Deep links, knockout, photos |

| 1.5 | Cloud Functions, offline, FCM |


