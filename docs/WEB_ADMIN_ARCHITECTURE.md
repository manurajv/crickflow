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
- Admin roles live in an **additive** collection `admin_users` (not the mobile `users.role` field).
- Org admins must never receive global platform data; queries in future modules must filter by `organizationId`.

---

## Architecture

```
apps/
  admin_core/          # Shared package (Clean Architecture helpers)
  superadmin/          # Super Admin Flutter Web
  admin/               # Organization Admin Flutter Web
```

### Feature layout (each app)

```
lib/features/<feature>/{data,domain,presentation,providers,widgets,models}/
```

Modules are scaffolded as empty folders; only Dashboard + Auth + Shell are implemented in foundation phase.

### Auth & role routing

1. Email/password Firebase Auth (no anonymous).
2. Load `admin_users/{uid}`.
3. Resolve `platformRole` → permissions via `AdminPermissionCatalog`.
4. GoRouter redirect:
   - unauthenticated → `/login`
   - wrong panel / missing profile / inactive → `/access-denied`
   - authorized → dashboard shell

| Role | Super Admin app | Org Admin app |
|------|-----------------|---------------|
| `superAdmin` | ✅ | ❌ |
| `admin` | ❌ | ✅ (requires `organizationId`) |
| `moderator` | ❌ | ✅ |
| `tournamentAdmin` | ❌ | ✅ |
| `support` | ❌ | ✅ |

### Permissions

Enum `AdminPermission` + `PermissionGate` widget. Add new permissions to the enum and map them in `AdminPermissionCatalog.forRole`.

### Theme

CrickFlow brand: blue `#1E88E5`, gold `#FFC107`, white, dark gray. Light + dark Material 3. Desktop / tablet / laptop / wide (no mobile layout).

### Layout

`AdminShell`: collapsible sidebar, top bar (breadcrumbs, notifications stub, theme toggle, profile menu), scrollable content, optional future `endDrawer`.

---

## `admin_users` document (additive)

```json
{
  "email": "owner@crickflow.app",
  "displayName": "Platform Owner",
  "platformRole": "superAdmin",
  "organizationId": null,
  "organizationName": null,
  "permissionGrants": [],
  "permissionDenies": [],
  "isActive": true
}
```

Org admin example:

```json
{
  "email": "admin@university.lk",
  "displayName": "Uni Admin",
  "platformRole": "admin",
  "organizationId": "org_abc",
  "organizationName": "Example University",
  "isActive": true
}
```

Create these docs manually in Firestore Console until a provisioner module exists. The user must already exist in Firebase Authentication.

Deploy the additive `admin_users` Firestore rules (already added to root `firestore.rules`) before testing against production:

```powershell
firebase deploy --only firestore:rules --project crickflow-b06bc
```

---

## Run locally

```powershell
cd apps/admin_core; flutter pub get
cd ../superadmin; flutter pub get; flutter run -d chrome
cd ../admin; flutter pub get; flutter run -d chrome --web-port=8081
```

Authorized domains: add `localhost` (already typical) and later `superadmin.crickflow.app` / `admin.crickflow.app` under Firebase Auth → Settings → Authorized domains.

---

## Deploy (later)

Register Firebase Hosting **sites** (do not replace the existing `public/` scorecard hosting):

```text
firebase hosting:sites:create crickflow-superadmin
firebase hosting:sites:create crickflow-admin
```

Then add multi-site targets in root `firebase.json` pointing at each app’s `build/web` output. **Do not** overwrite the current `hosting.public: "public"` scorecard site without an explicit multi-target migration.

Build:

```powershell
cd apps/superadmin; flutter build web --release
cd ../admin; flutter build web --release
```

---

## Foundation checklist (this phase)

- [x] Project structure + shared core
- [x] Firebase web apps registered + options wired
- [x] GoRouter + role redirects
- [x] Auth (email/password) + `admin_users` profile
- [x] Permission catalog + `PermissionGate`
- [x] Theme (light/dark) + responsive shell
- [x] Navigation (sections prepared; modules placeholder)
- [x] Placeholder dashboard cards
- [x] Reusable base widgets
- [ ] Feature modules (users, matches, …) — **not in this phase**
