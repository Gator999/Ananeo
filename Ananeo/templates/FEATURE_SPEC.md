# Feature: <name>

## What it does
One or two sentences from the user's side. What can they do that they couldn't before?

## Who sees what
- Who can create it:
- Who can read it (owner only, the other person in a pickup, everyone nearby, signed out):
- Who can change or delete it:
- What happens across a block:

## Data
| Column | Type | Rules | App writes it? |
|---|---|---|---|
| title | text | 1 to 80 characters | yes |

Functions, if any write touches more than one row or table:

## Screens
- Where it lives (new tab, a section of an existing screen, a sheet):
- Empty state:
- Errors the user might hit:

## Out of scope for now

## Checks
- [ ] pgTAP: one check per rule in "Who sees what"
- [ ] Builds in Xcode and works in `scripts/dev-simulator.sh`
- [ ] Tried as two different accounts
