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

## Testing in a cloud container

- There is no Swift or Xcode, so iOS code can't be compiled there. Build in Xcode before merging.
- Database tests work. Start `dockerd`, download the Supabase CLI release binary, then run `supabase db start` and `supabase test db`. Docker Hub sometimes rate-limits image pulls, and retrying usually works.
