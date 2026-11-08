#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
app="${repo_root}/showcase/flutter_demo"
out="${repo_root}/.native_capture/android"
rm -rf "$out"
mkdir -p "$out"

bash "${repo_root}/tool/ci/prepare_universal_automation_sibling.sh"
(cd "${repo_root}/mcp_server_dart" && flutter pub get)
(cd "$app" && flutter pub get)
[[ -d "$app/android" ]] || (cd "$app" && flutter create --platforms=android .)

log="${out}/flutter_run.log"
(
  cd "$app"
  flutter run -d emulator --debug \
    --host-vmservice-port=9192 \
    --disable-service-auth-codes \
    2>&1 | tee "$log"
) &
fpid=$!
cleanup() { kill "$fpid" 2>/dev/null || true; }
trap cleanup EXIT

ws=""
for _ in $(seq 1 180); do
  ws="$(grep -Eo 'ws://127\.0\.0\.1:[0-9]+/[A-Za-z0-9_=-]+/ws' "$log" | tail -1 || true)"
  [[ -n "$ws" ]] && break
  sleep 2
done
[[ -n "$ws" ]] || { echo "No VM service URI"; tail -60 "$log"; exit 1; }

adb logcat -d | grep -iE 'impeller|vulkan|skia|GrBackend' >"${out}/renderer.log" || true

bash "${here}/flutter_layer_capture_matrix.sh" \
  --device emulator \
  --vm-ws "$ws" \
  --out "$out" \
  --project-dir "$app"

echo "Android emulator flutter_layer capture OK -> $out"
