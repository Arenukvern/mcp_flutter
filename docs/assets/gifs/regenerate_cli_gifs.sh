#!/usr/bin/env bash
# Regenerate committed CLI/harness GIFs (vhs). Called locally and from CI.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
export PATH="${HOME}/.local/bin:${FLUTTER_ROOT:-${HOME}/flutter}/bin:${PATH:-}"
export DISPLAY="${DISPLAY:-:99}"

cd "$ROOT"
command -v vhs >/dev/null || { echo "vhs not installed" >&2; exit 1; }
echo "regenerate_cli_gifs: compiling workspace flutter-mcp-toolkit…"
(
  cd mcp_server_dart
  make compile
)
export PATH="$ROOT/mcp_server_dart/build:${HOME}/.local/bin:${PATH}"
command -v flutter-mcp-toolkit >/dev/null || {
  echo "regenerate_cli_gifs: flutter-mcp-toolkit missing after compile" >&2
  exit 1
}

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
pkill -f 'flutter run.*flutter_test_app' 2>/dev/null || true

echo "regenerate_cli_gifs: prebuilding showcase/flutter_demo (web)…"
(
  cd showcase/flutter_demo
  flutter build web
)

echo "regenerate_cli_gifs: prebuilding showcase/flutter_test_app (web)…"
(
  cd showcase/flutter_test_app
  flutter build web
)

vhs docs/assets/gifs/harness-flutter.tape
vhs docs/assets/gifs/harness-web.tape
vhs docs/assets/gifs/cli-exec.tape

warn_budget=2097152
hard_cap=5242880

for name in harness-flutter harness-web cli-exec; do
  gif="docs/assets/gifs/${name}.gif"
  size="$(stat -c%s "$gif")"
  if [ "$size" -gt "$warn_budget" ]; then
    echo "regenerate_cli_gifs: warning — $gif is $size bytes (budget 2MB)" >&2
  fi
  if [ "$size" -gt "$hard_cap" ]; then
    echo "regenerate_cli_gifs: GIF over 5MB cap: $gif ($size bytes)" >&2
    exit 1
  fi
done

make showcase-stop >/dev/null 2>&1 || true

echo "regenerate_cli_gifs: OK"