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

[[ -f "$ASSET_DIR/checksums.txt" ]] || fail "missing checksums.txt beside tarballs"

gh release upload "$TAG" \
  --repo "$GITHUB_REPOSITORY" \
  --clobber \
  "${files[@]}"

verify_dir="$(mktemp -d)"
cleanup() { rm -rf "$verify_dir"; }
trap cleanup EXIT

gh release download "$TAG" \
  --repo "$GITHUB_REPOSITORY" \
  --dir "$verify_dir" \
  --pattern '*.tar.gz' \
  --pattern 'checksums.txt'

(
  cd "$verify_dir"
  sha256sum -c checksums.txt
) || fail "post-upload checksum verification failed for $TAG"

for local_path in "${files[@]}"; do
  base="$(basename "$local_path")"
  remote_path="$verify_dir/$base"
  [[ -f "$remote_path" ]] || fail "missing downloaded asset $base"
  local_hash="$(sha256sum "$local_path" | awk '{print $1}')"
  remote_hash="$(sha256sum "$remote_path" | awk '{print $1}')"
  [[ "$local_hash" == "$remote_hash" ]] || fail "hash mismatch for $base after upload"
done

ok "uploaded and verified ${#files[@]} asset(s) on $TAG"