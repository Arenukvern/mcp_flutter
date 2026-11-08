#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
app="${repo_root}/showcase/flutter_demo"
out="${repo_root}/.native_capture/android"
rm -rf "$out"
mkdir -p "$out"

(cd "${repo_root}/mcp_server_dart" && flutter pub get)
(cd "$app" && flutter pub get)
[[ -d "$app/android" ]] || (cd "$app" && flutter create --platforms=android .)

log="${out}/flutter_run.log"
(
  cd "$app"
  flutter run -d emulator --debug \
    --enable-impeller \
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

bash "${here}/flutter_layer_capture_matrix.sh" \
  --device emulator \
  --vm-ws "$ws" \
  --out "$out" \
  --project-dir "$app"
matrix_ec=$?

adb logcat -d >"${out}/logcat_full.txt"
grep -iE 'impeller|Vulkan|GrBackend' "${out}/logcat_full.txt" "$log" >"${out}/renderer.log" || true

python3 - "${out}" "${log}" <<'PY'
import json, pathlib, sys
out = pathlib.Path(sys.argv[1])
flog = pathlib.Path(sys.argv[2]).read_text(errors="replace")
rlog = (out / "renderer.log").read_text(errors="replace") if (out / "renderer.log").exists() else ""
blob = (flog + rlog).lower()
verdict = {
    "impellerMentioned": "impeller" in blob,
    "vulkanMentioned": "vulkan" in blob,
    "skiaOnlyFallback": "skia" in blob and "impeller" not in blob,
}
(out / "renderer_verdict.json").write_text(json.dumps(verdict, indent=2))
if not verdict["impellerMentioned"]:
    raise SystemExit(
        "Android renderer gap: Impeller not observed in logcat/flutter output "
        "(see renderer.log). Toolkit flutter_layer matrix may still pass; "
        "this fails Impeller-specific acceptance for #156."
    )
PY
impeller_ec=$?

if [[ "$matrix_ec" -ne 0 || "$impeller_ec" -ne 0 ]]; then
  echo "Android capture finished matrix_ec=$matrix_ec impeller_ec=$impeller_ec"
  exit 1
fi
echo "Android emulator flutter_layer capture OK -> $out"
