# Firestore rules tests

Emulator tests for [`../firestore.rules`](../firestore.rules). They cover:

- public (signed-out) reads that crickflow-web and the mobile app rely on: series, clubs, rankings, matches, teams, players
- regular users: their own data only, and series draft create
- series owners and series admins: profile edits; status, `platformHold` and ownership are locked; approvals, registrations and audit reads
- the platform Super Admin: full access, plus the Orgs & Series moderation batch
- platform staff roles (moderator, tournamentAdmin, support, viewer), with `admin_roles` permission maps, built-in defaults and per-person overrides
- suspended or revoked staff, and the retired `admin` (organization) role, which are denied

```bash
cd firestore-tests
npm install
npm test        # needs Java 11+ for the emulator
```

When you change `firestore.rules`, add or extend a case here first. Then deploy with
`firebase deploy --only firestore:rules --project crickflow-b06bc`.
