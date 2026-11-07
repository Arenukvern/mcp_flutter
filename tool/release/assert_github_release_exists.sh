#!/usr/bin/env bash
set -euo pipefail

fail() { echo "assert_github_release_exists: $*" >&2; exit 1; }
ok() { echo "assert_github_release_exists: $*"; }

TAG="${1:-}"
REPO="${GITHUB_REPOSITORY:-${2:-}}"

[[ -n "$TAG" && -n "$REPO" ]] || fail "usage: GITHUB_REPOSITORY=owner/repo assert_github_release_exists.sh <tag>"

command -v gh >/dev/null 2>&1 || fail "gh CLI required"

gh release view "$TAG" --repo "$REPO" --json tagName \
  | jq -e --arg t "$TAG" '.tagName == $t' >/dev/null

ok "GitHub release $TAG exists on $REPO"
