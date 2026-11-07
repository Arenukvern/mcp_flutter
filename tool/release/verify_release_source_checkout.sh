#!/usr/bin/env bash
# Ensure release-src checkout matches the annotated tag and expected commit SHA.
set -euo pipefail

fail() { echo "verify_release_source_checkout: $*" >&2; exit 1; }
ok() { echo "verify_release_source_checkout: $*"; }

RELEASE_SRC="${1:-}"
TAG="${2:-}"
EXPECTED_SHA="${3:-}"

[[ -d "$RELEASE_SRC/.git" || -f "$RELEASE_SRC/.git" ]] || fail "release source is not a git checkout: $RELEASE_SRC"
[[ -n "$TAG" && -n "$EXPECTED_SHA" ]] || fail "usage: verify_release_source_checkout.sh <release-src> <tag> <expected_sha>"

if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  fail "invalid tag: $TAG"
fi

head_sha="$(git -C "$RELEASE_SRC" rev-parse "HEAD^{commit}")"
tag_sha="$(git -C "$RELEASE_SRC" rev-parse "refs/tags/${TAG}^{commit}")"

if [[ "$head_sha" != "$tag_sha" ]]; then
  fail "HEAD ($head_sha) != refs/tags/${TAG}^{commit} ($tag_sha)"
fi
if [[ "$head_sha" != "$EXPECTED_SHA" ]]; then
  fail "HEAD ($head_sha) != expected release_sha ($EXPECTED_SHA)"
fi

ok "release-src at $head_sha matches tag $TAG"
