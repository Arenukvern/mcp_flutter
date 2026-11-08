#!/usr/bin/env bash
# Native flutter_layer capture proof: toolkit CLI + optional flutter screenshot CLI.
# Requires a running `flutter run` and WS URI. Fails if platform fallback is used.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: flutter_layer_capture_matrix.sh --device <id> --vm-ws <ws-uri> --out <dir> [--project-dir <path>]

Runs:
  1) fmtk exec get_screenshots mode=flutter_layer compress true/false
  2) Optional: flutter screenshot --type skia (Flutter-rendered via VM) when VM URL known
  3) Optional: flutter screenshot (device default = OS screencap) for contrast only

Writes PNG artifacts, vm_trace.jsonl, and summary.json under --out.
EOF
}

device=""
vm_ws=""
out=""
project_dir=""
flutter_bin="${FLUTTER_BIN:-flutter}"
server_dir=""

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

decode_summary() {
  python3 - "$1" <<'PY'
import json, base64, struct, sys
path = sys.argv[1]
raw = open(path).read()
d = json.loads(raw)
ok = d.get("ok")
data = d.get("data") or {}
imgs = data.get("images") or []
meta = {k: data.get(k) for k in (
    "captureMode", "actualMode", "captureBackend", "captureImplementation",
    "requestedMode", "fallbackReason", "captureModeUpgraded",
)}
print(json.dumps({"ok": ok, "imageCount": len(imgs), "meta": meta}, indent=2))
if not ok:
    sys.exit(0)
if meta.get("captureMode") != "flutter_layer" and meta.get("actualMode") != "flutter_layer":
    print("FAIL: not flutter_layer backend", file=sys.stderr)
    sys.exit(3)
if meta.get("captureBackend") not in (None, "flutter_layer_vm_extension"):
    print("FAIL: unexpected captureBackend", file=sys.stderr)
    sys.exit(3)
if len(imgs) < 1:
    print("FAIL: empty images", file=sys.stderr)
    sys.exit(3)
b = base64.b64decode(imgs[0])
open(path.replace(".stdout", ".png"), "wb").write(b)
if b[:8] != b"\x89PNG\r\n\x1a\n":
    print("FAIL: not a PNG", file=sys.stderr)
    sys.exit(3)
w, h = struct.unpack(">II", b[16:24])
print(json.dumps({"pngBytes": len(b), "width": w, "height": h}))
PY
}

echo '{"event":"matrix_start","device":"'"$device"'","vmWs":"'"$vm_ws"'"}' >"${out}/vm_trace.jsonl"

run_cli get_screenshots '{"mode":"flutter_layer","compress":false}' exec_layer_compress_false
decode_summary "${out}/exec_layer_compress_false.stdout" | tee "${out}/exec_layer_compress_false.summary.json"

run_cli get_screenshots '{"mode":"flutter_layer","compress":true}' exec_layer_compress_true
decode_summary "${out}/exec_layer_compress_true.stdout" | tee "${out}/exec_layer_compress_true.summary.json"

# Contrast: flutter CLI device screencap vs skia (layer) when project dir supplied.
if [[ -n "$project_dir" ]]; then
  $flutter_bin screenshot -d "$device" -o "${out}/flutter_screenshot_device.png" \
    >"${out}/flutter_screenshot_device.log" 2>&1 || true
  http_ws="${vm_ws%/ws}"
  http_ws="${http_ws/ws:\/\//http:\/\/}"
  $flutter_bin screenshot --type skia --vm-service-url="$http_ws" \
    -o "${out}/flutter_screenshot_skia.png" \
    >"${out}/flutter_screenshot_skia.log" 2>&1 || true
fi

python3 - "${out}" <<'PY'
import json, pathlib, struct
root = pathlib.Path(__import__("sys").argv[1])
summary = {"steps": []}
for p in sorted(root.glob("exec_layer_*.summary.json")):
    summary["steps"].append(json.loads(p.read_text()))
fail = [s for s in summary["steps"] if not s.get("ok")]
summary["verdict"] = "pass" if not fail else "fail"
(root / "summary.json").write_text(json.dumps(summary, indent=2))
print(json.dumps(summary, indent=2))
raise SystemExit(1 if fail else 0)
PY
