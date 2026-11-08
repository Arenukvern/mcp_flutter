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
export LIBRARY_PATH="/usr/lib/gcc/x86_64-linux-gnu/12:/usr/lib/gcc/x86_64-linux-gnu/13:${LIBRARY_PATH:-}"
export LDFLAGS="-L/usr/lib/gcc/x86_64-linux-gnu/12 -L/usr/lib/gcc/x86_64-linux-gnu/13"

(cd "${repo_root}/mcp_server_dart" && flutter pub get)
(cd "$app" && flutter pub get)
[[ -d "$app/linux" ]] || (cd "$app" && flutter create --platforms=linux .)

if [[ -z "${DISPLAY:-}" ]]; then
  sudo apt-get install -y -qq xvfb g++ libstdc++-12-dev
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

grep -iE 'impeller|skia|opengl|vulkan' "$log" >"${out}/renderer.log" || true
python3 - "$log" "${out}/renderer.log" <<'PY'
import json, pathlib, sys
flog = pathlib.Path(sys.argv[1]).read_text(errors="replace").lower()
rlog = pathlib.Path(sys.argv[2]).read_text(errors="replace").lower() if pathlib.Path(sys.argv[2]).exists() else ""
blob = flog + rlog
observed = []
if "impeller" in blob:
    observed.append("impeller")
if "skia" in blob:
    observed.append("skia")
verdict = {
    "observedBackends": observed,
    "note": "Linux desktop debug is often Skia/OpenGL; not Android Impeller.",
}
pathlib.Path(sys.argv[2]).with_name("renderer_verdict.json").write_text(json.dumps(verdict, indent=2))
if not observed:
    raise SystemExit("Linux renderer gap: no impeller/skia signal in flutter log")
PY

bash "${here}/flutter_layer_capture_matrix.sh" \
  --device linux \
  --vm-ws "$ws" \
  --out "$out" \
  --project-dir "$app"

echo "Linux native flutter_layer capture OK -> $out"
