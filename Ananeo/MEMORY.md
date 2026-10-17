# Ananeo working notes

Notes for future work on this app. The product plan and roadmap live in PLAN.md.

## Backend (Supabase)

- The hosted project already has the migrations in `supabase/migrations` applied. Never edit an applied migration. Add a new one and run `supabase db push`.
- New functions are executable by everyone by default. Revoke from `public, anon, authenticated`, then grant to `authenticated` only.
- Row Level Security is on for every table. Writes that span rows go through `security definer` functions with `set search_path = ''`.
- A `conversations` row is a pickup request and the chat about it. `reserve_item` only accepts someone who has one.
- Clients may insert only `(id, conversation_id, body)` into `messages` and `(id, item_id, giver_id)` into `conversations`. Everything else comes from defaults or functions, so nobody can backdate a message or set the other side's read marker.
- Owners can update an item only while it is `available` or `removed`. Reserved and handed-off items change only through `reserve_item`, `cancel_reservation`, `confirm_handoff`, and `withdraw_request`.

## iOS

- SwiftUI, iOS 18, Swift 5 language mode. The Xcode project uses synchronized folders, so new files under `Ananeo/` are picked up without editing the project file.
- Services are `@MainActor @Observable` and expose a `revision` counter that views use to reload. `PickupService` and `ChatService` also cache the signed-in user's pickups and chats, and `RootView` clears both when the account changes.
- `ChatService.listen()` holds the app's only Realtime channel. It covers message inserts plus handoff inserts and updates, and `ContentView` runs it for as long as someone is signed in. Don't subscribe to handoff deletes: Realtime sends delete events to every subscriber regardless of RLS.
- `scripts/dev-simulator.sh` runs the app against the local stack with a test account.

## Testing in a cloud container

- There is no Xcode, so SwiftUI views can't be compiled there. Build in Xcode before merging.
- Database tests work. Start `dockerd`, download the Supabase CLI release binary, then run `supabase db start` and `supabase test db`. Docker Hub sometimes rate-limits image pulls, and retrying usually works.
- The tests assume an empty database. Run `supabase db reset` first if you've used the local stack for anything else.
- The non-UI code can be compiled and run on Linux in the `swift:6.1-noble` Docker image, which gives a real compile check. Build a small package with `Models/`, `Shared/`, `PickupService` and `ChatService` against supabase-swift at the revision in `Package.resolved`. Linux needs three adjustments: a stand-in `Backend`, an in-memory `AuthLocalStorage`, and the linker flag `-Xlinker --allow-shlib-undefined`.
- Linux Foundation can't open `ws://` sockets, so test Realtime with a Python `websockets` client that joins the same channel config instead.
