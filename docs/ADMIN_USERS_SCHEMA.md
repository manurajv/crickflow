# Admin auth seed data (Firestore)

Additive collections only — do **not** change mobile `users`.

Firestore rules for `admin_users` / `admin_roles` are deployed to **crickflow-b06bc**.

## Create a Super Admin (recommended)

### 1. Create the Auth user

Firebase Console → [Authentication → Users](https://console.firebase.google.com/project/crickflow-b06bc/authentication/users) → **Add user**

- Email + password (or sign in once with Google on the Super Admin login page so Auth creates the user)

Copy the **User UID**.

### 2. Seed role definitions

Firestore → create collection `admin_roles` (if missing), then document **`superAdmin`**:

```json
{
  "label": "Super Admin",
  "description": "Platform owner — full access",
  "allowedPanel": "superAdmin",
  "isSystem": true,
  "permissions": {
    "canViewDashboard": true,
    "canViewProfile": true,
    "canManageAccount": true,
    "canManageUsers": true,
    "canManageTeams": true,
    "canManagePlayers": true,
    "canManageMatches": true,
    "canManageTournaments": true,
    "canManageBroadcast": true,
    "canManageAds": true,
    "canModerateCommunity": true,
    "canSendNotifications": true,
    "canViewAnalytics": true,
    "canManageCms": true,
    "canViewReports": true,
    "canManageSettings": true,
    "canViewLogs": true,
    "canManageOrganizations": true,
    "canAccessGlobalData": true,
    "canManageDiscover": true
  }
}
```

(Optional but recommended) Also add docs `admin`, `moderator`, `tournamentAdmin`, `support`, `viewer` — or run the seed script below.

If `admin_roles/superAdmin` is missing, the app still uses a built-in fallback permission map.

### 3. Link the admin profile

Create collection `admin_users`, document ID = **Auth UID** from step 1:

```json
{
  "email": "you@example.com",
  "displayName": "Platform Owner",
  "roleId": "superAdmin",
  "organizationId": null,
  "organizationName": null,
  "permissionOverrides": {},
  "isActive": true,
  "claimsVersion": 0
}
```

### 4. Sign in

```powershell
cd apps/superadmin
flutter run -d chrome
```

Use that email/password (or Google with the same account).

---

## CLI seed (optional)

Requires [Application Default Credentials](https://cloud.google.com/docs/authentication/application-default-credentials) (`gcloud auth application-default login`).

```powershell
# Seed all admin_roles only
node scripts/seed-admin-roles.cjs

# Seed roles + create/link Super Admin Auth user
node scripts/seed-admin-roles.cjs --email you@example.com --password "YourSecurePass!" --name "Platform Owner"
```

---

## Org Admin note

Same Auth project. `admin_users` doc with `roleId: "admin"` and a non-empty `organizationId`, then use the Org Admin app (`apps/admin`).

## Custom claims (later)

Cloud Function can set `adminRoleId` / `organizationId` on the ID token. Client already refreshes tokens after login.
