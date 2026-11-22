#!/usr/bin/env bash
# Regression guardrails for release PR bot sync workflows.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DRIFT="$ROOT_DIR/.github/workflows/skill_assets_drift.yml"
VERSIONS="$ROOT_DIR/.github/workflows/dart_changesets_sync_versions.yml"
SKILLS="$ROOT_DIR/.github/workflows/release_pr_sync_skills.yml"

fail() { echo "check_release_sync_workflows: $*" >&2; exit 1; }
ok() { echo "check_release_sync_workflows: $*"; }

if grep -q 'workflow_run:' "$DRIFT"; then
  fail "skill_assets_drift.yml must not use workflow_run (unsafe head / fork context)"
fi

if grep -q 'build_skill_assets.dart' "$VERSIONS"; then
  fail "dart_changesets_sync_versions.yml must not regenerate skill assets (single owner: sync skills workflow)"
fi

if ! grep -q 'dart-changesets-sync-\${{ github.event.pull_request.number }}' "$VERSIONS"; then
  fail "dart_changesets_sync_versions.yml must use dart-changesets-sync concurrency group"
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
  fail "dart_changesets_sync_versions.yml must not run pre-commit skill_assets git diff verify"
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

# Release surfaces: the in-PR sync bot must cover BOTH trains and BOTH surfaces.
if ! grep -q 'changesets/version-packages' "$SKILLS"; then
  fail "release_pr_sync_skills.yml must trigger on dart_changesets version PRs (changesets/version-packages)"
fi
if ! grep -q 'chore: version packages' "$SKILLS"; then
  fail "release_pr_sync_skills.yml must trigger on the changesets version PR title"
fi
if ! grep -q 'docs-reference' "$SKILLS"; then
  fail "release_pr_sync_skills.yml must regenerate docs/reference (regen owner alongside skill assets)"
fi

# Post-merge safety net for direct-to-main pushes (no PR for the bot to patch).
REGEN="$ROOT_DIR/.github/workflows/regen_surfaces.yml"
[[ -f "$REGEN" ]] || fail "missing regen_surfaces.yml (post-merge regen safety net)"
if ! grep -q 'branches: \[main\]' "$REGEN"; then
  fail "regen_surfaces.yml must run on push to main"
fi
if grep -q 'pull_request:' "$REGEN"; then
  fail "regen_surfaces.yml must not run on pull_request events (in-PR sync belongs to release_pr_sync_skills.yml)"
fi
if grep -q 'workflow_run:' "$REGEN"; then
  if ! grep -q 'workflows: \[dart_changesets publish\]' "$REGEN"; then
    fail "regen_surfaces.yml workflow_run leg must pin the dart_changesets publish workflow"
  fi
  if ! grep -qE 'ref: main' "$REGEN"; then
    fail "regen_surfaces.yml must always checkout refs/heads/main (never the workflow_run head)"
  fi
fi
if ! grep -q 'RELEASE_PLEASE_TOKEN || secrets.GITHUB_TOKEN' "$REGEN"; then
  fail "regen_surfaces.yml must use RELEASE_PLEASE_TOKEN with GITHUB_TOKEN fallback (GITHUB_TOKEN PRs do not trigger checks)"
fi
if ! grep -q -- '--auto' "$REGEN"; then
  fail "regen_surfaces.yml must enable auto-merge on the regen PR"
fi

ok "release PR sync workflow structure OK"
