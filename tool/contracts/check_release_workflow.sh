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
if ! grep -q 'recovery_mode:' "$WF"; then
  fail "workflow_dispatch must declare recovery_mode input"
fi
if ! grep -q 'resolve_release_tag.sh' "$WF"; then
  fail "release.yml must call resolve_release_tag.sh"
fi
if ! grep -q 'check_release_assets_conflict.sh' "$WF"; then
  fail "release.yml must guard against accidental asset overwrite"
fi
if grep -E 'tag_name:\s*\$\{\{\s*github\.ref_name' "$WF"; then
  fail "publish must not use github.ref_name for tag_name (dispatch runs from main)"
fi
if ! grep -q 'needs.prepare.outputs.release_tag' "$WF"; then
  fail "checkout/publish must use prepare.outputs.release_tag"
fi
if ! grep -q 'verify_release_tarball_architecture.sh' "$WF"; then
  fail "release.yml must verify tarball architecture after build"
fi

ok "release workflow structure OK"
