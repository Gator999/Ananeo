# Ananeo web

The site at **ananeo.app**: a public landing page with the impact methodology, and the Ananeo app in
the browser at `/app`. It talks to the same Supabase project as the iOS app, so listings, pickups,
chats, and impact totals are shared across both.

Vite, React, TypeScript, and `@supabase/supabase-js`. No UI framework; one stylesheet with design
tokens, light and dark from the system setting.

| Path | What |
|---|---|
| `/` | Landing page: how it works, the six pillars, live community total, impact methodology, safety. |
| `/app/browse` | Nearby listings, closest first. Filter by category and distance. |
| `/app/browse/:id` | A listing. Request pickup, or remove it if it's yours. |
| `/app/give` | Post an item with up to 5 photos, resized on device with location data stripped. |
| `/app/pickups` | Everything you're giving or getting. Reserve, confirm handoffs, chat. |
| `/app/donate` | Donation, repair, e-waste, and textile places near you. |
| `/app/impact` | Your totals and everyone's. Sign out and account deletion. |

## Run it locally

```sh
cd Ananeo
supabase start                      # local Postgres, auth, storage, realtime
cd web
npm install
cp .env.example .env                # already points at the local stack
npm run dev                         # http://127.0.0.1:3000
```

In development against the local stack, the sign-in page shows a **developer sign-in** with the
same throwaway account `scripts/dev-simulator.sh` uses. Open a second private window and sign in
with a different email to try both sides of a pickup. That form is compiled out of production builds.

`npm run check` typechecks, `npm run build` writes `dist/`.

## Sign-in on the web

- **Email.** The default. Supabase emails a magic link; opening it on the same device signs you in.
  If the project's *Magic Link* email template includes `{{ .Token }}`, the email also carries a
  6-digit code and the form accepts it, which is friendlier on phones. Add it under
  Supabase > Authentication > Email Templates.
- **Apple.** Set `VITE_APPLE_SIGN_IN=true` to show the button. Web sign-in needs an Apple
  *Services ID* (not the app's bundle ID) and its secret configured under
  Supabase > Authentication > Providers > Apple. Same Supabase user as the iOS app.

Supabase's built-in email sender is limited to a few messages per hour. Set up custom SMTP
(Supabase > Project Settings > Auth) before sharing the link widely.

## Deploy to Cloudflare (ananeo.app)

The site is static. `wrangler.jsonc` deploys it as a Worker with static assets and a few lines of
code that send `www.ananeo.app` to `ananeo.app`. Both hostnames are attached as custom domains on
deploy, which works because the zone is in the same Cloudflare account.

### One-time setup in Supabase

Under Authentication > URL Configuration:

- **Site URL:** `https://ananeo.app`
- **Redirect URLs:** add `https://ananeo.app/app/browse` (and `http://127.0.0.1:3000/app/browse` for local dev).

Then apply the new migration: `supabase db push` from `Ananeo/`. It lets the signed-out landing
page read the community total and adds `nearby_places` for the Donate tab.

### Option A: Deploy from your machine

```sh
cd Ananeo/web
npx wrangler login
VITE_SUPABASE_URL=https://YOUR-REF.supabase.co VITE_SUPABASE_KEY=sb_publishable_... npm run deploy
```

### Option B: Deploy on every push (Cloudflare Workers Builds)

In the Cloudflare dashboard: Workers & Pages > Create > Import a repository > `Gator999/Ananeo`.

| Setting | Value |
|---|---|
| Root directory | `Ananeo/web` |
| Build command | `npm run build` |
| Deploy command | `npx wrangler deploy` |
| Build variables | `VITE_SUPABASE_URL`, `VITE_SUPABASE_KEY` (and `VITE_APPLE_SIGN_IN` if used) |

Cloudflare builds the Worker from `wrangler.jsonc`, attaches `ananeo.app` and `www.ananeo.app`,
and redeploys on every push to `main`. Preview builds run for pull requests.

### Option C: GitHub Actions

`.github/workflows/web.yml` typechecks and builds on every push and pull request that touches
`Ananeo/web`. It also deploys from `main` when these repository secrets exist:
`CLOUDFLARE_API_TOKEN` (Workers Scripts: Edit, plus Zone: DNS Edit for the custom domains),
`CLOUDFLARE_ACCOUNT_ID`, `VITE_SUPABASE_URL`, and `VITE_SUPABASE_KEY`.

## Notes

- Listing locations come from the browser's Geolocation API and are fuzzed by the database before
  storage, exactly as on iOS. The last fix is remembered in `localStorage` so the feed opens without a prompt.
- Row Level Security decides what each signed-in user can read; the publishable key is not a secret.
- `public/_headers` sets security headers; `public/_redirects` keeps the SPA working if the site is
  ever served from Cloudflare Pages instead of Workers.
- There is no server-side rendering, so a shared listing link shows the generic page preview. Public
  listing pages with their own previews are on the roadmap in `PLAN.md`.
