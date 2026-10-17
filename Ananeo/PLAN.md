# Ananeo Build Plan

**Give More. Waste Less. Keep It Moving.**

Ananeo keeps useful products and materials in circulation by connecting people who have things they no longer need with people who can use them. It is not a resale marketplace. There are no prices, no checkout, and no seller ratings tied to money. Success is measured in items and kilograms kept out of landfill.

*Ananeo* is from the Greek ανανέωση, "renewal."

---

## 1. Name check (status as of 2026-10-16)

| Check | Result | Status |
|---|---|---|
| Apple App Store | No published app titled Ananeo. App record created in App Store Connect with bundle ID `com.cameronnutter.ananeo`, which reserves the name. | Done |
| Google Play | No app titled Ananeo in US search. Only fuzzy matches such as "Ana" and "Anan". | Clear |
| ananeo.com | Registered since 2012 by someone else. | Taken |
| ananeo.org | Registered since 2021 by someone else. | Taken |
| ananeo.app | Registered on Cloudflare, 2026-10-17. | **Done** |
| ananeo.co, ananeo.io | Not registered. | Available |
| getananeo.com, ananeoapp.com | Not registered. | Available |
| US trademark (USPTO) | Not yet checked. | **To do** |

**Actions before launch**

1. ~~Register **ananeo.app** now.~~ Done. Also grab **getananeo.com** so a `.com` exists for email and marketing.
2. Search USPTO at tmsearch.uspto.gov for "Ananeo" and close spellings in Class 9 (software) and Class 42 (online platforms). If nothing conflicts, consider filing an intent-to-use application. A trademark attorney review is worth the cost before any paid marketing.
3. Reserve the Google Play package name `com.cameronnutter.ananeo` by creating the app in Play Console once the Android build starts.
4. Claim social handles (@ananeo or @ananeoapp) on Instagram, TikTok, and X.

App Store Connect reserves a name for 180 days without a build upload. Upload a TestFlight build before that window closes.

---

## 2. Positioning

Typical marketplaces optimize for transactions. Ananeo optimizes for **reuse**. Each feature should answer one question: does this help an item find its next use?

| Marketplace instinct | Ananeo approach |
|---|---|
| Price and sell | Give or swap only |
| Seller reputation | Giver and receiver "kept moving" counts |
| Maximize listings | Maximize completed handoffs |
| Ship anywhere | Hyperlocal pickup |
| Broken item is worthless | Broken item routes to repair or materials |

**Primary audiences**

- **Movers and declutterers** who want things gone fast and responsibly.
- **Students and new renters** who need furniture and household basics cheaply.
- **Makers and fixers** who want materials, parts, and repair projects.
- **Organizations** such as colleges, apartment communities, and cities that want measurable diversion numbers.

---

## 3. Feature set

Six pillars, each with a minimum version for launch and a later expansion.

### 3.1 Give

Post an item in under 60 seconds.

- **MVP:** Photos (up to 5), title, category, condition, pickup area (approximate, never an exact address), and availability window. Item states are *available*, *reserved*, and *handed off*.
- **Later:** Bulk "moving out" listings, curb alerts for items left outside with a short expiry, and AI-suggested title and category from the photo.

### 3.2 Exchange

Swap one item for another without money.

- **MVP:** Mark a listing as "open to swap" and say what you'd like in return. A receiver can offer one of their own listings. Both sides confirm.
- **Later:** Multi-party swap suggestions, and a "wishlist" that alerts you when a matching item is posted nearby.

### 3.3 Donate

Find where things can go when no individual claims them.

- **MVP:** Map and list of donation centers, thrift stores, e-waste drop-offs, and textile bins. Filter by what each accepts. Seed the data manually for the launch city.
- **Later:** Hours, partner verification, and "this item has been listed 14 days, here's where to donate it" nudges.

### 3.4 Repair and repurpose

The piece most marketplaces lack.

- **MVP:** Condition option "needs repair," a dedicated Fix-it feed, and a directory of repair cafes and shops. Broken items can be listed for parts or materials.
- **Later:** Curated repair and upcycling guides per category, maker profiles, and repair events.

### 3.5 Impact

Make diversion visible.

- **MVP:** Personal totals for items given, items received, and estimated kilograms diverted. A community total on the home screen.
- **Later:** CO₂-equivalent estimates, shareable impact cards, and monthly recaps.

