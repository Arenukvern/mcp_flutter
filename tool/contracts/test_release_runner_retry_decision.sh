#!/usr/bin/env bash
# Fixtures for release runner shortage classification and attempt cap.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE="$ROOT_DIR/tool/contracts/fixtures/github_runner_not_acquired_annotation.json"
MANUAL_CANCEL="$ROOT_DIR/tool/contracts/fixtures/release_job_manual_cancel_short.json"
LONG_QUEUE="$ROOT_DIR/tool/contracts/fixtures/release_job_runner_shortage_long_queue.json"
SUPERSEDED="$ROOT_DIR/tool/contracts/fixtures/release_superseded_runs.json"
SCRIPT="$ROOT_DIR/tool/release/maybe_rerun_runner_shortage_jobs.sh"
LIB="$ROOT_DIR/tool/release/runner_shortage_lib.sh"
RETRY_LIB="$ROOT_DIR/tool/release/release_runner_retry_lib.sh"

fail() { echo "test_release_runner_retry_decision: $*" >&2; exit 1; }
ok() { echo "test_release_runner_retry_decision: $*"; }

command -v jq >/dev/null 2>&1 || fail "jq required"
# shellcheck source=../release/runner_shortage_lib.sh
source "$LIB"
# shellcheck source=../release/release_runner_retry_lib.sh
source "$RETRY_LIB"

NOT_ACQUIRED_RE="$NOT_ACQUIRED_RE_DEFAULT"

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

if ! grep -q 'superseded by a newer Release run' "$SCRIPT"; then
  fail "script must skip superseded release runs"
fi
ok "superseded run guard present"

newer="$(release_runner_retry__newer_run_count \
  "$(cat "$SUPERSEDED")" "v7.2.0" "2026-11-17T10:30:00Z" 100)"
[[ "$newer" -gt 0 ]] || fail "superseded fixture must detect newer run"
ok "superseded fixture detects newer run for same tag"

if release_runner_retry__is_superseded \
  "$(cat "$SUPERSEDED")" "v7.2.0" "2026-11-17T10:30:00Z" 100; then
  ok "superseded guard triggers for newer release run"
else
  fail "superseded guard must trigger"
fi

jobs_empty='{"jobs":[]}'
decision="$(release_runner_retry__decide 1 3 "$(cat "$SUPERSEDED")" \
  "v7.2.0" "2026-11-17T10:30:00Z" 100 "$jobs_empty")"
[[ "$decision" == superseded ]] || fail "decide must return superseded"
ok "decide returns superseded without gh"

long_jobs="$(jq -n --argjson j "$(cat "$LONG_QUEUE")" '{jobs: [$j]}')"
decision="$(release_runner_retry__decide 2 3 '{"workflow_runs":[]}' \
  "v7.2.1" "2026-11-17T09:00:00Z" 102 "$long_jobs")"
[[ "$decision" == rerun ]] || fail "long zero-step cancel must decide rerun"
ok "decide classifies runner shortage and requests rerun"

manual_jobs="$(jq -n --argjson j "$(cat "$MANUAL_CANCEL")" '{jobs: [$j]}')"
decision="$(release_runner_retry__decide 1 3 '{"workflow_runs":[]}' \
  "v7.2.1" "2026-11-17T09:00:00Z" 101 "$manual_jobs")"
[[ "$decision" == real_failure ]] || fail "manual short cancel must not rerun"
ok "decide rejects manual short-queue cancel"

if grep -q 'RUNNER_RETRY_SKIP_BACKOFF' "$SCRIPT"; then
  fail "production retry script must not include RUNNER_RETRY_SKIP_BACKOFF"
fi
ok "no test-only retry backoff hook in production script"

job="$(cat "$MANUAL_CANCEL")"
runner_id="$(echo "$job" | jq -r '.runner_id')"
step_count="$(echo "$job" | jq -r '.steps | length')"
created_at="$(echo "$job" | jq -r '.created_at')"
completed_at="$(echo "$job" | jq -r '.completed_at')"

if runner_shortage__zero_step_shortage_candidate \
  "$runner_id" "$step_count" "$created_at" "$completed_at" 600; then
  fail "manual cancel short queue must not match zero-step shortage"
else
  ok "manual cancel short queue rejected"
fi

if runner_shortage__zero_step_shortage_candidate \
  "$runner_id" "$step_count" "" "" 600; then
  fail "missing timestamps must not match zero-step shortage"
else
  ok "missing timestamps rejected"
fi

long_job="$(cat "$LONG_QUEUE")"
long_runner="$(echo "$long_job" | jq -r '.runner_id')"
long_steps="$(echo "$long_job" | jq -r '.steps | length')"
long_created="$(echo "$long_job" | jq -r '.created_at')"
long_completed="$(echo "$long_job" | jq -r '.completed_at')"

if runner_shortage__zero_step_shortage_candidate \
  "$long_runner" "$long_steps" "$long_created" "$long_completed" 600; then
  ok "long zero-step queue classified as shortage"
else
  fail "long zero-step queue must match shortage"
fi

ok "runner retry decision fixtures OK"
