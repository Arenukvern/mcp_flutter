#!/usr/bin/env bash
# Resolve release_tag for tag-push, workflow_dispatch, and workflow_call runs.
# Writes: release_tag, version to GITHUB_OUTPUT when set.
set -euo pipefail

fail() { echo "resolve_release_tag: $*" >&2; exit 1; }

EVENT_NAME="${GITHUB_EVENT_NAME:-}"
REF_NAME="${GITHUB_REF_NAME:-}"
DISPATCH_TAG="${DISPATCH_RELEASE_TAG:-}"

resolve_input_tag() {
  local tag=""
  case "$EVENT_NAME" in
    workflow_dispatch)
      tag="$DISPATCH_TAG"
      ;;
    push)
      tag="$REF_NAME"
      ;;
    workflow_call)
      tag="$DISPATCH_TAG"
      ;;
    *)
      fail "unsupported GITHUB_EVENT_NAME: $EVENT_NAME"
      ;;
  esac

  if [[ -z "$tag" ]]; then
    fail "empty release tag"
  fi
  if [[ "$tag" == *".."* || "$tag" == *"/"* || "$tag" == *"\\"* ]]; then
    fail "release tag contains invalid path characters"
  fi
  printf '%s' "$tag"
}

INPUT_TAG="$(resolve_input_tag)"
TAG="$INPUT_TAG"
VERSION=""

if [[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]]; then
  VERSION="${TAG#v}"
elif [[ "$TAG" =~ ^[a-zA-Z0-9_]+-v([0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?)$ ]]; then
  VERSION="${BASH_REMATCH[1]}"
  TAG="v${VERSION}"
else
  fail "release tag must be vMAJOR.MINOR.PATCH or <package>-vMAJOR.MINOR.PATCH (got '$INPUT_TAG')"
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "release_tag=$TAG"
    echo "version=$VERSION"
    echo "source_tag=$INPUT_TAG"
  } >>"$GITHUB_OUTPUT"
fi

echo "resolve_release_tag: tag=$TAG version=$VERSION source=$INPUT_TAG"