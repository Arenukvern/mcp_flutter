#!/usr/bin/env bash
# When invoked from a dart_changesets per-package tag (workflow_call), create the
# root binary train tag vX.Y.Z and GitHub release when absent.
set -euo pipefail

fail() { echo "ensure_root_release_tag: $*" >&2; exit 1; }

SOURCE_TAG="${1:-}"
[[ -n "$SOURCE_TAG" ]] || fail "usage: ensure_root_release_tag.sh <package-vX.Y.Z>"

if [[ ! "$SOURCE_TAG" =~ ^[a-zA-Z0-9_]+-v([0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?)$ ]]; then
  fail "unsupported source tag format: $SOURCE_TAG"
fi
version="${BASH_REMATCH[1]}"
root_tag="v${version}"

if git rev-parse "$root_tag" >/dev/null 2>&1; then
  echo "ensure_root_release_tag: $root_tag already exists"
  exit 0
fi

git fetch --tags origin
sha="$(git rev-parse "$SOURCE_TAG^{commit}")"
git tag "$root_tag" "$sha"
git push origin "$root_tag"

notes="$(bash "$(dirname "${BASH_SOURCE[0]}")/extract_package_release_notes.sh" "$version")"

gh release create "$root_tag" \
  --title "Flutter MCP Toolkit $version" \
  --notes "$notes" \
  --verify-tag

echo "ensure_root_release_tag: created $root_tag"