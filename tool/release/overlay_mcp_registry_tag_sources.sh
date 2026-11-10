#!/usr/bin/env bash
# Overlay immutable release *sources* onto the trusted main workspace for MCP Registry publish.
#
# Boundary:
#   From the tag (RELEASE_SRC): server sources, pubspec, lock, server.json
#   From main (TOOLING_ROOT):   Dockerfile.registry, Flutter pin, scripts, contracts
set -euo pipefail

fail() { echo "overlay_mcp_registry_tag_sources: $*" >&2; exit 1; }
ok() { echo "overlay_mcp_registry_tag_sources: $*"; }

TOOLING_ROOT="${TOOLING_ROOT:-}"
RELEASE_SRC="${RELEASE_SRC:-}"

[[ -n "$TOOLING_ROOT" && -n "$RELEASE_SRC" ]] || \
  fail "usage: TOOLING_ROOT=<main> RELEASE_SRC=<tag-tree> $0"

tag_server="$RELEASE_SRC/mcp_server_dart"
dest_server="$TOOLING_ROOT/mcp_server_dart"

[[ -d "$tag_server" ]] || fail "missing $tag_server"
[[ -d "$dest_server" ]] || fail "missing $dest_server"

# Server/runtime inputs from the tag only — never Dockerfile.registry or other build tooling.
OVERLAY_PATHS=(bin lib pubspec.yaml server.json)

for rel in "${OVERLAY_PATHS[@]}"; do
  src="$tag_server/$rel"
  [[ -e "$src" ]] || fail "tag tree missing $src"
  rm -rf "$dest_server/$rel"
  cp -a "$src" "$dest_server/$rel"
done

if [[ -f "$tag_server/pubspec.lock" ]]; then
  cp -a "$tag_server/pubspec.lock" "$dest_server/pubspec.lock"
fi

dockerfile="$dest_server/Dockerfile.registry"
[[ -f "$dockerfile" ]] || fail "main checkout missing $dockerfile"
if grep -q 'ghcr.io/cirruslabs/flutter' "$dockerfile"; then
  fail "Dockerfile.registry must come from main tooling, not the tag tree"
fi

ok "tag sources overlaid (${OVERLAY_PATHS[*]}) onto main tooling"
