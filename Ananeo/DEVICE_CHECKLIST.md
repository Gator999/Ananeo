# UI redesign: device checks before launch

Phase 5 of the redesign is a pass on a real phone. Everything below needs Xcode or a device, so it was not
checked in the cloud container. Tick each row on an iOS 18 device or simulator, and again on iOS 26 with
Xcode 26 for the Liquid Glass look. Settings to toggle: Accessibility → Motion → Reduce Motion;
Accessibility → Display & Text Size → Reduce Transparency; Display & Text Size → Larger Text, up to the
largest accessibility size (the app caps the floating tab bar at XXXL; everything else should grow).

## Build

- [ ] `xcodebuild` succeeds with no errors. Warnings about `preparePhoto`'s default argument or Sendable
      closures are fine in Swift 5 mode and can be cleaned up later.
- [ ] `scripts/dev-simulator.sh` runs against the local stack after `supabase db reset` (which loads
      `supabase/seed.sql`). Set the simulator's location to Brooklyn (40.6782, -73.9442) to see seeded places.
- [ ] `supabase db push` applied the three new migrations: `public_profile`, `community_impact` for anon,
      `nearby_places`.

## Every screen, light and dark

| Screen | Look right | Reduce Motion | Reduce Transparency | XXL type |
|---|---|---|---|---|
| Welcome: mesh drifts, loop draws, tagline fades word by word, community pill | [ ] | [ ] still, all at once | [ ] | [ ] |
| Browse: title, chips, community strip, grid, card zoom into listing | [ ] | [ ] no zoom | [ ] chips opaque | [ ] |
| Listing: hero, toolbar turns solid on scroll, giver card, map, Ask pill → Requested | [ ] | [ ] | [ ] | [ ] |
| Give: three steps, photo strip, category grid, condition pill, mode cards, post toast | [ ] | [ ] | [ ] | [ ] |
| Pickups: segments, cards, tracker pulse, Your move glow | [ ] | [ ] no pulse | [ ] | [ ] |
| Pickup detail: cards, dialogs, celebration on completion | [ ] | [ ] no particles | [ ] | [ ] |
| Chat: header tracker, bubbles, confirm card, composer above keyboard, celebration | [ ] | [ ] | [ ] | [ ] |
| Places: map pins, filter chips, sheet drag, pin ↔ card selection, directions | [ ] | [ ] | [ ] | [ ] |
| Impact: ring fills, counters roll, share sheet gets the 1080×1920 card | [ ] | [ ] | [ ] | [ ] |
| Floating tab bar: hides on listing, pickup detail, and chat; returns on pop; badge count | [ ] | [ ] | [ ] | [ ] |

## Known risks to look at first

- The floating tab bar replaces the system tab bar. Check the bar hides and shows cleanly with the zoom
  transition on Browse, and that nothing important sits under it on any tab.
- Chat stacks a top inset, a bottom inset with the Confirm card, and the keyboard. Check nothing is clipped
  on a small phone.
- The Welcome mesh runs at 30 frames per second. Check an older phone stays smooth and that Low Power Mode
  pauses it.
- On Xcode 26, `GlassBackground` switches to `glassEffect`. Check chips, the tab bar, and the composer look
  right, and that Reduce Transparency still gives a solid surface.
- Dynamic Type at accessibility sizes: chips and pills grow in height now; check the stage tracker labels
  and the floating tab bar labels still read.

## Launch items (from PLAN.md, not UI)

- [ ] App Store screenshots in the new look.
- [ ] Choose the launch city and seed real `places` rows on the hosted project.
- [ ] Decide on the app icon: the new two-tone loop on the gradient is in the asset catalog.
