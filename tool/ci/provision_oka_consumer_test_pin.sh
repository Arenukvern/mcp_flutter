#!/usr/bin/env bash
# Provisional test-only oka consumer pin (unmerged PR). Not production cutover.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
pin_file="$repo_root/tool/ci/oka_consumer_pin.txt"
if [[ ! -f "$pin_file" ]]; then
  echo "missing $pin_file — cannot provision oka test pin" >&2
  exit 1
fi
pin="$(tr -d '[:space:]' < "$pin_file")"
echo "oka consumer test pin (provisional): $pin"
bash "$repo_root/tool/ci/checkout_oka_consumer.sh"
bash "$repo_root/tool/ci/apply_oka_consumer_overrides.sh"
bash "$repo_root/tool/ci/activate_oka_consumer_cli.sh"
(cd "$repo_root" && flutter pub get)
(cd "$repo_root/showcase/native_layer_capture_fixture" && flutter pub get)
echo "OKA_BIN=$(command -v oka || true)"
