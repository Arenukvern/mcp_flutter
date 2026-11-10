#!/usr/bin/env bash
# Writes workspace-root pubspec_overrides.yaml for the pinned oka consumer graph.
# Workspace members (packages/*, showcase/native_layer_capture_fixture) must not
# carry their own pubspec_overrides — pub applies overrides from the repo root only.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
pin="$(tr -d '[:space:]' < "$repo_root/tool/ci/oka_consumer_pin.txt")"
oka="$repo_root/oka"
if [[ ! -d "$oka/packages/oka_android" ]]; then
  echo "missing $oka — run tool/ci/checkout_oka_consumer.sh first" >&2
  exit 1
fi

out="$repo_root/pubspec_overrides.yaml"
{
  echo "# GENERATED: oka consumer test pin $pin (unmerged PR — not a release claim)"
  echo "dependency_overrides:"
  echo "  universal_automation_interface: 0.4.0"
  for pkg_dir in "$oka"/packages/*/; do
    [[ -f "$pkg_dir/pubspec.yaml" ]] || continue
    name="$(basename "$pkg_dir")"
    echo "  $name:"
    echo "    path: oka/packages/$name"
  done
} >"$out"

# Remove legacy per-package override files (workspace members reject these).
rm -f "$repo_root/packages/harness/pubspec_overrides.yaml"
rm -f "$repo_root/showcase/native_layer_capture_fixture/pubspec_overrides.yaml"

echo "pubspec_overrides.yaml applied at workspace root (full oka graph, pin $pin)"
