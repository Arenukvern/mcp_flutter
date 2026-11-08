#!/usr/bin/env bash
# Records resolved oka SDK provenance for native capture CI artifacts.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
pin="$(tr -d '[:space:]' < "$repo_root/tool/ci/oka_consumer_pin.txt")"
oka="$repo_root/oka"
out="${1:-$repo_root/.native_capture/oka_consumer_provenance.json}"

if [[ ! -d "$oka/.git" ]]; then
  echo '{"error":"oka checkout missing"}' >"$out"
  exit 1
fi

resolved="$(git -C "$oka" rev-parse HEAD)"
oka_cli="$(command -v oka || true)"
oka_version=""
if [[ -n "$oka_cli" ]]; then
  oka_version="$(oka --version 2>&1 || true)"
fi

harness_deps="$(cd "$repo_root/packages/harness" && dart pub deps --style=compact 2>&1 | head -c 12000)"
fixture_deps="$(cd "$repo_root/showcase/native_layer_capture_fixture" && dart pub deps --style=compact 2>&1 | head -c 12000)"

python3 - <<PY
import json, os
data = {
    "pinFile": "$pin",
    "okaCheckoutHead": "$resolved",
    "pinMatchesHead": "$resolved".startswith("$pin") or "$pin".startswith("$resolved"[:len("$pin")]),
    "okaCliPath": "$oka_cli",
    "okaCliVersionStdout": """$oka_version""".strip(),
    "cliActivation": "dart pub global activate --source path oka/packages/oka",
    "harnessPubDepsCompact": """$harness_deps""",
    "fixturePubDepsCompact": """$fixture_deps""",
    "note": "Unmerged oka PR #18 test pin; not a hosted release claim.",
}
os.makedirs(os.path.dirname("$out") or ".", exist_ok=True)
with open("$out", "w") as f:
    json.dump(data, f, indent=2)
print("wrote $out")
PY
