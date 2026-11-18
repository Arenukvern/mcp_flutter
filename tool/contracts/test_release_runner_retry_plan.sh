#!/usr/bin/env bash
# Plan-mode contracts + mutation checks for runner retry (no gh).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/tool/release/maybe_rerun_runner_shortage_jobs.sh"
SUPERSEDED="$ROOT_DIR/tool/contracts/fixtures/release_superseded_runs.json"
LONG_QUEUE="$ROOT_DIR/tool/contracts/fixtures/release_job_runner_shortage_long_queue.json"
MANUAL_CANCEL="$ROOT_DIR/tool/contracts/fixtures/release_job_manual_cancel_short.json"
ANNOTATION="$ROOT_DIR/tool/contracts/fixtures/github_runner_not_acquired_annotation.json"
LIB="$ROOT_DIR/tool/release/runner_shortage_lib.sh"
RETRY_LIB="$ROOT_DIR/tool/release/release_runner_retry_lib.sh"

fail() { echo "test_release_runner_retry_plan: $*" >&2; exit 1; }
ok() { echo "test_release_runner_retry_plan: $*"; }

command -v jq >/dev/null 2>&1 || fail "jq required"
# shellcheck source=../release/runner_shortage_lib.sh
source "$LIB"
# shellcheck source=../release/release_runner_retry_lib.sh
source "$RETRY_LIB"

long_job="$(jq -c --argjson ann "$(cat "$ANNOTATION")" \
  '. + {annotations: $ann}' "$LONG_QUEUE")"
state_rerun="$(mktemp)"
jq -n \
  --argjson run_attempt 2 \
  --argjson max_attempts 3 \
  --arg hb "v7.2.1" \
  --arg ts "2026-11-17T09:00:00Z" \
  --argjson run_id 102 \
  --argjson wf "$(cat "$SUPERSEDED")" \
  --argjson jobs "$(jq -n --argjson j "$long_job" '[$j]')" \
  '{
    run_attempt: $run_attempt,
    max_attempts: $max_attempts,
    head_branch: $hb,
    created_at: $ts,
    run_id: $run_id,
    workflow_event: "push",
    workflow_runs: $wf,
    jobs: $jobs,
    zero_step_min_wait_seconds: 600
  }' >"$state_rerun"

bash "$SCRIPT" --plan "$state_rerun" >/dev/null || fail "plan mode must succeed"
[[ "$(bash "$SCRIPT" --plan "$state_rerun" | jq -r '.decision')" == rerun ]] || \
  fail "must decide rerun"
[[ "$(bash "$SCRIPT" --plan "$state_rerun" | jq -r '.sleep_seconds')" -eq 240 ]] || \
  fail "backoff must be 120×attempt"
ok "plan mode rerun with annotations"

state_sup="$(mktemp)"
jq -n \
  --argjson run_attempt 1 \
  --argjson max_attempts 3 \
  --arg hb "v7.2.0" \
  --arg ts "2026-11-17T10:30:00Z" \
  --argjson run_id 100 \
  --argjson wf "$(cat "$SUPERSEDED")" \
  '{
    run_attempt: $run_attempt,
    max_attempts: $max_attempts,
    head_branch: $hb,
    created_at: $ts,
    run_id: $run_id,
    workflow_event: "push",
    workflow_runs: $wf,
    jobs: []
  }' >"$state_sup"
[[ "$(release_runner_retry__plan_from_state_file "$state_sup" | jq -r '.decision')" == superseded ]] || \
  fail "superseded guard"
ok "superseded via shared plan"

state_event="$(mktemp)"
jq '.workflow_event = "workflow_dispatch"' "$state_rerun" >"$state_event"
[[ "$(release_runner_retry__plan_from_state_file "$state_event" | jq -r '.decision')" == skip_event ]] || \
  fail "non-push event must skip"
ok "push-only guard"

state_cap="$(mktemp)"
jq '.run_attempt = 3' "$state_rerun" >"$state_cap"
[[ "$(release_runner_retry__plan_from_state_file "$state_cap" | jq -r '.decision')" == cap ]] || \
  fail "attempt cap uses >="
ok "attempt cap at 3/3"

grep -q 'release_runner_retry__plan_from_state_file' "$SCRIPT" || \
  fail "production script must call shared plan"

mutate_retry_lib() {
  cp "$RETRY_LIB" "$1"
  sed -i "${@:2}" "$1"
}

mutated="$(mktemp)"
cp "$RETRY_LIB" "$mutated"
sed -i 's/-ge "$max_attempts"/-gt "$max_attempts"/' "$mutated"
# shellcheck source=/dev/null
source "$mutated"
if release_runner_retry__attempt_cap_reached 3 3; then
  fail "mutation -gt cap must not block at 3/3"
else
  ok "mutation blocked: attempt cap"
fi

# shellcheck source=../release/release_runner_retry_lib.sh
source "$RETRY_LIB"
cp "$RETRY_LIB" "$mutated"
sed -i '/^release_runner_retry__is_superseded()/,/^}$/c\
release_runner_retry__is_superseded() { return 1; }\
' "$mutated"
# shellcheck source=/dev/null
source "$mutated"
[[ "$(release_runner_retry__plan_from_state_file "$state_sup" | jq -r '.decision')" != superseded ]] && \
  ok "mutation blocked: superseded guard" || fail "superseded mutation undetected"
# shellcheck source=../release/release_runner_retry_lib.sh
source "$RETRY_LIB"

# shellcheck source=../release/release_runner_retry_lib.sh
source "$RETRY_LIB"
cp "$RETRY_LIB" "$mutated"
sed -i 's/workflow_event" != "push"/workflow_event" != "never_push"/' "$mutated"
# shellcheck source=/dev/null
source "$mutated"
[[ "$(release_runner_retry__plan_from_state_file "$state_event" | jq -r '.decision')" == skip_event ]] || \
  fail "push guard broken under mutation"
ok "mutation blocked: push-only"

# shellcheck source=../release/runner_shortage_lib.sh
source "$LIB"
# shellcheck source=../release/release_runner_retry_lib.sh
source "$RETRY_LIB"
short_job="$(jq -c '.annotations=[]' "$MANUAL_CANCEL")"
state_short="$(mktemp)"
jq -n \
  --argjson run_attempt 1 \
  --argjson max_attempts 3 \
  --argjson run_id 99 \
  --argjson jobs "$(jq -n --argjson j "$short_job" '[$j]')" \
  '{
    run_attempt: $run_attempt,
    max_attempts: $max_attempts,
    head_branch: "v7.2.1",
    created_at: "2026-11-17T09:00:00Z",
    run_id: $run_id,
    workflow_event: "push",
    workflow_runs: {workflow_runs:[]},
    jobs: $jobs,
    zero_step_min_wait_seconds: 600
  }' >"$state_short"
short_decision="$(release_runner_retry__plan_from_state_file "$state_short" | jq -r '.decision')"
[[ "$short_decision" == rerun ]] && fail "600s wait guard must reject short queue"
shortage_mut="$(mktemp)"
cp "$LIB" "$shortage_mut"
sed -i 's/-ge "\$min_seconds"/-ge 0/' "$shortage_mut"
# shellcheck source=/dev/null
source "$shortage_mut"
[[ "$(release_runner_retry__plan_from_state_file "$state_short" | jq -r '.decision')" == rerun ]] && \
  ok "mutation blocked: 600s minimum wait" || fail "600s wait mutation undetected"

ok "runner retry plan contracts OK"