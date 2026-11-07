#!/usr/bin/env bash
# Regression guardrails for release PR bot sync workflows.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DRIFT="$ROOT_DIR/.github/workflows/skill_assets_drift.yml"
VERSIONS="$ROOT_DIR/.github/workflows/release_pr_sync_versions.yml"
SKILLS="$ROOT_DIR/.github/workflows/release_pr_sync_skills.yml"

fail() { echo "check_release_sync_workflows: $*" >&2; exit 1; }
ok() { echo "check_release_sync_workflows: $*"; }

if grep -q 'workflow_run:' "$DRIFT"; then
  fail "skill_assets_drift.yml must not use workflow_run (unsafe head / fork context)"
fi

if grep -q 'build_skill_assets.dart' "$VERSIONS"; then
  fail "release_pr_sync_versions.yml must not regenerate skill assets (single owner: sync skills workflow)"
fi

if ! grep -q 'release-pr-automation-\${{ github.event.pull_request.number }}' "$VERSIONS"; then
  fail "release_pr_sync_versions.yml must use shared release-pr-automation concurrency group"
fi
if ! grep -q 'release-pr-automation-\${{ github.event.pull_request.number }}' "$SKILLS"; then
  fail "release_pr_sync_skills.yml must use shared release-pr-automation concurrency group"
fi

for wf in "$VERSIONS" "$SKILLS"; do
  if grep -q 'title="\${{ github.event.pull_request.title }}"' "$wf"; then
    fail "$(basename "$wf") must not interpolate PR title inline in shell"
  fi
  if ! grep -q 'PR_TITLE:' "$wf"; then
    fail "$(basename "$wf") must pass PR title via env"
  fi
done

if grep -q 'Verify skill assets before commit' "$VERSIONS"; then
  fail "release_pr_sync_versions.yml must not run pre-commit skill_assets git diff verify"
fi

if ! grep -q 'statuses: write' "$SKILLS"; then
  fail "release_pr_sync_skills.yml needs statuses: write for post-push verification status"
fi

for wf in "$VERSIONS" "$SKILLS"; do
  if grep -E 'git push.*github\.event\.pull_request\.head\.ref' "$wf"; then
    fail "$(basename "$wf") must not interpolate head.ref inside git push run scripts"
  fi
  if ! grep -q 'HEAD_REF:' "$wf"; then
    fail "$(basename "$wf") git push step must set HEAD_REF env"
  fi
  if ! grep -q 'HEAD:refs/heads/\${HEAD_REF}' "$wf"; then
    fail "$(basename "$wf") must push via quoted HEAD:refs/heads/\${HEAD_REF}"
  fi
done

ok "release PR sync workflow structure OK"
