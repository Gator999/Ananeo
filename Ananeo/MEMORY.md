# Ananeo working notes

Notes for future work on this app. The product plan and roadmap live in PLAN.md.

## Backend (Supabase)

- The hosted project already has the migrations in `supabase/migrations` applied. Never edit an applied migration. Add a new one and run `supabase db push`.
- New functions are executable by everyone by default. Revoke from `public, anon, authenticated`, then grant to `authenticated` only.
- Row Level Security is on for every table. Writes that span rows go through `security definer` functions with `set search_path = ''`.
- A `conversations` row doubles as a pickup request. `reserve_item` only accepts someone who has one.
- Chat messages hang off the same `conversations` row, so withdrawing a request deletes its chat. Clients insert only `conversation_id` and `body`; the server stamps sender and time. Read state lives in `conversation_reads`, written only by `mark_conversation_read`, and `my_chats` gives the inbox (latest message and unread count per request).
- Owners can update an item only while it is `available` or `removed`. Reserved and handed-off items change only through `reserve_item`, `cancel_reservation`, `confirm_handoff`, and `withdraw_request`.

## iOS

- SwiftUI, iOS 18, Swift 5 language mode. The Xcode project uses synchronized folders, so new files under `Ananeo/` are picked up without editing the project file.
- `ChatService` keeps unread counts live through one realtime channel on `messages` while signed in; RLS decides which rows each user receives. `ChatView` opens its own channel filtered to one conversation.
- Services are `@MainActor @Observable` and expose a `revision` counter that views use to reload. `PickupService` also caches the signed-in user's pickups, and `RootView` clears that cache when the account changes.
- `scripts/dev-simulator.sh` runs the app against the local stack with a test account.

## Web (`web/`)

- Vite + React + TypeScript, deployed to Cloudflare Workers with static assets (`wrangler.jsonc`). `npm run check` typechecks, `npm run build` writes `dist/`, `npm run deploy` publishes to ananeo.app. Build-time settings are `VITE_SUPABASE_URL`, `VITE_SUPABASE_KEY`, and optional `VITE_APPLE_SIGN_IN`.
- Same service shape as iOS: `AuthProvider`, `ListingsProvider`, `PickupsProvider`, and `ChatProvider` in `src/services`, with a `revision` counter that pages watch. `src/lib/types.ts` mirrors the Postgres enums; raw values must match.
- Sign-in is email magic link, plus a 6-digit code when the Supabase email template includes `{{ .Token }}`. Apple on the web needs a Services ID, so it's behind `VITE_APPLE_SIGN_IN`. In dev against the local stack the sign-in page also has a password form for throwaway accounts; it's compiled out of production builds.
- Photos are resized to 1600 px through a canvas, which also strips EXIF. Locations come from the browser Geolocation API and are fuzzed by the database like on iOS.
- The landing page reads `community_impact()` signed out, so that function is granted to `anon`. `nearby_places()` backs the Donate tab.

## Testing in a cloud container

- There is no Swift or Xcode, so iOS code can't be compiled there. Build in Xcode before merging.
- Database tests work. Start `dockerd`, install the CLI with `npm install supabase` (GitHub release downloads may be blocked, npm is not), then run `supabase start` and `supabase test db`. Docker Hub sometimes rate-limits image pulls, and retrying usually works.
- The full local stack runs too, so the web app can be driven end to end with Playwright against `supabase start`: use the developer sign-in form with two different emails for the two sides of a pickup.
