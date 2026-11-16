#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=fixture_lib.sh
source "$(dirname "$0")/fixture_lib.sh"
trap stop_fixture_chrome EXIT

uri="$(read_fixture_vm_uri || true)"
if [[ -z "${uri:-}" ]]; then
  echo "exec_demo_display: run warm_fixture.sh first" >&2
  exit 1
fi
ws="$(fixture_ws_uri)"
echo "== exec demo (fixture already attached) =="
echo "target: $uri"
echo "== flutter-mcp-toolkit exec --name get_extension_rpcs =="
json="$(mktemp)"
flutter-mcp-toolkit exec --name get_extension_rpcs \
  --args "{\"connection\":{\"uri\":\"$ws\"}}" >"$json"
if command -v jq >/dev/null 2>&1; then
  jq '{ok, data: (.data[:14]), error}' "$json"
else
  python3 - "$json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
preview = d.get("data", [])
if isinstance(preview, list):
    preview = preview[:14]
print(json.dumps({"ok": d.get("ok"), "data": preview, "error": d.get("error")}, indent=2))
PY
fi
rm -f "$json"