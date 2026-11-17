#!/usr/bin/env bash
# Upload release tarballs with --clobber so recovery reruns stay idempotent.
set -euo pipefail

TAG="${1:-}"
ASSET_DIR="${2:-}"

fail() { echo "publish_release_assets: $*" >&2; exit 1; }
ok() { echo "publish_release_assets: $*"; }

[[ -n "$TAG" && -d "$ASSET_DIR" ]] || fail "usage: publish_release_assets.sh <tag> <asset-dir>"

command -v gh >/dev/null 2>&1 || fail "gh CLI required"
[[ -n "${GITHUB_REPOSITORY:-}" ]] || fail "GITHUB_REPOSITORY required"

shopt -s nullglob
files=( "$ASSET_DIR"/*.tar.gz "$ASSET_DIR"/checksums.txt )
[[ ${#files[@]} -gt 0 ]] || fail "no release assets in $ASSET_DIR"

gh release upload "$TAG" \
  --repo "$GITHUB_REPOSITORY" \
  --clobber \
  "${files[@]}"

ok "uploaded ${#files[@]} asset(s) to $TAG"