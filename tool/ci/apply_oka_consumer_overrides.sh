#!/usr/bin/env bash
# Writes pubspec_overrides.yaml for pinned path deps (gitignored oka/ checkout).
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
pin="$(tr -d '[:space:]' < "$repo_root/tool/ci/oka_consumer_pin.txt")"
oka="$repo_root/oka"
if [[ ! -d "$oka/packages/oka_android" ]]; then
  echo "missing $oka — run tool/ci/checkout_oka_consumer.sh first" >&2
  exit 1
fi
write_harness_override() {
  cat >"$repo_root/packages/harness/pubspec_overrides.yaml" <<EOF
# GENERATED: oka consumer test pin $pin (unmerged PR — not a release claim)
dependency_overrides:
  oka_android:
    path: ../../oka/packages/oka_android
  oka_core:
    path: ../../oka/packages/oka_core
  oka_harness:
    path: ../../oka/packages/oka_harness
EOF
}
write_fixture_override() {
  cat >"$repo_root/showcase/native_layer_capture_fixture/pubspec_overrides.yaml" <<EOF
# GENERATED: oka consumer test pin $pin (unmerged PR — not a release claim)
dependency_overrides:
  oka_android:
    path: ../../oka/packages/oka_android
  oka_core:
    path: ../../oka/packages/oka_core
EOF
}
write_harness_override
write_fixture_override
echo "pubspec_overrides.yaml applied (pin $pin)"
