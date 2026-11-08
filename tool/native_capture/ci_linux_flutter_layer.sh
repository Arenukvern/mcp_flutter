#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
app="${repo_root}/showcase/flutter_demo"
out="${repo_root}/.native_capture/linux"
rm -rf "$out"
mkdir -p "$out"

export CC=gcc
export CXX=g++
export CMAKE_C_COMPILER=gcc
export CMAKE_CXX_COMPILER=g++

bash "${repo_root}/tool/ci/prepare_universal_automation_sibling.sh"
(cd "${repo_root}/mcp_server_dart" && flutter pub get)
(cd "$app" && flutter pub get)
[[ -d "$app/linux" ]] || (cd "$app" && flutter create --platforms=linux .)

# Headless Linux CI: use xvfb when DISPLAY is unset.
if [[ -z "${DISPLAY:-}" ]]; then
  sudo apt-get install -y xvfb g++ libstdc++-12-dev
  export DISPLAY=:99
  Xvfb :99 -screen 0 1280x720x24 &
  sleep 2
fi

log="${out}/flutter_run.log"
(
  cd "$app"
  flutter run -d linux --debug \
    --host-vmservice-port=9191 \
    --disable-service-auth-codes \
    --dart-define=FLUTTER_WEB_USE_SKIA=false \
    2>&1 | tee "$log"
) &
fpid=$!
cleanup() { kill "$fpid" 2>/dev/null || true; }
trap cleanup EXIT

ws=""
for _ in $(seq 1 120); do
  ws="$(grep -Eo 'ws://127\.0\.0\.1:[0-9]+/[A-Za-z0-9_=-]+/ws' "$log" | tail -1 || true)"
  [[ -n "$ws" ]] && break
  sleep 2
done
[[ -n "$ws" ]] || { echo "No VM service URI in $log"; tail -40 "$log"; exit 1; }

grep -iE 'impeller|skia' "$log" >"${out}/renderer.log" || true

bash "${here}/flutter_layer_capture_matrix.sh" \
  --device linux \
  --vm-ws "$ws" \
  --out "$out" \
  --project-dir "$app"

echo "Linux native flutter_layer capture OK -> $out"
