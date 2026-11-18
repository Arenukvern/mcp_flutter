#!/usr/bin/env bash
# Fixtures for release runner shortage classification and attempt cap.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE="$ROOT_DIR/tool/contracts/fixtures/github_runner_not_acquired_annotation.json"
SCRIPT="$ROOT_DIR/tool/release/maybe_rerun_runner_shortage_jobs.sh"

fail() { echo "test_release_runner_retry_decision: $*" >&2; exit 1; }
ok() { echo "test_release_runner_retry_decision: $*"; }

command -v jq >/dev/null 2>&1 || fail "jq required"

NOT_ACQUIRED_RE='not acquired by (a )?Runner'

if ! jq -e --arg re "$NOT_ACQUIRED_RE" \
  '[.[]? | select(.message | test($re; "i"))] | length > 0' \
  "$FIXTURE" >/dev/null; then
  fail "fixture annotation must match NOT_ACQUIRED_RE"
fi
ok "real GitHub runner-not-acquired annotation matches pattern"

old_bad_re='not acquired by a Runner of type hosted'
if jq -e --arg re "$old_bad_re" \
  '[.[]? | select(.message | test($re; "i"))] | length > 0' \
  "$FIXTURE" >/dev/null 2>&1; then
  fail "stale regex with extra article must not match fixture"
else
  ok "stale regex correctly rejected"
fi

attempt_cap_reached() {
  local run_attempt="$1"
  local max_attempts="$2"
  [[ "$run_attempt" -ge "$max_attempts" ]]
}

if attempt_cap_reached 3 3; then
  ok "run_attempt 3 blocks another dispatch (max 3 total runs)"
else
  fail "run_attempt 3 must block"
fi
if attempt_cap_reached 2 3; then
  fail "run_attempt 2 must not block"
else
  ok "run_attempt 2 still eligible"
fi

if ! grep -q 'gh run rerun.*--failed' "$SCRIPT"; then
  fail "script must use single gh run rerun --failed"
fi
ok "single --failed rerun present"

if grep -q 'gh run rerun.*--job' "$SCRIPT"; then
  fail "script must not loop per-job reruns"
fi
ok "no per-job rerun loop"

if ! grep -q 'head_repository.full_name' \
  "$ROOT_DIR/.github/workflows/release_runner_retry.yml"; then
  fail "workflow must guard fork PRs via head_repository"
fi
ok "fork guard uses head_repository"

ok "runner retry decision fixtures OK"