#!/usr/bin/env bash
# Regression guards for .github/workflows/release.yml (tag push + dispatch recovery).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WF="$ROOT_DIR/.github/workflows/release.yml"

fail() { echo "check_release_workflow: $*" >&2; exit 1; }
ok() { echo "check_release_workflow: $*"; }

[[ -f "$WF" ]] || fail "missing release.yml"

if grep -q 'macos-14' "$WF"; then
  fail "release.yml must not use retired macos-14 runner"
fi
if ! grep -q 'macos-15' "$WF"; then
  fail "release.yml must use macos-15 for darwin-arm64"
fi
if ! grep -q 'workflow_dispatch:' "$WF"; then
  fail "release.yml must support workflow_dispatch for asset recovery"
fi
if ! grep -q 'release_tag:' "$WF"; then
  fail "workflow_dispatch must declare release_tag input"
fi
if grep -q 'recovery_mode:' "$WF"; then
  fail "workflow must not expose recovery_mode overwrite escape hatch"
fi
if ! grep -q 'TOOLING_CHECKOUT_PATH' "$WF"; then
  fail "workflow must checkout trusted tooling separately"
fi
if ! grep -q 'RELEASE_SRC_PATH' "$WF"; then
  fail "workflow must checkout release-src separately"
fi
if ! grep -q 'persist-credentials: false' "$WF"; then
  fail "tooling checkout must set persist-credentials: false"
fi
if ! grep -q 'release_sha:' "$WF"; then
  fail "prepare must output release_sha"
fi
if ! grep -q 'verify_release_source_checkout.sh' "$WF"; then
  fail "build must verify release-src SHA against prepare output"
fi
if ! grep -q 'TOOLING_CHECKOUT_PATH.*resolve_release_tag' "$WF" && \
   ! grep -q 'tool/release/resolve_release_tag.sh' "$WF"; then
  fail "resolve_release_tag must run from tooling checkout"
fi
if grep -E 'tag_name:\s*\$\{\{\s*github\.ref_name' "$WF"; then
  fail "publish must not use github.ref_name for tag_name"
fi
if ! grep -q 'needs.prepare.outputs.release_tag' "$WF"; then
  fail "publish must use prepare.outputs.release_tag"
fi
if ! grep -q 'verify_release_tarball_architecture.sh' "$WF"; then
  fail "release.yml must verify tarball architecture from tooling"
fi
if ! grep -q 'GITHUB_REPOSITORY' "$WF"; then
  fail "gh calls must pass explicit GITHUB_REPOSITORY"
fi

if command -v actionlint >/dev/null 2>&1; then
  actionlint "$WF" || fail "actionlint reported errors"
  ok "actionlint passed"
else
  ok "actionlint not installed (structural grep guards only)"
fi

ok "release workflow structure OK"
