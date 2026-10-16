#!/bin/bash
# Usage: tool/run_cases.sh <out_dir> [ENV=value ...]
# Makes a fresh project in <out_dir>/proj, starts the built spike app on it with
# the given environment, runs every edit case, then quits the app.
# Leaves <out_dir>/app.log, edits.log and shots/. Build the app first.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HERE/../studio/build/macos/Build/Products/Debug/disk_render_studio.app/Contents/MacOS/disk_render_studio"
OUT="$1"; shift
rm -rf "$OUT"; mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
python3 "$HERE/make_assets.py" "$OUT/proj" >/dev/null
env FLAME_SPIKE_PROJECT="$OUT/proj" FLAME_SPIKE_SHOTS="$OUT/shots" "$@" "$APP" >"$OUT/app.log" 2>&1 &
PID=$!
sleep 5
python3 "$HERE/edit_cases.py" "$OUT/proj" >"$OUT/edits.log"
sleep 2
kill "$PID"
echo "done: $OUT"
