# CrickFlow Web — production ops checklist



Use this after `npm run ci` succeeds in `crickflow-web`. None of these steps change the Flutter app, Admin apps, or root Hosting.



## Code (done in repo)



- [x] Isolated `crickflow-web/firebase.json` with site **crickflow**

- [x] Isolated `crickflow-web/.firebaserc` for project `crickflow-b06bc`

- [x] Public URL `https://crickflow.web.app`

- [x] App Hosting public env in `apphosting.yaml`

- [x] CI workflow `.github/workflows/crickflow-web.yml` (lint / test / build only)

- [x] Health file `GET /health.json` (rewritten from `/api/health`)

- [x] Homepage loads live data in the browser (no stale SSR snapshot)

- [x] Signed-in Following strip, community media, transactional likes

- [x] Error boundaries, skip-to-content, CSP + HSTS

- [x] Default Open Graph image, theme-color, web manifest

- [x] Hosting unknown-path rewrite to `/404.html`

- [x] Cache-Control for `_next/static` (immutable) and HTML (must-revalidate)

- [x] Production gate `npm run gate` refuses the mobile Hosting site



## Your next steps

1. **Storage CORS — done** on `gs://crickflow-b06bc.firebasestorage.app` (PUT/POST from crickflow.web.app). Retry a photo upload if you have not yet.

2. **Smoke-test in the browser** (you, signed in) at https://crickflow.web.app  
   - Google or phone login  
   - Upload a photo on Community or Settings  
   - Follow a team  
   - Message from a Discover listing  
   - Open a live match and confirm the score updates  
   - Save a Community post  
   - Create a Discover listing  

3. **Email/password (optional)**  
   [Authentication → Sign-in method](https://console.firebase.google.com/project/crickflow-b06bc/authentication/providers) → enable Email/Password.

4. **Custom domain (optional)**  
   Hosting → site **crickflow** → add `www.crickflow.app`. Leave `crickflow-b06bc.web.app` on mobile Hosting.

5. **Maps / App Check (optional)**  
   Web-restricted Maps key as `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY`, then rebuild. App Check when mobile enables it.



## Deploy command (this folder only)



```powershell

cd crickflow-web

.\scripts\deploy-web.ps1

```



Do not run `firebase deploy --only hosting` from the repository root.

