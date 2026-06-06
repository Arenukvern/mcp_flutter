#!/usr/bin/env bash
# Assert that the pushed release tag matches root VERSION.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
TAG="${1:-${GITHUB_REF_NAME:-}}"

if [[ -z "$TAG" ]]; then
  echo "assert_release_tag: pass the tag or set GITHUB_REF_NAME" >&2
  exit 1
fi

EXPECTED="v$VERSION"
if [[ "$TAG" != "$EXPECTED" ]]; then
  echo "assert_release_tag: tag '$TAG' does not match VERSION '$VERSION' (expected '$EXPECTED')" >&2
  exit 1
fi

echo "assert_release_tag: $TAG matches VERSION $VERSION"
