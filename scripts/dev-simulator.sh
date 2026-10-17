#!/bin/zsh
# Runs Ananeo in the iOS Simulator against the LOCAL Supabase stack, signed in as a
# throwaway test account. No Apple ID needed. This account exists only in your local
# database and has nothing to do with the hosted project.
#
# Usage: scripts/dev-simulator.sh ["iPhone 17 Pro"]
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE="${1:-iPhone 17 Pro}"
API=http://127.0.0.1:54321
KEY=sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH
DEV_EMAIL=dev@ananeo.test
DEV_PASSWORD=local-dev-3ffdb31b88f264d6
DD=build/dev-simulator

# Create the test account if it doesn't exist yet. Local email signups are auto-confirmed.
curl -s -o /dev/null "$API/auth/v1/signup" -H "apikey: $KEY" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$DEV_EMAIL\",\"password\":\"$DEV_PASSWORD\",\"data\":{\"full_name\":\"Dev Tester\"}}" || true

# Build against the local stack, overriding any Config/Secrets.xcconfig.
xcodebuild -scheme Ananeo -destination "platform=iOS Simulator,name=$DEVICE" -derivedDataPath "$DD" \
  "SUPABASE_URL=http:/\$()/127.0.0.1:54321" "SUPABASE_KEY=$KEY" build -quiet

xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl install "$DEVICE" "$DD/Build/Products/Debug-iphonesimulator/Ananeo.app"
SIMCTL_CHILD_ANANEO_DEV_EMAIL="$DEV_EMAIL" SIMCTL_CHILD_ANANEO_DEV_PASSWORD="$DEV_PASSWORD" \
  xcrun simctl launch --terminate-running-process "$DEVICE" com.cameronnutter.ananeo
