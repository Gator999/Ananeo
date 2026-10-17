# Ananeo screenshots

Presentation images of each screen, 1179 × 2556 px (iPhone 6.1" at 3x). `00-overview.png` puts all nine on one slide. `accent-options.png` shows Browse and Pickups in four candidate tint colors.

These were rendered from the SwiftUI views' layout and sample data, not captured from the iOS Simulator, so item photos appear as the app's category placeholders. To capture real ones instead, run the app in the Simulator and grab the screen:

```sh
scripts/dev-simulator.sh "iPhone 17 Pro"
xcrun simctl io booted screenshot docs/screenshots/02-browse.png
```

| File | Screen |
|---|---|
| 01-sign-in | Sign in with Apple |
| 02-browse | Nearby feed with category and distance filters |
| 03-listing-detail | Listing with Request Pickup |
| 04-give | Give form |
| 05-pickups | Giving, Getting, and Done |
| 06-pickup-detail | Reservation and handoff confirmation |
| 07-chat | Chat with a requester |
| 08-donation-centers | Donation centers |
| 09-impact | Personal and community impact |
