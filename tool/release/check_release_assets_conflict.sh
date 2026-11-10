#!/usr/bin/env bash
# Fail when a GitHub release already has expected binary asset names (no overwrite).
set -euo pipefail

fail() { echo "check_release_assets_conflict: $*" >&2; exit 1; }
ok() { echo "check_release_assets_conflict: $*"; }

TAG="${1:-}"
VERSION="${2:-}"
REPO="${GITHUB_REPOSITORY:-${3:-}}"

[[ -n "$TAG" && -n "$VERSION" && -n "$REPO" ]] || \
  fail "usage: GITHUB_REPOSITORY=owner/repo check_release_assets_conflict.sh <tag> <version>"

if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  fail "invalid tag format"
fi

command -v gh >/dev/null 2>&1 || fail "gh CLI required"

expected=(
  "flutter_mcp_${VERSION}_darwin-arm64.tar.gz"
  "flutter_mcp_${VERSION}_linux-x64.tar.gz"
  "checksums.txt"
)

json="$(gh release view "$TAG" --repo "$REPO" --json assets)"
if ! command -v jq >/dev/null 2>&1; then
  fail "jq required to parse gh release view output"
fi
if ! echo "$json" | jq -e '.assets | type == "array"' >/dev/null; then
  fail "invalid gh release view JSON for $TAG on $REPO"
fi

existing=()
while IFS= read -r name; do
  [[ -n "$name" ]] && existing+=("$name")
done < <(echo "$json" | jq -r '.assets[].name')

if [[ ${#existing[@]} -eq 0 ]]; then
  ok "no conflicting assets on $TAG ($REPO)"
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
  ok "no conflicting assets on $TAG ($REPO)"
  exit 0
fi

fail "release $TAG on $REPO already has: ${conflicts[*]}. Delete assets manually or use a new tag — workflow does not overwrite."
