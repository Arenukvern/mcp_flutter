#!/usr/bin/env bash
# Decide whether to re-run GitHub Actions jobs cancelled by hosted-runner shortages.
set -euo pipefail

RUN_ID="${1:-}"
REPO="${2:-}"
RUN_ATTEMPT="${3:-1}"
MAX_ATTEMPTS="${4:-3}"

SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stdout}"
# GitHub: "The job was not acquired by Runner of type hosted even after multiple attempts"
NOT_ACQUIRED_RE='not acquired by (a )?Runner'
ZERO_STEP_MIN_WAIT_SECONDS=600

log() {
  echo "$*" | tee -a "$SUMMARY"
}

fail() {
  log "❌ $*"
  exit 1
}

[[ -n "$RUN_ID" && -n "$REPO" ]] || \
  fail "usage: maybe_rerun_runner_shortage_jobs.sh <run-id> <owner/repo> [run_attempt] [max_attempts]"

command -v gh >/dev/null 2>&1 || fail "gh CLI required"
command -v jq >/dev/null 2>&1 || fail "jq required"

log "## Release runner retry decision"
log ""
log "- Workflow run: $RUN_ID"
log "- Repository: $REPO"
log "- Run attempt: $RUN_ATTEMPT / $MAX_ATTEMPTS (max total runs)"

if [[ "$RUN_ATTEMPT" -ge "$MAX_ATTEMPTS" ]]; then
  log ""
  log "**No rerun:** attempt cap reached (max $MAX_ATTEMPTS total runs)."
  exit 0
fi

jobs_json="$(gh api "repos/$REPO/actions/runs/$RUN_ID/jobs" --paginate)"

job_has_not_acquired_annotation() {
  local check_run_url="$1"
  [[ -n "$check_run_url" && "$check_run_url" != "null" ]] || return 1
  local annotations
  annotations="$(gh api "${check_run_url%/}/annotations" --paginate 2>/dev/null || true)"
  echo "$annotations" | jq -e --arg re "$NOT_ACQUIRED_RE" \
    '[.[]? | select(.message | test($re; "i"))] | length > 0' >/dev/null
}

job_waited_at_least_seconds() {
  local created_at="$1"
  local completed_at="$2"
  local min_seconds="$3"
  [[ -n "$created_at" && -n "$completed_at" ]] || return 1
  local created_epoch completed_epoch
  created_epoch="$(date -d "$created_at" +%s 2>/dev/null || echo 0)"
  completed_epoch="$(date -d "$completed_at" +%s 2>/dev/null || echo 0)"
  [[ "$created_epoch" -gt 0 && "$completed_epoch" -ge "$created_epoch" ]] || return 1
  [[ $((completed_epoch - created_epoch)) -ge "$min_seconds" ]]
}

runner_shortage_detected=false
real_failure_jobs=()

while IFS= read -r job_line; do
  [[ -n "$job_line" ]] || continue
  job_id="$(echo "$job_line" | jq -r '.id')"
  job_name="$(echo "$job_line" | jq -r '.name')"
  conclusion="$(echo "$job_line" | jq -r '.conclusion')"
  runner_id="$(echo "$job_line" | jq -r '.runner_id')"
  step_count="$(echo "$job_line" | jq -r '.steps | length')"
  check_run_url="$(echo "$job_line" | jq -r '.check_run_url // empty')"
  created_at="$(echo "$job_line" | jq -r '.created_at // empty')"
  completed_at="$(echo "$job_line" | jq -r '.completed_at // empty')"

  if [[ "$conclusion" == "failure" ]]; then
    failed_steps="$(echo "$job_line" | jq -r \
      '[.steps[]? | select(.conclusion == "failure")] | length')"
    if [[ "$failed_steps" -gt 0 ]]; then
      real_failure_jobs+=("$job_name ($job_id)")
      continue
    fi
  fi

  if [[ "$conclusion" != "cancelled" ]]; then
    continue
  fi

  if job_has_not_acquired_annotation "$check_run_url"; then
    log "- Classified runner shortage (annotation): $job_name ($job_id)"
    runner_shortage_detected=true
    continue
  fi

  if [[ "$runner_id" == "0" && "$step_count" == "0" ]] && \
    job_waited_at_least_seconds "$created_at" "$completed_at" "$ZERO_STEP_MIN_WAIT_SECONDS"; then
    log "- Classified runner shortage (zero steps, waited >= ${ZERO_STEP_MIN_WAIT_SECONDS}s): $job_name ($job_id)"
    runner_shortage_detected=true
    continue
  fi

  real_failure_jobs+=("$job_name ($job_id)")
done < <(echo "$jobs_json" | jq -c '.jobs[]?')

if [[ ${#real_failure_jobs[@]} -gt 0 ]]; then
  log ""
  log "**No rerun:** real build/test failures or non-shortage cancellations:"
  for name in "${real_failure_jobs[@]}"; do
    log "- $name"
  done
  exit 0
fi

if [[ "$runner_shortage_detected" != true ]]; then
  log ""
  log "**No rerun:** no runner-shortage cancellations detected."
  exit 0
fi

sleep_seconds=$((120 * RUN_ATTEMPT))
log ""
log "Backing off ${sleep_seconds}s before rerun..."
sleep "$sleep_seconds"

log ""
log "**Rerunning failed jobs (single dispatch):** run $RUN_ID"
gh run rerun "$RUN_ID" --repo "$REPO" --failed

log ""
log "**Rerun dispatched.** Dependent publish should resume once all build jobs succeed."