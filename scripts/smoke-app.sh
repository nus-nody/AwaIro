#!/bin/bash
# App smoke test — boot simulator, install, launch, verify no crash.
# Used by `make test-app-smoke`. Exits 0 if app launches cleanly,
# 1 if launch fails or app crashes within the observation window.
#
# Why a shell script (not XCTest):
# Phase 1's App target has no test bundle (kept lean per plan). A
# launch-and-observe smoke test gives us "AppContainer + RootContentView
# don't crash on cold start" coverage without pbxproj surgery.

set -e

SIM_NAME="${SIM_NAME:-iPhone 16 (AwaIro)}"
BUNDLE_ID="${BUNDLE_ID:-io.awairo.AwaIro}"
OBSERVE_SECONDS="${OBSERVE_SECONDS:-3}"

echo "==> Booting simulator: $SIM_NAME"
xcrun simctl boot "$SIM_NAME" 2>/dev/null || true
sleep 2

# Verify simulator is actually booted (idempotent boot returns success either way)
BOOTED=$(xcrun simctl list devices booted | grep -F "$SIM_NAME" | head -1 || echo "")
if [ -z "$BOOTED" ]; then
  echo "❌ Simulator '$SIM_NAME' not booted. Available booted devices:" >&2
  xcrun simctl list devices booted >&2
  exit 1
fi
echo "   $BOOTED"

echo "==> Building App for simulator"
xcodebuild build \
  -project App/AwaIro.xcodeproj \
  -scheme AwaIro \
  -destination "platform=iOS Simulator,name=$SIM_NAME" \
  -derivedDataPath build/ \
  -quiet 2>&1 | tail -5

APP_PATH=$(find build/Build/Products -name "AwaIro.app" -type d | head -1)
if [ -z "$APP_PATH" ]; then
  echo "❌ Built .app bundle not found under build/Build/Products" >&2
  exit 1
fi
echo "   App: $APP_PATH"

echo "==> Installing on booted simulator"
xcrun simctl install booted "$APP_PATH"

echo "==> Launching $BUNDLE_ID"
LAUNCH_OUT=$(xcrun simctl launch booted "$BUNDLE_ID" 2>&1)
echo "   $LAUNCH_OUT"

# Extract PID from launch output (format: "<bundle-id>: <pid>")
PID=$(echo "$LAUNCH_OUT" | grep -oE '[0-9]+$' || echo "")
if [ -z "$PID" ]; then
  echo "❌ Could not parse PID from launch output" >&2
  exit 1
fi

echo "==> Observing for ${OBSERVE_SECONDS}s for crashes"
sleep "$OBSERVE_SECONDS"

# Check if process is still running. If gone, treat as crash unless we explicitly killed it.
STATE=$(xcrun simctl spawn booted launchctl list 2>&1 | grep "$BUNDLE_ID" | awk '{print $1}' | head -1 || echo "")
if [ -z "$STATE" ] || [ "$STATE" = "-" ]; then
  echo "❌ App appears to have crashed or exited within ${OBSERVE_SECONDS}s." >&2
  echo "   Recent log lines:" >&2
  xcrun simctl spawn booted log show --predicate 'process == "AwaIro"' --last "${OBSERVE_SECONDS}s" 2>&1 | tail -10 >&2
  exit 1
fi

echo "==> Terminating app (smoke test complete)"
xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true

echo "✅ App smoke test passed (launched, no crash within ${OBSERVE_SECONDS}s)"
