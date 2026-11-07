#!/usr/bin/env bash
# Fail when a GitHub release already has binary assets unless recovery_mode=true.
set -euo pipefail

fail() { echo "check_release_assets_conflict: $*" >&2; exit 1; }
ok() { echo "check_release_assets_conflict: $*"; }

TAG="${1:-}"
VERSION="${2:-}"
RECOVERY_MODE="${3:-false}"

[[ -n "$TAG" && -n "$VERSION" ]] || fail "usage: check_release_assets_conflict.sh <tag> <version> [recovery_mode]"

if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  fail "invalid tag format"
fi

command -v gh >/dev/null 2>&1 || fail "gh CLI required"

expected=(
  "flutter_mcp_${VERSION}_darwin-arm64.tar.gz"
  "flutter_mcp_${VERSION}_linux-x64.tar.gz"
  "checksums.txt"
)

mapfile -t existing < <(gh release view "$TAG" --json assets --jq '.assets[].name' 2>/dev/null || true)

if [[ ${#existing[@]} -eq 0 ]]; then
  ok "no existing assets on $TAG (safe to upload)"
  exit 0
fi

conflicts=()
for name in "${expected[@]}"; do
  for asset in "${existing[@]}"; do
    if [[ "$asset" == "$name" ]]; then
      conflicts+=("$name")
    fi
  done
done

if [[ ${#conflicts[@]} -eq 0 ]]; then
  ok "release has assets but none of the expected binary names (safe to upload)"
  exit 0
fi

if [[ "$RECOVERY_MODE" == "true" ]]; then
  ok "recovery_mode=true — uploading despite existing: ${conflicts[*]}"
  exit 0
fi

fail "release $TAG already has assets: ${conflicts[*]}. Re-run with recovery_mode=true to attach missing binaries (does not delete tags or republish packages)."
