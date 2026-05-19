# Player accounts

## Current behavior

- **Onboarding** — first launch walkthrough → login.
- **Login** — choose **Player**, **Scorer/Organizer**, or **Viewer** before Google/Phone sign-in.
- **Add to squad** (organizer):
  - **Existing players** — search global directory, no duplicate profiles.
  - **New player** — walk-in without an app account.
- **Team invite** — share from team screen → `crickflow://teams/{id}` → **Join team** banner for recipients.
- **Player role** — creates `players/{userId}` linked to Firebase Auth uid.

## Planned enhancements

- Player self-service: batting style, availability, stats edit.
- Organizer approval flow for join requests.
- Push notification when added to a team.

Organizers: use **Existing players** for registered users; **New player** only for guests.
