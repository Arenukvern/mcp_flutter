#!/usr/bin/env bash
# Real debug-app exec demo for cli-exec.tape: headless Chrome on Linux, then JSON RPCs.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../../" && pwd)"
export PATH="${FLUTTER_ROOT:-$HOME/flutter}/bin:${HOME}/.local/bin:${PATH:-}"
export DISPLAY="${DISPLAY:-:1}"
APP="${ROOT}/showcase/native_layer_capture_fixture"
LOG="$(mktemp)"
cleanup() {
  pkill -f "flutter run.*native_layer_capture_fixture" 2>/dev/null || true
  rm -f "$LOG"
}
trap cleanup EXIT

(
  cd "$APP"
  flutter run -d chrome --web-port=9877 \
    --web-browser-flag=--headless=new \
    --web-browser-flag=--disable-gpu
) >"$LOG" 2>&1 &
FPID=$!
URI=""
for _ in $(seq 1 120); do
  URI="$(grep -Eo 'http://127\.0\.0\.1:[0-9]+/[^ ]+' "$LOG" | head -1 || true)"
  if [[ -n "$URI" ]]; then
    break
  fi
  sleep 1
done
if [[ -z "$URI" ]]; then
  echo "exec_demo: no VM service URI in flutter log" >&2
  tail -20 "$LOG" >&2
  kill "$FPID" 2>/dev/null || true
  exit 1
fi
WS="ws://${URI#http://}/ws"
echo "# attached $URI"
flutter-mcp-toolkit exec --name get_extension_rpcs \
  --args "{\"connection\":{\"uri\":\"$WS\"}}" --pretty
kill "$FPID" 2>/dev/null || true
wait "$FPID" 2>/dev/null || true