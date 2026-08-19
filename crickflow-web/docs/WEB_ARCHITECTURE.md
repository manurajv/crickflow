# CrickFlow Web — Architecture

Independent consumer frontend for the existing CrickFlow Firebase ecosystem.
Does **not** modify the Flutter mobile app, Admin panel, Super Admin panel, root `firebase.json`, Cloud Functions, or Firestore rules.

**Domain:** `https://crickflow.web.app` (optional later: `www.crickflow.app`)  
**Firebase project (shared):** `crickflow-b06bc`  
**Stack:** Next.js App Router · TypeScript strict · Tailwind CSS · shadcn-style UI · Zustand · TanStack Query · Firestore

---

## 1. Recommended final architecture

```
Browser  →  Next.js (SSR / RSC for public SEO pages)
                 │
                 ├── Firebase Auth (client) for session
                 ├── Firestore (client) — public reads + authenticated writes
                 ├── Firebase Storage (client) — images
                 └── Existing Cloud Functions (unchanged; consume results)
```

| Layer | Role |
|-------|------|
| `app/` | Routes, metadata, layouts, RSC pages |
| `features/` | Feature UI + client hooks |
| `components/` | Shared layout + design system |
| `repositories/` | Typed Firestore access |
| `lib/` | Firebase, cricket formatting, SEO, location |
| `stores/` | Zustand (auth session, UI, location consent) |
| `types/` | Firestore-aligned models |
| `config/` | Site + collection constants |

**Rules**

- Server Components fetch public listings (one-shot `getDocs`).
- Client Components used only for auth, forms, search palette, chat, and **live** match listeners.
- Realtime `onSnapshot` only for genuinely live match documents, overlay, and recent commentary.
- No Firebase Admin SDK in this app. No service accounts in the browser.
- Scoring engine stays on mobile. Web is a **viewer** of match documents / `ball_events` / overlay.

---

## 2. Folder structure

```
crickflow-web/
  app/                    # Next.js App Router
  components/
    layout/
    ui/
    shared/
  features/{auth,home,matches,live-match,tournaments,teams,players,
            grounds,community,discover,chat,notifications,rankings,
            statistics,profiles,broadcasts,search,settings}/
  lib/
  repositories/
  hooks/
  stores/
  types/
  utils/
  config/
  public/
  docs/                   # Web-only tracking (not IMPLEMENTATION_STATUS.md)
  tests/
```

---

## 3. Firebase integration plan

| Service | How web uses it |
|---------|-----------------|
| Auth | Google + phone OTP (same as mobile). Email/password optional for web UX. |
| Firestore | Same collections as mobile. Client SDK respects security rules. |
| Storage | Read public image URLs already stored on docs. Upload only when signed in (community/discover media). |
| Functions | No new functions. Consume stats/badges written by `onMatchCompleted`, public scorecard from `syncPublicScorecard`. |
| Hosting | **New site** for www — never replace root `public/` scorecard hosting. |
| Analytics | Optional `NEXT_PUBLIC_GA_MEASUREMENT_ID` (existing GA4). |

Env vars: see `.env.example`. Client API keys are public by design; App Check is an ops follow-up (already pending on mobile).

---

## 4. Existing backend / data structures to reuse

| Collection | Web use | Public read |
|------------|---------|-------------|
| `users` | Profiles, settings | Signed-in self + public profile fields via `players` |
| `players` | Profiles, rankings, search | Yes |
| `teams` | Profiles, search | Yes |
| `matches` + `innings` embed | Match centre, live score | Yes |
| `matches/{id}/ball_events` | Commentary, wagon wheel, manhattan | Yes |
| `matches/{id}/overlay/current` | Live scorebug | Yes |
| `matches/{id}/public/scorecard` | SEO fallback / published card | Yes |
| `matches/{id}/highlights` | Highlights tab | Yes |
| `tournaments` + points table | Tournament centre | Yes |
| `community_posts` + likes/comments | Community | Yes (writes need auth) |
| `opportunity_posts` | Discover | Yes |
| `notifications` | Inbox | Owner only |
| `chats` + `messages` | Chat | Participants only |
| `chat_blocks` | Filter feed / chat | Owner |
| `playerFollows`, `teamFollowers`, `matchFollowers` | Follow | Auth writes |
| `badges` | Trophies | Yes |
| `fantasy_leagues` | Optional later | Yes |
| `home_promotions` | Home carousel | Yes |
| `grounds` | **Do not query from web** | Admin-only (see EXTERNAL_DEPENDENCY_ISSUES) |