**Methodology:** Each category and size has a default weight estimate. Users may optionally override it with a weight band. Only count an item once it is confirmed handed off by both sides. Publish the method on the website so organizational partners can trust the numbers. Use EPA WARM factors for any CO₂ claims.

### 3.6 Community challenges

Turn reuse into a group effort.

- **MVP:** Challenges created by the team, such as "Move-out Week: 500 items kept moving." Users join, progress counts automatically from handoffs, and a shared progress bar updates live.
- **Later:** Organizations create their own challenges for a campus, building, or city, with a leaderboard per neighborhood or dorm and a partner dashboard.

---

## 4. Trust, safety, and App Store requirements

User-generated content apps get extra App Review scrutiny under guideline 1.2. These items are required, not optional.

- Report a listing, report a user, and block a user.
- A moderation queue with the ability to remove content and ban accounts.
- Terms of use with zero tolerance for objectionable content.
- In-app account deletion, required by guideline 5.1.1(v).
- If Google sign-in is offered, Sign in with Apple must be offered too.
- A prohibited-items list covering weapons, drugs, recalled products, car seats, and similar items.

**Privacy**

- Store only an approximate location for each listing, a point offset within roughly 500 meters. Exact addresses are shared only in chat, by choice.
- Request location "when in use" only.
- Fill in App Privacy nutrition labels accurately: location, photos, contact info, and user content.

**Safety guidance**

- In-app tips for meeting in public places, and an optional "safe exchange spots" layer on the map.

---

## 5. Architecture

### 5.1 Recommendation

| Layer | Choice | Why |
|---|---|---|
| iOS app | SwiftUI, iOS 18+ (current project) | Already built and archiving. Native maps and photos are strong. |
| Backend | **Supabase** | Postgres with PostGIS makes "items within 5 km" a single indexed query. Includes auth, image storage, and realtime chat. Generous free tier. |
| Auth | Sign in with Apple, email magic link | Low friction, meets App Store rules. |
| Images | Supabase Storage with on-device resize to 1600 px | Keeps storage and bandwidth cheap. |
| Push | APNs through a Supabase Edge Function | Messages, reservations, and challenge updates. |
| Maps | MapKit on iOS | Free and native. |
| Android, later | Kotlin with Jetpack Compose | Reuses the same backend. |
| Web | Vite + React SPA on Cloudflare Workers (`web/`) | The landing page and the full app in the browser, on the same backend. Public listing pages with link previews and the partner dashboard would need server rendering; revisit then. |

The original concept called for all three platforms. Launching iOS alone first is faster. The backend should be designed for all three from day one, so the API never depends on iOS-only behavior.

**Alternative considered:** a single cross-platform codebase in Flutter or React Native. It would mean discarding the current SwiftUI work, and the UI quality on iOS would drop. Revisit only if Android demand arrives early.

### 5.2 Data model

```
profiles        id, display_name, avatar_url, home_area (geography), created_at
items           id, owner_id, title, details, category, condition,
                mode (give | swap | parts), status (available | reserved | handed_off | removed),
                location (geography, fuzzed), est_kg, photos[], created_at
swap_offers     id, item_id, offered_item_id, from_user, status
conversations   id, item_id, giver_id, receiver_id
messages        id, conversation_id, sender_id, body, created_at
handoffs        id, item_id, giver_id, receiver_id, confirmed_by_giver, confirmed_by_receiver, completed_at
places          id, kind (donation | repair | ewaste | textile), name, address, location, accepts[], hours
challenges      id, title, goal_items, starts_at, ends_at, area (geography, nullable), org_id
challenge_members  challenge_id, user_id
reports         id, reporter_id, target_type, target_id, reason, status
blocks          blocker_id, blocked_id
```

Row Level Security on every table. Impact totals come from a view over completed `handoffs`, so they cannot be edited directly.

A conversation doubles as a pickup request. The receiver opens it from a listing, the giver reserves the item for one of the people who asked, and chat messages hang off the same row.

### 5.3 iOS code structure

Build on the current folders.

```
Ananeo/
  App/            AnaneoApp, root TabView, deep links
  Models/         Codable types matching the tables above
  Services/       SupabaseClient, AuthService, ItemService, ChatService, LocationService
  Features/
    Browse/       feed, filters, map view, item detail
    Give/         create and edit listing, photo picker
    Messages/     conversation list, chat thread
    Places/       donation and repair map
    Impact/       personal and community stats
    Challenges/   list, detail, progress
    Profile/      settings, my listings, account deletion
  Shared/         components, styles, formatters
```

