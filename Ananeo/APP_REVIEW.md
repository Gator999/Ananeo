# App Review

Apple rejected 1.0 (2) on 2026-10-31 under guideline 2.1(a): the reviewer could not get past
Sign in with Apple and asked for a demo account with pre-populated content. This is how the demo
account works and what to send back.

## What the app does for review

- The Welcome screen has a "Sign in with email" link under Sign in with Apple. It opens a
  password form (`EmailSignInView`). There is no sign-up form; accounts with passwords are made
  by hand.
- Demo accounts carry `app_metadata.demo_location`. The app pins itself to that point
  (Cupertino) instead of asking for the device's location, so Browse, Give, and Places show the
  seeded content wherever the reviewer is. Real accounts are untouched.
- The reviewer account is a moderator, so the Moderation screen (Impact tab > account menu) is
  reachable too.

## Set up the hosted project (once, and again to reset the demo)

The Email provider must be on: Supabase dashboard > Authentication > Sign In / Providers > Email >
"Enable Email provider", with "Confirm email" left on. Password sign-in answers "Email logins are
disabled" otherwise. The SQL in scripts/seed-review.py can also be run by hand in the SQL editor;
then `python3 scripts/seed-review.py --photos-only` uploads the photos and prints the update to run.

From this folder, with the CLI linked to the hosted project (`supabase link --project-ref fmkjghyzpyxaraxdbsgi`):

```bash
supabase db push --linked
```

That applies `20261022000000_public_profile.sql`, which was never pushed; the giver card on a
listing reads `public_profile` and gets an error without it.

```bash
python3 scripts/seed-review.py
```

That creates three email/password accounts, listings, requests, a reserved pickup, two finished
handoffs, chats, one open report, and five unverified places around Cupertino, then uploads a
placeholder photo per listing. It writes the passwords to `Config/ReviewAccount.md` (gitignored).
Re-running resets everything and makes new passwords.

## App Store Connect

1. Archive and upload build 1.0 (3) (Product > Archive, then Distribute App).
2. App Review Information > Sign-in required: user name `appreview@ananeo.app`, password from
   `Config/ReviewAccount.md`.
3. Notes field, suggested text:

> Tap "Sign in with email" under the Sign in with Apple button and use the demo account above.
> The demo account is pinned to Cupertino, so Browse, Places, and the Give flow show content
> without granting location access. What to try: Browse lists nearby items (tap one, then
> "Ask for it"); Pickups > Giving has a floor lamp with two requests to choose between; Pickups >
> Getting has a road bike reserved for you with a chat and a Confirm step; Pickups > Done and the
> Impact tab show finished handoffs; the Give button posts a new listing; Impact > account menu >
> Moderation shows the report queue (the demo account is a moderator). Signing in with Apple
> creates a regular account with the same features.

4. Reply to the rejection message, suggested text:

> Thank you for the review. We've added a demo account so every part of the app can be checked
> without Sign in with Apple. The user name and password are in App Review Information, and the
> account comes with listings, pickup requests, a reserved pickup with a chat, finished handoffs,
> and moderator access. Build 1.0 (3) adds the "Sign in with email" option on the Welcome screen
> that the demo account uses.

Then resubmit the new build for review.
