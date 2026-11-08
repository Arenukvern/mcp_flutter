#!/usr/bin/env bash
# Native flutter_layer capture proof: toolkit CLI + classified flutter screenshot CLI.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: flutter_layer_capture_matrix.sh --device <id> --vm-ws <ws-uri> --out <dir> [--project-dir <path>]
EOF
}

device=""
vm_ws=""
out=""
project_dir=""
flutter_bin="${FLUTTER_BIN:-flutter}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device) device="$2"; shift 2 ;;
    --vm-ws) vm_ws="$2"; shift 2 ;;
    --out) out="$2"; shift 2 ;;
    --project-dir) project_dir="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 64 ;;
  esac
done

[[ -n "$device" && -n "$vm_ws" && -n "$out" ]] || {
  usage >&2
  exit 64
}

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
server_dir="${repo_root}/mcp_server_dart"
decode="${here}/decode_screenshot_envelope.py"
mkdir -p "$out"

run_cli() {
  local name="$1"
  local args="$2"
  local tag="$3"
  (
    cd "$server_dir"
    dart run bin/flutter_mcp_toolkit.dart exec \
      --flutter-vm-service-uri "$vm_ws" \
      --flutter-device "$device" \
      --name "$name" \
      --args "$args"
  ) >"${out}/${tag}.stdout" 2>"${out}/${tag}.stderr"
}

echo '{"event":"matrix_start","device":"'"$device"'","vmWs":"'"$vm_ws"'"}' >"${out}/vm_trace.jsonl"

run_cli get_screenshots '{"mode":"flutter_layer","compress":false}' exec_layer_compress_false
python3 "$decode" "${out}/exec_layer_compress_false.stdout" --png "${out}/exec_layer_compress_false.png" \
  | tee "${out}/exec_layer_compress_false.summary.json"

run_cli get_screenshots '{"mode":"flutter_layer","compress":true}' exec_layer_compress_true
python3 "$decode" "${out}/exec_layer_compress_true.stdout" --png "${out}/exec_layer_compress_true.png" \
  | tee "${out}/exec_layer_compress_true.summary.json"

bash "${here}/selftest_decode.sh"

echo '{"event":"harness_proof_start"}' >>"${out}/vm_trace.jsonl"
(
  cd "${repo_root}/packages/harness"
  dart run tool/native_layer_proof.dart "$vm_ws" "${out}/harness_proof"
) >"${out}/native_layer_proof.stdout" 2>"${out}/native_layer_proof.stderr"

flutter_cli=()
if [[ -n "$project_dir" ]]; then
  http_ws="${vm_ws%/ws}"
  http_ws="${http_ws/ws:\/\//http:\/\/}"
  set +e
  $flutter_bin screenshot -d "$device" -o "${out}/flutter_screenshot_device.png" \
    >"${out}/flutter_screenshot_device.log" 2>&1
  dev_ec=$?
  $flutter_bin screenshot --type skia --vm-service-url="$http_ws" \
    -o "${out}/flutter_screenshot_skia.png" \
    >"${out}/flutter_screenshot_skia.log" 2>&1
  skia_ec=$?
  set -e
  python3 - "${out}" "${dev_ec}" "${skia_ec}" <<'PY'
import json, pathlib, sys
out, dev_ec, skia_ec = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
root = pathlib.Path(out)
def probe(name):
    p = root / name
    return p.is_file() and p.stat().st_size > 100
report = {
    "deviceScreencap": {
        "kind": "os_device_framebuffer",
        "exitCode": dev_ec,
        "artifactPresent": probe("flutter_screenshot_device.png"),
        "countsAsFlutterLayerProof": False,
    },
    "skiaVmScreenshot": {
        "kind": "flutter_skia_picture_via_vm",
        "exitCode": skia_ec,
        "artifactPresent": probe("flutter_screenshot_skia.png"),
        "countsAsFlutterLayerProof": skia_ec == 0 and probe("flutter_screenshot_skia.png"),
    },
}
(root / "flutter_screenshot_report.json").write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
PY
fi

python3 - "${out}" <<'PY'
import json, pathlib
root = pathlib.Path(__import__("sys").argv[1])
summary = {"steps": [], "verdict": "fail"}
for p in sorted(root.glob("exec_layer_*.summary.json")):
    summary["steps"].append(json.loads(p.read_text()))
hp = root / "harness_proof" / "harness_proof.json"
if hp.is_file():
    summary["harnessProof"] = json.loads(hp.read_text())
fs = root / "flutter_screenshot_report.json"
if fs.is_file():
    summary["flutterScreenshot"] = json.loads(fs.read_text())
fail = [s for s in summary["steps"] if not s.get("ok")]
if summary.get("harnessProof", {}).get("verdict") != "pass":
    fail.append({"harnessProof": summary.get("harnessProof")})
summary["verdict"] = "pass" if not fail else "fail"
(root / "summary.json").write_text(json.dumps(summary, indent=2))
print(json.dumps(summary, indent=2))
raise SystemExit(0 if summary["verdict"] == "pass" else 1)
PY
