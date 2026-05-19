# Play Store readiness

## Is the app ready to publish?

**The product (MVP) is built.** The app is **not** a single button away from the Play Store. You still need **your** steps below.

| Area | Status |
|------|--------|
| Features (scoring, teams, tournaments, stream UI, deep links) | Ready for QA |
| Firebase backend (rules, functions, hosting) | Deployed / scriptable |
| Privacy policy URL | Live on Firebase Hosting |
| Account deletion (in-app) | Implemented |
| Release signing (Play requires release keystore) | **You must create** |
| Physical device QA | **You must run** [DEVICE_QA.md](DEVICE_QA.md) |
| Play Console listing (screenshots, description) | **You must submit** [STORE_LISTING.md](STORE_LISTING.md) |
| iOS App Store | Needs `GoogleService-Info.plist` + Xcode — [IOS_SETUP.md](IOS_SETUP.md) |

### Typical path to Play Store

1. `.\scripts\create-release-keystore.ps1` + `android/key.properties`
2. `.\scripts\build-release.ps1` → upload `.aab`
3. Run [DEVICE_QA.md](DEVICE_QA.md) on a real phone
4. Complete Play Console with URLs from [STORE_LISTING.md](STORE_LISTING.md)
5. Internal testing track → closed testing → production

Estimate: **1–2 days** of your time after keystore + QA, assuming no blockers from Google review.

## Login model (current)

- **One login** — Google or Phone only.
- Default account = **Member** (can score, organize, join squads, stream).
- **Viewer** = optional read-only mode in Profile (for spectators).

Players are not a separate login type; every member can also organize matches.
