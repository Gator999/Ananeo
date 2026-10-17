#!/bin/bash
# Scaffolds a new feature from templates/feature: a Swift model, service, and list view,
# plus a Supabase migration and pgTAP test for its table. See templates/README.md.
#
# Usage: scripts/new-feature.sh FeatureName [table_name]
#   FeatureName  PascalCase, singular. For example SavedSearch.
#   table_name   Optional. Defaults to the snake_case plural, for example saved_searches.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  sed -n '5,7p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
fi

FEATURE="$1"
if ! [[ "$FEATURE" =~ ^[A-Z][A-Za-z0-9]*$ ]]; then
  echo "FeatureName must be PascalCase, like SavedSearch." >&2
  exit 1
fi

CAMEL="$(printf '%s' "${FEATURE:0:1}" | tr '[:upper:]' '[:lower:]')${FEATURE:1}"
TITLE="$(printf '%s' "$FEATURE" | sed 's/\([a-z0-9]\)\([A-Z]\)/\1 \2/g')"
SNAKE="$(printf '%s' "$FEATURE" | sed 's/\([a-z0-9]\)\([A-Z]\)/\1_\2/g' | tr '[:upper:]' '[:lower:]')"

if [ $# -eq 2 ]; then
  TABLE="$2"
else
  case "$SNAKE" in
    *s|*x|*ch|*sh) TABLE="${SNAKE}es" ;;
    *[!aeiou]y)    TABLE="${SNAKE%y}ies" ;;
    *)             TABLE="${SNAKE}s" ;;
  esac
fi
if ! [[ "$TABLE" =~ ^[a-z][a-z0-9_]*$ ]]; then
  echo "table_name must be lowercase snake_case, like saved_searches." >&2
  exit 1
fi

# Plural forms for the UI and the service property, taken from the table name.
TITLES="$(printf '%s' "$TABLE" | tr '_' ' ' | awk '{ for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) substr($i, 2) } 1')"
PLURAL="$(printf '%s' "$TABLE" | awk -F_ '{ out = $1; for (i = 2; i <= NF; i++) out = out toupper(substr($i, 1, 1)) substr($i, 2); print out }')"

# Migrations run in filename order, so the new one must sort after every existing one.
STAMP="$(date -u +%Y%m%d%H%M%S)"
LATEST="$(ls supabase/migrations 2>/dev/null | sed -n 's/^\([0-9]\{14\}\)_.*/\1/p' | sort | tail -n 1)"
if [ -n "$LATEST" ] && [ "$STAMP" -le "$LATEST" ]; then
  STAMP=$((LATEST + 1))
fi

T=templates/feature
FILES=(
  "$T/Models/__Feature__.swift.tmpl|Ananeo/Models/$FEATURE.swift"
  "$T/Services/__Feature__Service.swift.tmpl|Ananeo/Services/${FEATURE}Service.swift"
  "$T/Views/__Feature__ListView.swift.tmpl|Ananeo/Views/${FEATURE}ListView.swift"
  "$T/supabase/migration.sql.tmpl|supabase/migrations/${STAMP}_${TABLE}.sql"
  "$T/supabase/test.sql.tmpl|supabase/tests/database/${TABLE}_test.sql"
)

for pair in "${FILES[@]}"; do
  dest="${pair#*|}"
  if [ -e "$dest" ]; then
    echo "$dest already exists. Nothing was created." >&2
    exit 1
  fi
done

for pair in "${FILES[@]}"; do
  src="${pair%%|*}"
  dest="${pair#*|}"
  mkdir -p "$(dirname "$dest")"
  sed -e "s/__Feature__/$FEATURE/g" \
      -e "s/__feature__/$CAMEL/g" \
      -e "s/__Titles__/$TITLES/g" \
      -e "s/__Title__/$TITLE/g" \
      -e "s/__table__/$TABLE/g" \
      "$src" > "$dest"
  echo "created $dest"
done

cat <<EOF

Next steps (details in templates/README.md):

1. Wire the service into the app.
   Ananeo/AnaneoApp.swift:
       @State private var $PLURAL = ${FEATURE}Service()
       ...
       .environment($PLURAL)
   Add the same .environment(${FEATURE}Service()) to the ContentView and RootView previews.

2. Show the screen. For a new tab, in Ananeo/ContentView.swift add a case to AppTab and:
       Tab("$TITLES", systemImage: "tray", value: .$CAMEL) {
           ${FEATURE}ListView()
       }

3. Shape the data. Add columns to the migration, the model's CodingKeys, the
   New$FEATURE insert struct, and the grant insert (...) / update (...) lists together.

4. Test the database: supabase db reset && supabase test db
   Then build in Xcode, and run scripts/dev-simulator.sh to try it.

5. Ship it: supabase db push applies the migration to the hosted project.
EOF
