Before:

After:

## How

## Checklist

**Database** (skip if `supabase/` is untouched)
- [ ] New migration only. No applied migration was edited.
- [ ] Row Level Security is on for every new table.
- [ ] New tables and functions start with no access, then get explicit grants.
- [ ] `supabase test db` passes, with a check for each new rule.

**iOS** (skip if no Swift changed)
- [ ] Builds in Xcode.
- [ ] Tried in the simulator with `scripts/dev-simulator.sh`.
- [ ] New services are passed in with `.environment(...)` in `AnaneoApp` and in previews.

**Web** (skip if `web/` is untouched)
- [ ] `npm run check` and `npm run build` pass.
- [ ] Tried in the browser against `supabase start`, as two different accounts where it matters.

**After merge**
- [ ] `supabase db push` to apply new migrations to the hosted project.
- [ ] ananeo.app redeploys from `main` (Cloudflare Workers Builds or the Web workflow).
