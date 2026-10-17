# Feature templates

Starting points for adding a feature to Ananeo the way the existing ones are built:
a Swift model, an `@Observable` service, and a SwiftUI screen on the app side, and a
migration plus a pgTAP test on the Supabase side.

## Quick start

From the `Ananeo/` folder:

```sh
scripts/new-feature.sh SavedSearch            # table defaults to saved_searches
scripts/new-feature.sh Wishlist wishlist_items # or name the table yourself
```

That creates, with every placeholder filled in:

| File | What it is |
|---|---|
| `Ananeo/Models/SavedSearch.swift` | `Decodable` row struct with `CodingKeys`, a `Draft` for forms, and a preview value |
| `Ananeo/Services/SavedSearchService.swift` | `@MainActor @Observable` service: `refresh`, `create`, `rename`, `delete`, `reset`, `revision`, `preview` |
| `Ananeo/Views/SavedSearchListView.swift` | List screen with pull to refresh, add sheet, swipe to delete, empty state, and a `#Preview` |
| `supabase/migrations/<timestamp>_saved_searches.sql` | Table, owner trigger, RLS policies, and explicit grants |
| `supabase/tests/database/saved_searches_test.sql` | pgTAP checks for ownership, privacy, column grants, and signed-out access |

The Xcode project uses synchronized folders, so the new Swift files are compiled without
touching the project file. The script never overwrites an existing file, and it picks a
migration timestamp that sorts after every migration already in the folder.

## Finishing a feature

1. **Plan it.** Copy `FEATURE_SPEC.md` into the pull request description or an issue
   and fill it in. It is short on purpose.
2. **Shape the data.** The table starts with `id`, `owner_id`, `title`, and timestamps. When you
   add a column, change these together:
   - the `create table` in the migration
   - the `grant insert (...)` and `grant update (...)` column lists, if the app writes it
   - the model's properties and `CodingKeys`
   - the service's `New<Feature>` insert struct
3. **Decide who can see rows.** The policies start owner-only. If other people should see them,
   loosen `"<table> readable"` and hide rows across a block with `public.is_blocked`.
   Anything that touches more than one row or table (a reservation, a counter) goes in a
   `security definer` function with `set search_path = ''`, then
   `revoke execute ... from public, anon, authenticated` and `grant execute ... to authenticated`.
4. **Wire it in.** The script prints the exact lines. In short: hold the service in `AnaneoApp`
   with `@State` and pass it down with `.environment(...)`, add it to the `ContentView` and
   `RootView` previews, and add a `Tab` (or a `NavigationLink` from an existing screen). If the
   service caches the signed-in user's data, call its `reset()` when the account changes.
5. **Test.**
   - `supabase db reset && supabase test db` runs every pgTAP file. Add a check for each rule
     the feature adds and bump `plan(n)`.
   - Build in Xcode, then `scripts/dev-simulator.sh` runs the app against the local stack.
6. **Ship.** Open the pull request (the repository's PR template has the checklist), and after
   merging run `supabase db push` to apply the migration to the hosted project.

## Rules the templates already follow

- Never edit a migration that has been applied to the hosted project. Add a new one.
- Row Level Security is on for every table.
- New tables and functions get no access by default. Grant only what the app uses, column by
  column for writes, so the app cannot set `owner_id` or `created_at`.
- Services are `@MainActor @Observable`, take a `SupabaseClient` defaulting to `Backend.client`,
  and bump `revision` after writes so views reload with `.task(id: service.revision)`.
- Views catch `CancellationError` silently and show any other error inline in red.

## Changing the templates

The files in `feature/` end in `.tmpl` so nothing compiles or runs them directly.
`scripts/new-feature.sh` replaces these placeholders:

| Placeholder | Example |
|---|---|
| `__Feature__` | `SavedSearch` |
| `__feature__` | `savedSearch` |
| `__Title__` | `Saved Search` |
| `__Titles__` | `Saved Searches` |
| `__table__` | `saved_searches` |

To check a change to the SQL templates, generate a throwaway feature in a copy of the
folder and run `supabase db reset && supabase test db` there.
