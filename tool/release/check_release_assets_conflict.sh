#!/usr/bin/env bash
# Fail when a GitHub release already has expected binary asset names (no overwrite).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=release_assets_conflict_lib.sh
source "$ROOT_DIR/release_assets_conflict_lib.sh"

fail() { echo "check_release_assets_conflict: $*" >&2; exit 1; }
ok() { echo "check_release_assets_conflict: $*"; }

check_release_assets_conflict__main() {
  local TAG="${1:-}"
  local VERSION="${2:-}"
  local REPO="${GITHUB_REPOSITORY:-${3:-}}"

  [[ -n "$TAG" && -n "$VERSION" && -n "$REPO" ]] || \
    fail "usage: GITHUB_REPOSITORY=owner/repo check_release_assets_conflict.sh <tag> <version>"

  if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    fail "invalid tag format"
  fi

  if [[ "${RELEASE_CONFLICT_CONTRACT_NO_GH:-}" != 1 ]]; then
    command -v gh >/dev/null 2>&1 || fail "gh CLI required"
  fi

  command -v jq >/dev/null 2>&1 || fail "jq required"

  local json
  json="$(release_conflict__fetch_release_view_json "$TAG" "$REPO")" || \
    fail "gh release view failed for $TAG on $REPO"

  local conflict_class
  conflict_class="$(release_conflict__conflict_class_from_json "$json" "$VERSION")" || \
    fail "invalid gh release view JSON for $TAG on $REPO"

  local -a conflicts=()
  local c
  while IFS= read -r c; do
    [[ -n "$c" ]] && conflicts+=("$c")
  done < <(release_conflict__conflict_names_from_json "$json" "$VERSION")

  case "$conflict_class" in
    none)
      ok "no conflicting assets on $TAG ($REPO)"
      ;;
    partial)
      ok "partial assets on $TAG ($REPO): ${conflicts[*]} (publish may clobber/fill gaps)"
      ;;
    full)
      fail "release $TAG on $REPO already has all expected assets: ${conflicts[*]}. Delete assets manually or use a new tag."
      ;;
    *)
      fail "unknown conflict class"
      ;;
  esac
}

if [[ "${1:-}" == --plan ]]; then
  TAG="${2:-}"
  REPO="${GITHUB_REPOSITORY:-${4:-}}"
  [[ -n "$TAG" && -n "$REPO" ]] || \
    fail "usage: GITHUB_REPOSITORY=owner/repo check_release_assets_conflict.sh --plan <tag> [version] [repo]"
  release_conflict__invoke_release_view_argv \
    "$TAG" "$REPO" release_conflict__cb_print_argv
  exit 0
fi

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  check_release_assets_conflict__main "$@"
fi