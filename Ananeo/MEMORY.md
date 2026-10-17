# Ananeo working notes

Notes for future work on this app. The product plan and roadmap live in PLAN.md.

## Backend (Supabase)

- The hosted project already has the migrations in `supabase/migrations` applied. Never edit an applied migration. Add a new one and run `supabase db push`.
- New functions are executable by everyone by default. Revoke from `public, anon, authenticated`, then grant to `authenticated` only.
- New tables are fully granted to `anon` and `authenticated` by Supabase's default privileges. Revoke them, then grant only what clients need.
- Row Level Security is on for every table. Writes that span rows go through `security definer` functions with `set search_path = ''`.
- A `conversations` row doubles as a pickup request. `reserve_item` only accepts someone who has one.
- Chat messages hang off the same `conversations` row, so withdrawing a request deletes its chat. Clients insert only `conversation_id` and `body`; the server stamps sender and time. Read state lives in `conversation_reads`, written only by `mark_conversation_read`, and `my_chats` gives the inbox (latest message and unread count per request).
- Blocking ends any pickup in progress between the two people (trigger on `blocks`). Completed handoffs stay.
- Reports are limited to things someone else posted that the reporter can see, one per person per thing.
- Moderators are added by hand: `insert into public.moderators (user_id) values ('<auth user id>');`. The Moderation screen appears in the account menu on the Impact tab only for them.
- A ban sets `profiles.banned_at` and `auth.users.banned_until`, and deletes the person's sessions. Their current access token keeps working until it expires, within an hour. To unban, clear both columns.
- The terms of use live in the app, in `Shared/TermsOfUse.swift`, with a version number. Bump `version` to make everyone accept again. Acceptance is recorded per version in `terms_acceptances` through `accept_terms`. `RootView` shows the terms until they're accepted, and `TermsService` remembers acceptance per user on the device.
- Owners can update an item only while it is `available` or `removed`. Reserved and handed-off items change only through `reserve_item`, `cancel_reservation`, `confirm_handoff`, and `withdraw_request`.

## iOS

- SwiftUI, iOS 18, Swift 5 language mode. The Xcode project uses synchronized folders, so new files under `Ananeo/` are picked up without editing the project file.
- `ChatService` keeps unread counts live through one realtime channel on `messages` while signed in; RLS decides which rows each user receives. `ChatView` opens its own channel filtered to one conversation.
- Services are `@MainActor @Observable` and expose a `revision` counter that views use to reload. `PickupService`, `ChatService`, and `SafetyService` cache the signed-in user's pickups, chat summaries, and blocks, and `RootView` clears all three when the account changes.
- `scripts/dev-simulator.sh` runs the app against the local stack with a test account.

## Web (`web/`)

- Vite + React + TypeScript, deployed to Cloudflare Workers with static assets (`wrangler.jsonc`). `npm run check` typechecks, `npm run build` writes `dist/`, `npm run deploy` publishes to ananeo.app. Build-time settings are `VITE_SUPABASE_URL`, `VITE_SUPABASE_KEY`, and `VITE_SIGN_IN_METHODS`.
- Same service shape as iOS: `AuthProvider`, `ListingsProvider`, `PickupsProvider`, and `ChatProvider` in `src/services`, with a `revision` counter that pages watch. `src/lib/types.ts` mirrors the Postgres enums; raw values must match.
- `VITE_SIGN_IN_METHODS` picks the sign-in buttons (`email`, `apple`, `google`). ananeo.app uses Apple and Google only; email magic link exists but is off there because the built-in sender is rate-limited. Apple on the web needs a Services ID and a client secret that expires every six months. In dev against the local stack the sign-in page also has a password form for throwaway accounts; it's compiled out of production builds.
- Photos are resized to 1600 px through a canvas, which also strips EXIF. Locations come from the browser Geolocation API and are fuzzed by the database like on iOS.
- The landing page reads `community_impact()` signed out, so that function is granted to `anon`. `nearby_places()` backs the Donate tab.

## Web (`web/`)

- Vite + React + TypeScript, deployed to Cloudflare Workers with static assets (`wrangler.jsonc`). `npm run check` typechecks, `npm run build` writes `dist/`, `npm run deploy` publishes to ananeo.app. Build-time settings are `VITE_SUPABASE_URL`, `VITE_SUPABASE_KEY`, and `VITE_SIGN_IN_METHODS`.
- Same service shape as iOS: `AuthProvider`, `ListingsProvider`, `PickupsProvider`, `ChatProvider`, and `TermsProvider` in `src/services`, with a `revision` counter that pages watch. `src/lib/types.ts` mirrors the Postgres enums; raw values must match.
- The terms text is duplicated in `src/lib/terms.ts`. Keep it and `Shared/TermsOfUse.swift` in step, and bump the version in both. `/terms` shows them publicly; the gate after sign-in uses `my_terms_version` and remembers acceptance per user in `localStorage`.
- `VITE_SIGN_IN_METHODS` picks the sign-in buttons (`email`, `apple`, `google`). ananeo.app uses Apple and Google only; email magic link exists but is off there because the built-in sender is rate-limited. Apple on the web needs a Services ID and a client secret that expires every six months. In dev against the local stack the sign-in page also has a password form for throwaway accounts; it's compiled out of production builds.
- Photos are resized to 1600 px through a canvas, which also strips EXIF. Locations come from the browser Geolocation API and are fuzzed by the database like on iOS.
- The landing page reads `community_impact()` signed out, so that function is granted to `anon`. `nearby_places()` backs the Donate tab.
- Blocks are enforced by RLS, so the web respects them without any UI of its own yet. Report and block screens are iOS-only so far.

## Testing in a cloud container

- There is no Xcode, so SwiftUI views can't be compiled there. Build in Xcode before merging.
- Database tests work. Start `dockerd`, install the CLI with `npm install supabase` (GitHub release downloads may be blocked, npm is not), then run `supabase start` and `supabase test db`. Docker Hub sometimes rate-limits image pulls, and retrying usually works.
- The tests assume an empty database. Run `supabase db reset` first if you've used the local stack for anything else.
- The full local stack runs too, so the web app can be driven end to end with Playwright against `supabase start`: use the developer sign-in form with two different emails for the two sides of a pickup.
- The non-UI code can be compiled and run on Linux in the `swift:6.1-noble` Docker image, which gives a real compile check. Build a small package with `Models/`, `Shared/`, and the services that don't import UIKit or AuthenticationServices, against supabase-swift at the revision in `Package.resolved`. Linux needs three adjustments: a stand-in `Backend`, an in-memory `AuthLocalStorage`, and the linker flag `-Xlinker --allow-shlib-undefined`.
- Linux Foundation can't open `ws://` sockets, so test Realtime with a Python `websockets` client that joins the same channel config instead.
