#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=fixture_lib.sh
source "$(dirname "$0")/fixture_lib.sh"
trap stop_fixture_chrome EXIT

echo "== attach debug app (headless Chrome fixture) =="
start_fixture_chrome
ws="$(fixture_ws_uri)"
echo "== flutter-mcp-toolkit doctor --target … --timeout-ms 15000 =="
out="$(mktemp)"
flutter-mcp-toolkit doctor --json --target "$ws" --timeout-ms 15000 >"$out"
python3 - "$out" <<'PY'
import json, sys
path = sys.argv[1]
d = json.load(open(path))
s = d["data"]["summary"]
print(f"ok={d['ok']}  pass={s['pass']}/{s['total']}  fail={s['fail']}  criticalFailures={s['criticalFailures']}")
for c in d["data"]["checks"]:
    if c.get("critical"):
        print(f"  {c['id']}: {c['status']}")
PY
if ! python3 -c "import json; d=json.load(open('$out')); exit(0 if d['ok'] and d['data']['summary']['criticalFailures']==0 else 1)"; then
  echo "doctor_demo: doctor did not pass critical checks" >&2
  cat "$out" >&2
  exit 1
fi
rm -f "$out"