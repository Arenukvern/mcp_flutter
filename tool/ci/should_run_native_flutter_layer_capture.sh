#!/usr/bin/env bash
# Exit 0 = run native jobs; exit 1 = hold (Contract Gates / local unit still run).
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
pin_file="$repo_root/tool/ci/oka_consumer_pin.txt"
allow_file="$repo_root/tool/ci/oka_consumer_native_rerun_allowed.txt"
if [[ ! -f "$pin_file" ]]; then
  echo "missing pin file: $pin_file" >&2
  exit 1
fi
pin="$(tr -d '[:space:]' < "$pin_file")"
if [[ -z "$pin" ]]; then
  echo "empty oka consumer pin"
  exit 1
fi
if [[ ! -f "$allow_file" ]]; then
  echo "HOLD native_layer CI: no allow file ($allow_file)"
  exit 1
fi
mapfile -t allowed < <(grep -v '^[[:space:]]*#' "$allow_file" | grep -v '^[[:space:]]*$' | tr -d '[:space:]' || true)
if [[ "${#allowed[@]}" -eq 0 ]]; then
  echo "HOLD native_layer CI: allowlist empty (pin=$pin)"
  exit 1
fi
for line in "${allowed[@]}"; do
  if [[ "$line" == "$pin" ]]; then
    echo "RUN native_layer CI: pin $pin is allowlisted"
    exit 0
  fi
done
echo "HOLD native_layer CI: pin $pin not in $allow_file"
exit 1
