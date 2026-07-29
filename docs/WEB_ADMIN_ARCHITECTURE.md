# CrickFlow Web Administration System

Enterprise admin panels for CrickFlow. **Separate Flutter Web apps** — they do **not** modify the mobile application, existing Firestore schemas used by mobile, Cloud Functions, Storage layout, scoring, streaming, or notifications.

| Panel | Project | Deploy host | Audience |
|-------|---------|-------------|----------|
| Super Admin | `apps/superadmin` | `superadmin.crickflow.app` | Platform owners |
| Organization Admin | `apps/admin` | `admin.crickflow.app` | Boards, schools, academies, clubs, organizers |
| Shared core | `apps/admin_core` | — | Theme, auth, permissions, shell, widgets |

Firebase project (same as mobile): **`crickflow-b06bc`**.

---

## Non-negotiables

- Do **not** change mobile `lib/`, existing Cloud Functions, scorebug, RTMP/YouTube, privacy/terms URLs, or mobile Auth flows.
- Admin auth uses the **same Firebase Authentication** project as mobile.
- Admin authorization uses additive collections `admin_users` + `admin_roles` (not mobile `users.role`).
- Org admins must never receive global platform data; queries in future modules must filter by `organizationId`.
- Client-side permissions are UX only — prepare Firestore rules + custom claims for real enforcement.

---

## Architecture

```
apps/
  admin_core/          # Shared package (Clean Architecture helpers)
  superadmin/          # Super Admin Flutter Web
  admin/               # Organization Admin Flutter Web
```

### Auth & authorization (current)

1. Email/password or Google Sign-In (Firebase Auth — no anonymous).
2. Session persistence: Remember me → `Persistence.LOCAL`, else `SESSION`.
3. Load `admin_users/{uid}` → `roleId`.
4. Load `admin_roles/{roleId}` permission map (+ user `permissionOverrides`).
5. Panel gate:
   - `superAdmin` → Super Admin app only
   - `admin` → Org Admin app only (requires `organizationId`)
   - any other role / missing profile → Access Denied
6. Route gate: `AdminRoutePermissions` + GoRouter redirect → `/forbidden` when missing a permission.
7. `PermissionGate` widgets as a second line of defense inside pages.
8. After login, `getIdToken(true)` + `idTokenChanges` prepare for future custom claims.

See [ADMIN_USERS_SCHEMA.md](ADMIN_USERS_SCHEMA.md).

### Permissions

Enum `AdminPermission`. Add a value, seed it on `admin_roles`, and register the route in `AdminRoutePermissions`.

### Theme / layout

CrickFlow brand: blue `#1E88E5`, gold `#FFC107`, white, dark gray. Light + dark Material 3.

`AdminShell`: collapsible sidebar, top bar (breadcrumbs, notifications, profile menu with Profile / Account Settings / Theme / Logout).

---

## Run locally

```powershell
cd apps/admin_core; flutter pub get
cd ../superadmin; flutter pub get; flutter run -d chrome
cd ../admin; flutter pub get; flutter run -d chrome --web-port=8081
```

Enable **Google** provider in Firebase Auth. Add authorized domains (`localhost`, later `superadmin.crickflow.app` / `admin.crickflow.app`).

Deploy additive rules:

```powershell
firebase deploy --only firestore:rules --project crickflow-b06bc
```

---

## Deploy (later)

Register Firebase Hosting **sites** (do not replace the existing `public/` scorecard hosting). See earlier notes in this doc / Firebase Console multi-site setup.

Build:

```powershell
cd apps/superadmin; flutter build web --release
cd ../admin; flutter build web --release
```

---

## Foundation checklist

- [x] Project structure + shared core
- [x] Firebase web apps + options
- [x] Auth (email/password + Google) + session persistence
- [x] `admin_roles` + `admin_users` authorization model
- [x] Role / panel / route permission guards
- [x] Access Denied + Forbidden screens
- [x] Profile menu (Profile, Account Settings, Theme, Logout)
- [x] Placeholder dashboard + navigation
- [ ] Feature modules (users, matches, …) — **not in this phase**
- [ ] Custom claims Cloud Function — prepared, not implemented
