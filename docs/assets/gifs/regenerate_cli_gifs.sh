#!/usr/bin/env bash
# Regenerate committed CLI/harness GIFs (vhs). Called locally and from CI.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
export PATH="${HOME}/.local/bin:${FLUTTER_ROOT:-${HOME}/flutter}/bin:${PATH:-}"
export DISPLAY="${DISPLAY:-:99}"

cd "$ROOT"
command -v vhs >/dev/null || { echo "vhs not installed" >&2; exit 1; }
command -v flutter-mcp-toolkit >/dev/null || { echo "flutter-mcp-toolkit not on PATH" >&2; exit 1; }

if command -v xdpyinfo >/dev/null 2>&1; then
  if ! xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
    echo "regenerate_cli_gifs: DISPLAY=$DISPLAY is not ready (start Xvfb for :99)" >&2
    exit 1
  fi
fi

if [[ -x tool/ci/checkout_intentcall.sh ]]; then
  bash tool/ci/checkout_intentcall.sh
  parent_intentcall="$(dirname "$ROOT")/intentcall"
  if [[ ! -e "$parent_intentcall" ]]; then
    ln -sfn "$ROOT/intentcall" "$parent_intentcall"
  fi
fi

pkill -f 'flutter run.*flutter_demo' 2>/dev/null || true

echo "regenerate_cli_gifs: prebuilding showcase/flutter_demo (web) for harness-flutter Hide…"
(
  cd showcase/flutter_demo
  flutter build web
)

vhs docs/assets/gifs/harness-flutter.tape
vhs docs/assets/gifs/harness-web.tape

pkill -f 'flutter run.*flutter_demo' 2>/dev/null || true
pkill -f 'chrome.*flutter_demo' 2>/dev/null || true
sleep 2

echo "regenerate_cli_gifs: warming chrome exec session (flutter_demo, port 8181)…"
exec_log="$(mktemp)"
(
  cd showcase/flutter_demo
  flutter run -d chrome --web-port=8794 --host-vmservice-port=8181 \
    --web-browser-flag=--headless=new --web-browser-flag=--disable-gpu
) >"$exec_log" 2>&1 &
exec_pid=$!
vm_ws=""
for _ in $(seq 1 90); do
  vm_ws="$(grep -m1 -oE 'ws://127\.0\.0\.1:8181/[^ ]+' "$exec_log" || true)"
  if [[ -n "$vm_ws" ]]; then
    break
  fi
  sleep 1
done
if [[ -z "$vm_ws" ]]; then
  echo "regenerate_cli_gifs: VM ws URI not found (see $exec_log)" >&2
  tail -20 "$exec_log" >&2 || true
  kill "$exec_pid" 2>/dev/null || true
  exit 1
fi
exec_tape="${ROOT}/docs/assets/gifs/cli-exec.run.tape"
sed "s|__VM_WS_URI__|${vm_ws}|g" docs/assets/gifs/cli-exec.tape >"$exec_tape"
vhs "$exec_tape"
kill "$exec_pid" 2>/dev/null || true
wait "$exec_pid" 2>/dev/null || true
rm -f "$exec_log" "$exec_tape"

frames_dir="${ROOT}/docs/assets/gifs/frames"
mkdir -p "$frames_dir"
warn_budget=2097152
hard_cap=5242880

for name in harness-flutter harness-web cli-exec; do
  gif="docs/assets/gifs/${name}.gif"
  ffprobe -v error -show_entries format=duration,size \
    -show_streams -select_streams v:0 \
    -of default=noprint_wrappers=1 "$gif" >"${frames_dir}/${name}.ffprobe.txt"
  ffmpeg -y -i "$gif" -vf "select=eq(n\,0)" -vframes 1 \
    "${frames_dir}/${name}-frame0.png" 2>/dev/null
  size="$(stat -c%s "$gif")"
  if [ "$size" -gt "$warn_budget" ]; then
    echo "regenerate_cli_gifs: warning — $gif is $size bytes (budget 2MB)" >&2
  fi
  if [ "$size" -gt "$hard_cap" ]; then
    echo "regenerate_cli_gifs: GIF over 5MB cap: $gif ($size bytes)" >&2
    exit 1
  fi
done

pkill -f 'flutter run.*flutter_demo' 2>/dev/null || true

echo "regenerate_cli_gifs: OK"