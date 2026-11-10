#!/usr/bin/env bash
# Writes pubspec_overrides.yaml — every oka/packages/* member at the pinned SHA.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
pin="$(tr -d '[:space:]' < "$repo_root/tool/ci/oka_consumer_pin.txt")"
oka="$repo_root/oka"
if [[ ! -d "$oka/packages/oka_android" ]]; then
  echo "missing $oka — run tool/ci/checkout_oka_consumer.sh first" >&2
  exit 1
fi

write_oka_overrides() {
  local target_dir="$1"
  local rel_prefix="$2"
  local add_interface_override="${3:-0}"
  local out="$target_dir/pubspec_overrides.yaml"
  {
    echo "# GENERATED: oka consumer test pin $pin (unmerged PR — not a release claim)"
    echo "dependency_overrides:"
    if [[ "$add_interface_override" == 1 ]]; then
      # Fixture is outside the workspace; mirror root 0.4.0 train for oka path graph.
      echo "  universal_automation_interface: 0.4.0"
    fi
    for pkg_dir in "$oka"/packages/*/; do
      [[ -f "$pkg_dir/pubspec.yaml" ]] || continue
      local name
      name="$(basename "$pkg_dir")"
      echo "  $name:"
      echo "    path: $rel_prefix/$name"
    done
  } >"$out"
}

write_oka_overrides "$repo_root/packages/harness" "../../oka/packages" 0
write_oka_overrides "$repo_root/showcase/native_layer_capture_fixture" "../../oka/packages" 1
echo "pubspec_overrides.yaml applied (full oka graph, pin $pin)"
