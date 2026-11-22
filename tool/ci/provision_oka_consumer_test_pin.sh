#!/usr/bin/env bash
# Provisional test-only oka consumer pin (unmerged PR). Not production cutover.
#
# When tool/ci/oka_consumer_pin.txt is absent the script falls back to HOSTED
# oka (pub.dev, ^0.12.0 — matches the harness/fixture pubspec carets): it
# activates the oka CLI globally and lets the workspace resolve hosted, so
# workflows calling this step run unchanged with or without a provisional pin.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
pin_file="$repo_root/tool/ci/oka_consumer_pin.txt"
if [[ ! -f "$pin_file" ]]; then
  echo "no $pin_file — provisioning HOSTED oka (pub.dev)"
  command -v dart >/dev/null 2>&1 || { echo "dart not on PATH" >&2; exit 1; }
  dart pub global activate oka
  (cd "$repo_root" && flutter pub get)
  echo "OKA_BIN=$(command -v oka || true)"
  echo "oka consumer: hosted mode (no pin)"
  exit 0
fi
pin="$(tr -d '[:space:]' < "$pin_file")"
echo "oka consumer test pin (provisional): $pin"
bash "$repo_root/tool/ci/checkout_oka_consumer.sh"
bash "$repo_root/tool/ci/apply_oka_consumer_overrides.sh"
bash "$repo_root/tool/ci/activate_oka_consumer_cli.sh"
(cd "$repo_root" && flutter pub get)
echo "OKA_BIN=$(command -v oka || true)"
if ! grep -q 'path: "oka/packages/oka_core"' "$repo_root/pubspec.lock" 2>/dev/null; then
  echo "oka consumer: expected path-pinned oka_core in root pubspec.lock after workspace overrides" >&2
  exit 1
fi
echo "oka consumer pin resolved via workspace root pubspec_overrides.yaml (path oka/packages/*, pin $pin)"
dart pub deps --style=compact -C "$repo_root" 2>/dev/null | rg '\boka(_[a-z0-9_]+)?\b' | head -12 || true
