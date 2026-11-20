#!/usr/bin/env bash
# Regression guards for release runner retry workflow.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WF="$ROOT_DIR/.github/workflows/release_runner_retry.yml"
SCRIPT="$ROOT_DIR/tool/release/maybe_rerun_runner_shortage_jobs.sh"

fail() { echo "check_release_runner_retry_workflow: $*" >&2; exit 1; }
ok() { echo "check_release_runner_retry_workflow: $*"; }

[[ -f "$WF" ]] || fail "missing release_runner_retry.yml"
[[ -x "$SCRIPT" ]] || fail "maybe_rerun_runner_shortage_jobs.sh must be executable"

if ! grep -q 'workflows: \[Release\]' "$WF"; then
  fail "workflow must trigger on Release completion"
fi
if ! grep -q "github.event.workflow_run.event == 'push'" "$WF"; then
  fail "workflow must only run for push-triggered Release workflow_run events"
fi
if ! grep -q 'head_repository.full_name == github.repository' "$WF"; then
  fail "workflow must refuse fork PRs via head_repository"
fi
if ! grep -q 'actions: write' "$WF"; then
  fail "workflow must request actions: write"
fi
if grep -q 'contents: write' "$WF"; then
  fail "runner retry must not request contents: write"
fi
if ! grep -q 'maybe_rerun_runner_shortage_jobs.sh' "$WF"; then
  fail "workflow must call maybe_rerun_runner_shortage_jobs.sh"
fi

if command -v actionlint >/dev/null 2>&1; then
  actionlint "$WF" "$ROOT_DIR/.github/workflows/release.yml" || fail "actionlint reported errors"
  ok "actionlint passed"
fi

ok "release runner retry workflow OK"
