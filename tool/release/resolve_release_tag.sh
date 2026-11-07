#!/usr/bin/env bash
# Resolve release_tag for tag-push and workflow_dispatch runs.
# Writes: release_tag, version to GITHUB_OUTPUT when set.
set -euo pipefail

fail() { echo "resolve_release_tag: $*" >&2; exit 1; }

EVENT_NAME="${GITHUB_EVENT_NAME:-}"
REF_NAME="${GITHUB_REF_NAME:-}"
DISPATCH_TAG="${DISPATCH_RELEASE_TAG:-}"

resolve_tag() {
  local tag=""
  if [[ "$EVENT_NAME" == "workflow_dispatch" ]]; then
    tag="$DISPATCH_TAG"
  elif [[ "$EVENT_NAME" == "push" ]]; then
    tag="$REF_NAME"
  else
    fail "unsupported GITHUB_EVENT_NAME: $EVENT_NAME"
  fi

  if [[ -z "$tag" ]]; then
    fail "empty release tag"
  fi
  if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    fail "release tag must match vMAJOR.MINOR.PATCH (got '$tag')"
  fi
  if [[ "$tag" == *".."* || "$tag" == *"/"* || "$tag" == *"\\"* ]]; then
    fail "release tag contains invalid path characters"
  fi
  printf '%s' "$tag"
}

TAG="$(resolve_tag)"
VERSION="${TAG#v}"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "release_tag=$TAG"
    echo "version=$VERSION"
  } >>"$GITHUB_OUTPUT"
fi

echo "resolve_release_tag: tag=$TAG version=$VERSION"
