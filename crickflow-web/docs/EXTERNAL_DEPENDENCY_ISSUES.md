# External dependency issues

The web platform does **not** patch mobile, Admin, or Super Admin. Issues in those systems are recorded here.

---

## EXTERNAL_DEPENDENCY_ISSUE — Admin grounds collection is not public

**Project:** CrickFlow Admin + Firestore rules (`match /grounds/{groundId}`)  
**Problem:** `grounds` documents are readable only by Super Admin / org admins (`canAdminManageGroundDoc()`).  
**Impact:** Consumer web cannot list official ground registry documents. Mobile also does not browse `grounds/{id}` for fans; it uses match `venue` and tournament `grounds[]`.  
**Suggested resolution (do not implement from this repo):** If a public grounds directory is required, add an explicit public-read rule or a `public_grounds` projection — owned by the backend/mobile team.  
**Web workaround:** Derive venue pages from public `matches` and `tournaments`.

---

## EXTERNAL_DEPENDENCY_ISSUE — Root Hosting URL space

**Project:** Root `firebase.json` Hosting (`public/`)  
**Problem:** Rewrites `/teams/**`, `/tournaments/**`, `/match/**` to `open-app.html`, and `/live/**` to the legacy scorecard.  
**Impact:** The consumer web app cannot share that Hosting site without breaking App Links and the existing `/live` scorecard.  
**Suggested resolution:** New Hosting site (`crickflow` / `crickflow.web.app`) or Firebase App Hosting. Keep apex/`crickflow-b06bc.web.app` as-is.  
**Web workaround:** Independent `crickflow-web` deploy config only.

---

## EXTERNAL_DEPENDENCY_ISSUE — Auth authorized domains

**Project:** Firebase Authentication  
**Problem:** Phone/Google auth will reject unknown domains.  
**Impact:** Production web login failed until `crickflow.web.app` was added. That domain is now on the authorized list.  
**Suggested resolution:** Ops adds authorized domains. No mobile code change.

---

## EXTERNAL_DEPENDENCY_ISSUE — App Check not enabled

**Project:** Mobile production readiness (already documented)  
**Impact:** Web client is equally unprotected from abuse of public API keys.  
**Suggested resolution:** Enable App Check for web when mobile enables it.

---

## EXTERNAL_DEPENDENCY_ISSUE — Storage CORS for browser uploads

**Project:** Firebase Storage bucket CORS (`config/storage-cors.json` at repo root is GET/HEAD only)  
**Problem:** Community, Discover, and profile photo **uploads** from `crickflow.web.app` need PUT/POST. GET already works for displaying images.  
**Impact:** Web can still create text posts; attaching photos fails until CORS includes PUT/POST.  
**Suggested resolution:** Apply `crickflow-web/config/storage-cors.json` with gsutil. Keep `*` GET/HEAD for Flutter web image loads.  
**Web workaround:** Convert images to JPEG client-side and upload to the same paths as mobile (`community/{uid}/`, `opportunities/{uid}/`, `users/{uid}/profile.jpg`).

