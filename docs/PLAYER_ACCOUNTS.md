# Player accounts

## One login for everyone

- **Login** — single flow: Google or Phone only (no role picker).
- Every new account is a **Member** with full access: create matches, score, stream, join squads.
- **Viewer mode** is optional in Profile → App mode (browse-only).

## Squads

- **Add to squad** (team screen):
  - **Existing players** — search global directory.
  - **New player** — walk-in without an app account.
- **Team invite** — share link → **Join team** for any signed-in member (not in viewer mode).
- Each member gets a linked `players/{userId}` record for roster and stats.

## Legacy roles

Older accounts may still have `player` in Firestore. They are treated like members (can score and organize). Profile shows **Member (score & play)**.
