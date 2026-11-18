#!/usr/bin/env bash
# Decide whether to re-run GitHub Actions jobs cancelled by hosted-runner shortages.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=runner_shortage_lib.sh
source "$ROOT_DIR/tool/release/runner_shortage_lib.sh"
# shellcheck source=release_runner_retry_lib.sh
source "$ROOT_DIR/tool/release/release_runner_retry_lib.sh"

SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

log() {
  echo "$*" | tee -a "$SUMMARY"
}

fail() {
  log "❌ $*"
  exit 1
}

if [[ "${1:-}" == --plan ]]; then
  state_file="${2:-}"
  [[ -f "$state_file" ]] || fail "usage: maybe_rerun_runner_shortage_jobs.sh --plan <state.json>"
  plan="$(release_runner_retry__plan_from_state_file "$state_file")"
  echo "$plan"
  [[ "$(echo "$plan" | jq -r '.ok')" == "true" ]] || fail "$(echo "$plan" | jq -r '.error')"
  exit 0
fi

RUN_ID="${1:-}"
REPO="${2:-}"
RUN_ATTEMPT="${3:-1}"
MAX_ATTEMPTS="${4:-3}"

[[ -n "$RUN_ID" && -n "$REPO" ]] || \
  fail "usage: maybe_rerun_runner_shortage_jobs.sh <run-id> <owner/repo> [run_attempt] [max_attempts]"

command -v gh >/dev/null 2>&1 || fail "gh CLI required"
command -v jq >/dev/null 2>&1 || fail "jq required"

log "## Release runner retry decision"
log ""
log "- Workflow run: $RUN_ID"
log "- Repository: $REPO"
log "- Run attempt: $RUN_ATTEMPT / $MAX_ATTEMPTS (max total runs)"

run_json="$(gh api "repos/$REPO/actions/runs/$RUN_ID")"
head_branch="$(echo "$run_json" | jq -r '.head_branch // empty')"
created_at="$(echo "$run_json" | jq -r '.created_at // empty')"
workflow_event="$(echo "$run_json" | jq -r '.event // empty')"

workflow_runs_json='{"workflow_runs":[]}'
workflow_id="$(gh api "repos/$REPO/actions/workflows" \
  --jq '.workflows[] | select(.path | endswith("release.yml")) | .id' | head -n1)"
if [[ -n "$workflow_id" ]]; then
  workflow_runs_json="$(gh api \
    "repos/$REPO/actions/workflows/$workflow_id/runs?per_page=30")"
fi

jobs_json="$(gh api "repos/$REPO/actions/runs/$RUN_ID/jobs" --paginate)"

enriched_jobs='[]'
while IFS= read -r job_line; do
  [[ -n "$job_line" ]] || continue
  check_run_url="$(echo "$job_line" | jq -r '.check_run_url // empty')"
  annotations='[]'
  if [[ -n "$check_run_url" && "$check_run_url" != "null" ]]; then
    annotations="$(gh api "${check_run_url%/}/annotations" --paginate 2>/dev/null || echo '[]')"
  fi
  job_with_ann="$(echo "$job_line" | jq -c --argjson ann "$annotations" '. + {annotations: $ann}')"
  enriched_jobs="$(jq -c --argjson j "$job_with_ann" '. + [$j]' <<<"$enriched_jobs")"
done < <(echo "$jobs_json" | jq -c '.jobs[]?')

state_file="$(mktemp)"
jq -n \
  --argjson run_attempt "$RUN_ATTEMPT" \
  --argjson max_attempts "$MAX_ATTEMPTS" \
  --arg head_branch "$head_branch" \
  --arg created_at "$created_at" \
  --argjson run_id "$RUN_ID" \
  --arg workflow_event "$workflow_event" \
  --argjson workflow_runs "$workflow_runs_json" \
  --argjson jobs "$enriched_jobs" \
  --arg not_acquired_re "$NOT_ACQUIRED_RE_DEFAULT" \
  --argjson min_wait "$ZERO_STEP_MIN_WAIT_SECONDS_DEFAULT" \
  '{
    run_attempt: $run_attempt,
    max_attempts: $max_attempts,
    head_branch: $head_branch,
    created_at: $created_at,
    run_id: $run_id,
    workflow_event: $workflow_event,
    workflow_runs: $workflow_runs,
    jobs: $jobs,
    not_acquired_re: $not_acquired_re,
    zero_step_min_wait_seconds: $min_wait
  }' >"$state_file"

plan="$(release_runner_retry__plan_from_state_file "$state_file")"
rm -f "$state_file"

[[ "$(echo "$plan" | jq -r '.ok')" == "true" ]] || fail "$(echo "$plan" | jq -r '.error')"

decision="$(echo "$plan" | jq -r '.decision')"
case "$decision" in
  cap)
    log ""
    log "**No rerun:** attempt cap reached (max $MAX_ATTEMPTS total runs)."
    exit 0
    ;;
  skip_event)
    log ""
    log "**No rerun:** workflow event is not push."
    exit 0
    ;;
  superseded)
    log ""
    log "**No rerun:** superseded by a newer Release run for \`$head_branch\`."
    exit 0
    ;;
  real_failure)
    log ""
    log "**No rerun:** real build/test failures or non-shortage cancellations."
    exit 0
    ;;
  unclassified)
    log ""
    log "**No rerun:** unclassified failure jobs present."
    exit 0
    ;;
  no_shortage)
    log ""
    log "**No rerun:** no runner-shortage cancellations detected."
    exit 0
    ;;
  rerun)
    sleep_seconds="$(echo "$plan" | jq -r '.sleep_seconds')"
    log ""
    log "Backoff: waiting ${sleep_seconds}s (120s × run attempt $RUN_ATTEMPT) before rerun..."
    sleep "$sleep_seconds"
    log ""
    log "**Rerunning failed jobs (single dispatch):** run $RUN_ID"
    gh run rerun "$RUN_ID" --repo "$REPO" --failed
    log ""
    log "**Rerun dispatched.** Dependent publish should resume once all build jobs succeed."
    ;;
  *)
    fail "unknown retry decision: $decision"
    ;;
esac