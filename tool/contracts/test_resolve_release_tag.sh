#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/tool/release/resolve_release_tag.sh"

fail() { echo "test_resolve_release_tag: $*" >&2; exit 1; }
ok() { echo "test_resolve_release_tag: $*"; }

run_case() {
  local name="$1"
  shift
  set +e
  out="$(env "$@" bash "$SCRIPT" 2>&1)"
  code=$?
  set -e
  printf '%s\n' "$out"
  return "$code"
}

if run_case push_ok GITHUB_EVENT_NAME=push GITHUB_REF_NAME=v7.0.2 | grep -q 'tag=v7.0.2'; then
  ok "tag push resolves ref"
else
  fail "tag push resolution failed"
fi

if run_case dispatch_ok GITHUB_EVENT_NAME=workflow_dispatch DISPATCH_RELEASE_TAG=v7.0.2 RECOVERY_MODE=true | grep -q 'recovery_mode=true'; then
  ok "dispatch ok"
else
  fail "dispatch resolution failed"
fi

if run_case bad_tag GITHUB_EVENT_NAME=workflow_dispatch DISPATCH_RELEASE_TAG='v7.0.2;rm -rf' >/dev/null 2>&1; then
  fail "must reject shell metacharacters in tag"
else
  ok "rejects invalid tag"
fi

if run_case bad_ref GITHUB_EVENT_NAME=workflow_dispatch DISPATCH_RELEASE_TAG='../v7.0.2' >/dev/null 2>&1; then
  fail "must reject path-like tag"
else
  ok "rejects path injection"
fi

ok "resolve_release_tag cases OK"
