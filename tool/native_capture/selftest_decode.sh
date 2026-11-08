#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
decode="${here}/decode_screenshot_envelope.py"
fixtures="${here}/fixtures"
mkdir -p "$fixtures"

# 1x1 red PNG (known good).
GOOD_B64='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='

cat >"${fixtures}/good.json" <<EOF
{"ok":true,"data":{"images":["${GOOD_B64}"],"captureMode":"flutter_layer","captureBackend":"flutter_layer_vm_extension","captureImplementation":"app_layer_tree"}}
EOF

cat >"${fixtures}/bad_backend.json" <<EOF
{"ok":true,"data":{"images":["${GOOD_B64}"],"captureMode":"flutter_layer","captureBackend":"desktop_window","captureImplementation":"app_layer_tree"}}
EOF

cat >"${fixtures}/bad_ok_false.json" <<'EOF'
{"ok":false,"error":{"code":"get_screenshots_failed","message":"empty"}}
EOF

python3 "$decode" "${fixtures}/good.json" >/tmp/good.summary.json
python3 "$decode" "${fixtures}/bad_backend.json" >/dev/null 2>&1 && {
  echo "FAIL: bad_backend should exit nonzero"
  exit 1
}
python3 "$decode" "${fixtures}/bad_ok_false.json" >/tmp/bad.summary.json
grep -q '"ok": false' /tmp/bad.summary.json
echo "selftest_decode: pass"
