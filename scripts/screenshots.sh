#!/usr/bin/env bash
# Regenerates docs/screenshots/*.png from demo mode: sample tasks only, never your Reminders.
#
#   scripts/screenshots.sh
#
# Quits any running Latch first (two status items would fight over the menu bar) and leaves
# it quit. The terminal running this needs Screen Recording permission for `screencapture`.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=docs/screenshots
WORK="$(mktemp -d)"
trap 'pkill -x Latch 2>/dev/null || true; rm -rf "$WORK"' EXIT

scripts/build-app.sh debug >/dev/null
mkdir -p "$OUT"

stop_latch() {
  pkill -x Latch 2>/dev/null || true
  for _ in $(seq 1 40); do pgrep -x Latch >/dev/null || return 0; sleep 0.1; done
}

# launch <scene>: starts demo mode and waits for its report.
launch() {
  stop_latch
  REPORT="$WORK/$1.json"
  open -n build/Latch.app --args -LatchDemoScene "$1" -LatchDemoReport "$REPORT"
  for _ in $(seq 1 80); do [ -s "$REPORT" ] && break; sleep 0.25; done
  [ -s "$REPORT" ] || { echo "demo scene '$1' produced no report" >&2; exit 1; }
  sleep 0.4
  # A here-string, because plutil's output has no trailing newline for `read` to stop at.
  read -r X Y W H <<< "$(plutil -extract item json -o - "$REPORT" | tr -d '[]' | tr ',' ' ')"
}

window() { screencapture -x -l "$(plutil -extract "$1" raw -o - "$REPORT")" "$OUT/$2.png"; }
token() { screencapture -x -R "$((X - 8)),$((Y - 2)),$((W + 16)),$((H + 4))" "$OUT/$1.png"; }

launch menubar;  token token-idle
launch selector; window panelWindow selector
launch latched;  window panelWindow latched;  token token-latched
launch drifting; window panelWindow drifting; token token-drifting
launch gate;     window panelWindow gate
launch capture;  window captureWindow capture
launch menu;     sleep 0.6; screencapture -x -R "$((X - 6)),$((Y - 2)),330,300" "$OUT/menu.png"

echo "Wrote $(ls "$OUT"/*.png | wc -l | tr -d ' ') screenshots to $OUT"
