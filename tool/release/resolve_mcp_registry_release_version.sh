#!/usr/bin/env bash
# Resolve MCP Registry publish version from the immutable tag checkout (not main VERSION).
set -euo pipefail

fail() { echo "resolve_mcp_registry_release_version: $*" >&2; exit 1; }
ok() { echo "resolve_mcp_registry_release_version: $*"; }

RELEASE_TAG="${RELEASE_TAG:-}"
RELEASE_SRC="${RELEASE_SRC:-}"

[[ -n "$RELEASE_TAG" && -n "$RELEASE_SRC" ]] || \
  fail "usage: RELEASE_SRC=<tag-tree> RELEASE_TAG=vX.Y.Z $0"

if [[ ! "$RELEASE_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  fail "invalid tag format: $RELEASE_TAG"
fi

tag_version="${RELEASE_TAG#v}"
version_file="$RELEASE_SRC/VERSION"
pubspec="$RELEASE_SRC/mcp_server_dart/pubspec.yaml"

[[ -f "$version_file" ]] || fail "missing $version_file"
src_version="$(tr -d '[:space:]' < "$version_file")"
[[ "$tag_version" == "$src_version" ]] || \
  fail "tag $RELEASE_TAG does not match release-src VERSION ($src_version)"

[[ -f "$pubspec" ]] || fail "missing $pubspec"
pubspec_version="$(grep -E '^version:' "$pubspec" | head -n1 | sed -E 's/^version:[[:space:]]*//')"
pubspec_version="${pubspec_version%%$'\r'}"
[[ -n "$pubspec_version" ]] || fail "mcp_server_dart pubspec missing version:"
[[ "$tag_version" == "$pubspec_version" ]] || \
  fail "tag $RELEASE_TAG does not match release-src mcp_server_dart version ($pubspec_version)"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "version=$tag_version" >> "$GITHUB_OUTPUT"
fi

ok "$RELEASE_TAG resolved to $tag_version from release-src"
echo "$tag_version"