Grounds on web are **derived** from match `venue`/`location` and tournament `grounds[]`.

---

## 5. Route map

| Route | Auth | Notes |
|-------|------|-------|
| `/` | Public | Homepage |
| `/login` `/register` | Public | Firebase Auth |
| `/home` | Public | Personalized when signed in |
| `/matches` | Public | Filters: live / upcoming / recent |
| `/matches/[matchId]` | Public | Match Centre |
| `/matches/[matchId]/live` | Public | Live score |
| `/matches/[matchId]/scorecard` | Public | |
| `/matches/[matchId]/commentary` | Public | |
| `/matches/[matchId]/stats` | Public | |
| `/matches/[matchId]/watch` | Public | Watch Live |
| `/tournaments` `/tournaments/[id]` | Public | |
| `/teams` `/teams/[id]` | Public | |
| `/players` `/players/[id]` | Public | |
| `/grounds` `/grounds/[id]` | Public | Derived venues |
| `/community` `/community/[postId]` | Public view / auth write | |
| `/discover` `/discover/[postId]` | Public view / auth write | |
| `/rankings` `/statistics` | Public | |
| `/search` | Public | Ctrl+K |
| `/notifications` `/chat` `/chat/[id]` | Auth | |
| `/profile` `/settings` | Auth | |
| `/legal/privacy` `/legal/terms` | Public | |

---

## 6. Feature parity matrix

Canonical table: [`../WEB_FEATURE_PARITY.md`](../WEB_FEATURE_PARITY.md).

---

## 7. Development phases

See [`../WEB_DEVELOPMENT_STATUS.md`](../WEB_DEVELOPMENT_STATUS.md). Phases 1–10 as specified in the product brief. Scoring/broadcast *creation* stays on mobile.

---

## 8. Potential conflicts with existing systems

| Conflict | Resolution |
|----------|------------|
| Root `firebase.json` rewrites `/teams/**`, `/tournaments/**`, `/match/**` to `open-app.html` | Deploy web as a **separate Hosting site / App Hosting backend**. Do not change root hosting. |
| `/live/**` public scorecard | Keep on current hosting. Web Match Centre lives at `/matches/[id]`. |
| App Links `https://crickflow.app` | Consumer web is `crickflow.web.app`; apex may still open the app. Document DNS in deployment. |
| Admin `grounds` collection | Not publicly readable — derive venues. |
| Shared Firebase web App ID | Ops may later register a dedicated “CrickFlow Web” app; no change to mobile/admin options files. |

---

## 9. Security considerations

- Never ship Admin SDK / service accounts.
- Never display `stream.streamKey` / `rtmpUrl` (mobile already omits from public projection).
- Authenticated writes only where rules allow (`authorId == uid`, chat participants, follow docs).
- Reports go to existing `community_post_reports` / `opportunity_post_reports`.
- CSP + secure headers in `next.config.ts`.
- Phone Auth needs authorized domain `crickflow.web.app` (Firebase Console — ops, not a code change to other apps).

---

## 10. Performance strategy

- RSC + one-shot queries for lists (limit 20–40).
- `onSnapshot` only when match `status` is `live` or `inningsBreak`.
- Image `next/image` + Firebase Storage URLs.
- Code-split Match Centre charts (Recharts).
- Pagination / infinite scroll for community, discover, notifications.
- TanStack Query stale times: listings 30s; profiles 2m; live disabled (realtime).
- `dynamic = 'force-dynamic'` only on live routes; public entity pages use ISR where possible (`revalidate: 60`).
