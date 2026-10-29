#!/usr/bin/env bash
# Builds Latch with SwiftPM and wraps the binary in a proper .app bundle so that
# LSUIElement and the Reminders/Calendar usage descriptions (required by TCC) apply.
#
#   scripts/build-app.sh            # release build -> build/Latch.app
#   scripts/build-app.sh debug      # debug build
#   open build/Latch.app
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="${1:-release}"

swift build -c "$CONFIG" --product Latch
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

APP="build/Latch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Latch" "$APP/Contents/MacOS/Latch"
cp Support/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature so TCC can attribute the Reminders/Calendar grants to a stable identity.
codesign --force --sign - "$APP"

echo "Built $APP"
