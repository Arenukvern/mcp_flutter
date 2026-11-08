#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
pin="$(tr -d '[:space:]' < "$repo_root/tool/ci/oka_consumer_pin.txt")"
oka="$repo_root/oka"
out="${1:-$repo_root/.native_capture/oka_consumer_provenance.json}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

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

(cd "$repo_root/packages/harness" && dart pub deps --style=compact >"$tmp/harness_deps.txt" 2>&1) || true
(cd "$repo_root/showcase/native_layer_capture_fixture" && dart pub deps --style=compact >"$tmp/fixture_deps.txt" 2>&1) || true

export REPORT_PIN="$pin"
export REPORT_HEAD="$resolved"
export REPORT_CLI="$oka_cli"
export REPORT_VER="$oka_version"
export REPORT_OUT="$out"
export REPORT_HARNESS="$tmp/harness_deps.txt"
export REPORT_FIXTURE="$tmp/fixture_deps.txt"

python3 - <<'PY'
import json, os
with open(os.environ["REPORT_HARNESS"], encoding="utf-8", errors="replace") as f:
    harness_deps = f.read()[:12000]
with open(os.environ["REPORT_FIXTURE"], encoding="utf-8", errors="replace") as f:
    fixture_deps = f.read()[:12000]
pin = os.environ["REPORT_PIN"]
head = os.environ["REPORT_HEAD"]
data = {
    "pinFile": pin,
    "okaCheckoutHead": head,
    "pinMatchesHead": head == pin or head.startswith(pin) or pin.startswith(head[: len(pin)]),
    "okaCliPath": os.environ["REPORT_CLI"],
    "okaCliVersionStdout": os.environ["REPORT_VER"].strip(),
    "cliActivation": "dart pub global activate --source path oka/packages/oka",
    "harnessPubDepsCompact": harness_deps,
    "fixturePubDepsCompact": fixture_deps,
    "note": "Unmerged oka PR #18 test pin; not a hosted release claim.",
}
os.makedirs(os.path.dirname(os.environ["REPORT_OUT"]) or ".", exist_ok=True)
with open(os.environ["REPORT_OUT"], "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
print("wrote", os.environ["REPORT_OUT"])
PY