The current `ItemStore` with sample data stays as a preview and test fixture. Views move from reading it directly to reading service-backed view models.

---

## 6. Roadmap

Week counts assume one developer part-time. Each phase ends with a TestFlight build.

### Phase 0 — Foundation (done)

- SwiftUI project, archive-ready signing, app icon.
- Four-tab prototype with sample data.
- App Store Connect record reserving the name.

### Phase 1 — Real data (weeks 1–3)

- [x] Supabase schema with PostGIS and Row Level Security, with pgTAP tests (`supabase test db`).
- [x] Sign in with Apple, profile creation, sign out, and account deletion.
- [x] Hosted Supabase project (us-west-1) with schema pushed, tests passing, and Apple sign-in verified on device.
- [x] Post a listing with up to 5 photos, resized to 1600 px with GPS metadata stripped. Browse a nearby feed sorted by distance, shown in miles.
- [x] Location permission flow. Listing locations are fuzzed by the database.
- [x] Impact tab reads real totals from confirmed handoffs.
- [x] `scripts/dev-simulator.sh` runs the app against the local stack with a test account, no Apple ID needed.
- Location permission flow and fuzzed listing location.
- **Exit test:** two TestFlight users in the same city see each other's listings.

### Phase 2 — Handoffs (weeks 4–6)

- [x] In-app chat per item, live over Realtime, with unread counts on the Pickups tab.
- Push notifications for new messages and reservations.
- [x] Request an item, reserve it for one requester, then both sides confirm the handoff. A Pickups tab tracks each item from request to handoff.
- Impact tab driven by real handoffs.
- [x] Report listings, messages, and people. Block people, which also ends any pickup in progress between you. A moderation queue for moderators, with remove and ban.
- [x] Terms of use, accepted after sign-in and before anything else, with zero tolerance for objectionable content, an 18+ minimum age, and a prohibited-items list linked from the Give form.
- Account deletion.
- **Exit test:** a full give-and-pickup loop completes, and impact updates for both users.

### Phase 3 — Beyond giving (weeks 7–9)

- Swap mode and swap offers.
- Places map seeded for the launch city, covering donation, repair, and e-waste.
- "Needs repair" condition and the Fix-it feed.
- **Exit test:** each of the six pillars has a working MVP.

### Phase 4 — Community and launch (weeks 10–12)

- Challenges with a live progress bar.
- Onboarding that explains the mission in three screens.
- App Store screenshots, privacy labels, and review notes describing moderation.
- [x] Landing page at ananeo.app with the impact methodology, and the app itself in the browser at ananeo.app/app (`web/`).
- **Launch:** one city or one campus. Density matters more than reach for a local app.

### Phase 5 — Growth (after launch)

- Partner dashboard on the web for colleges, apartment managers, and cities.
- Organization-run challenges.
- Android app.
- Wishlist alerts, curb alerts, and AI listing assist.

---

## 7. Launch strategy

A local reuse app is useless with empty shelves. Concentrate on one place.

- **Pick one launch zone.** A college campus during move-out is ideal: high supply, high demand, and a clear deadline.
- **Seed supply before launch.** Partner with one apartment complex or residence hall to post items in the first week.
- **Run the first challenge at launch**, so new users join something that is already moving.
- **Measure:** handoffs completed per week, the share of listings that end in a handoff within 7 days, median time to first reply, and kilograms diverted.

---

## 8. Risks

| Risk | Mitigation |
|---|---|
| Empty feed in a new area | Single launch zone, seeded supply, and the Places map so the app is useful even with few listings |
| No-shows on pickup | Reservations expire after 48 hours, with a reliability count on profiles |
| Unsafe meetups | Fuzzed location, safety tips, and suggested public exchange spots |
| Inflated impact numbers | Count only two-sided confirmed handoffs, and publish the method |
| App Review rejection for UGC | Ship reporting, blocking, moderation, and terms in Phase 2, before any public release |
| Name conflict | Finish the USPTO search before spending on branding |

---

## 9. Open decisions

1. **Launch city or campus.** This determines which places to seed and which partner to approach.
2. **Backend.** Supabase is recommended. Firebase is the alternative if you prefer Google tooling.
3. **Android timing.** At launch or after iOS proves the loop.
4. **Business model.** Free for individuals is assumed. Revenue candidates are paid partner dashboards and sponsored community challenges. Ads and transaction fees work against the mission.
