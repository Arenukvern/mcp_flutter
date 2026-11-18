#!/usr/bin/env bash
# Fail when a GitHub release already has expected binary asset names (no overwrite).
set -euo pipefail

RELEASE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=release_assets_conflict_lib.sh
source "$RELEASE_SCRIPT_DIR/release_assets_conflict_lib.sh"

fail() { echo "check_release_assets_conflict: $*" >&2; exit 1; }
ok() { echo "check_release_assets_conflict: $*"; }

check_release_assets_conflict__assert_tag() {
  local tag="$1"
  [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "invalid tag format"
}

check_release_assets_conflict__main() {
  local TAG="${1:-}"
  local VERSION="${2:-}"
  local REPO="${GITHUB_REPOSITORY:-${3:-}}"

  [[ -n "$TAG" && -n "$VERSION" && -n "$REPO" ]] || \
    fail "usage: GITHUB_REPOSITORY=owner/repo check_release_assets_conflict.sh <tag> <version>"

  check_release_assets_conflict__assert_tag "$TAG"

  command -v gh >/dev/null 2>&1 || fail "gh CLI required"
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

check_release_assets_conflict__plan_main() {
  local TAG="${2:-}"
  local REPO="${GITHUB_REPOSITORY:-${4:-}}"
  [[ -n "$TAG" && -n "$REPO" ]] || \
    fail "usage: GITHUB_REPOSITORY=owner/repo check_release_assets_conflict.sh --plan <tag> [version] [repo]"
  check_release_assets_conflict__assert_tag "$TAG"
  release_conflict__invoke_release_view_argv \
    "$TAG" "$REPO" release_conflict__cb_print_argv
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ "${1:-}" == --plan ]]; then
    check_release_assets_conflict__plan_main "$@"
    exit 0
  fi
  check_release_assets_conflict__main "$@"
fi
