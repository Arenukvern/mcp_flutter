#!/usr/bin/env bash
# Decide whether to re-run GitHub Actions jobs cancelled by hosted-runner shortages.
set -euo pipefail

RUN_ID="${1:-}"
REPO="${2:-}"
RUN_ATTEMPT="${3:-1}"
MAX_ATTEMPTS="${4:-3}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=runner_shortage_lib.sh
source "$ROOT_DIR/tool/release/runner_shortage_lib.sh"
# shellcheck source=release_runner_retry_lib.sh
source "$ROOT_DIR/tool/release/release_runner_retry_lib.sh"

SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stdout}"
NOT_ACQUIRED_RE="$NOT_ACQUIRED_RE_DEFAULT"
ZERO_STEP_MIN_WAIT_SECONDS="$ZERO_STEP_MIN_WAIT_SECONDS_DEFAULT"

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

run_json="$(gh api "repos/$REPO/actions/runs/$RUN_ID")"
head_branch="$(echo "$run_json" | jq -r '.head_branch // empty')"
created_at="$(echo "$run_json" | jq -r '.created_at // empty')"

workflow_runs_json='{"workflow_runs":[]}'
if [[ -n "$head_branch" && -n "$created_at" ]]; then
  workflow_id="$(gh api "repos/$REPO/actions/workflows" \
    --jq '.workflows[] | select(.path | endswith("release.yml")) | .id' | head -n1)"
  if [[ -n "$workflow_id" ]]; then
    workflow_runs_json="$(gh api \
      "repos/$REPO/actions/workflows/$workflow_id/runs?per_page=30")"
    if release_runner_retry__is_superseded \
      "$workflow_runs_json" "$head_branch" "$created_at" "$RUN_ID"; then
      log ""
      log "**No rerun:** superseded by a newer Release run for \`$head_branch\`."
      exit 0
    fi
  fi
fi

jobs_json="$(gh api "repos/$REPO/actions/runs/$RUN_ID/jobs" --paginate)"

job_has_not_acquired_annotation() {
  local check_run_url="$1"
  [[ -n "$check_run_url" && "$check_run_url" != "null" ]] || return 1
  local annotations
  annotations="$(gh api "${check_run_url%/}/annotations" --paginate 2>/dev/null || true)"
  runner_shortage__annotation_matches "$annotations" "$NOT_ACQUIRED_RE"
}

runner_shortage_detected=false
real_failure_jobs=()
unclassified_jobs=()

while IFS= read -r job_line; do
  [[ -n "$job_line" ]] || continue
  job_id="$(echo "$job_line" | jq -r '.id')"
  job_name="$(echo "$job_line" | jq -r '.name')"
  conclusion="$(echo "$job_line" | jq -r '.conclusion')"
  runner_id="$(echo "$job_line" | jq -r '.runner_id')"
  step_count="$(echo "$job_line" | jq -r '.steps | length')"
  check_run_url="$(echo "$job_line" | jq -r '.check_run_url // empty')"
  created_job="$(echo "$job_line" | jq -r '.created_at // empty')"
  completed_job="$(echo "$job_line" | jq -r '.completed_at // empty')"

  if [[ "$conclusion" == "failure" ]]; then
    failed_steps="$(echo "$job_line" | jq -r \
      '[.steps[]? | select(.conclusion == "failure")] | length')"
    if [[ "$failed_steps" -gt 0 ]]; then
      real_failure_jobs+=("$job_name ($job_id)")
    else
      log "- Unclassified: $job_name ($job_id) (failure, zero failed steps)"
      unclassified_jobs+=("$job_name ($job_id)")
    fi
    continue
  fi

  if [[ "$conclusion" != "cancelled" ]]; then
    continue
  fi

  if job_has_not_acquired_annotation "$check_run_url"; then
    log "- Classified runner shortage (annotation): $job_name ($job_id)"
    runner_shortage_detected=true
    continue
  fi

  if runner_shortage__zero_step_shortage_candidate \
    "$runner_id" "$step_count" "$created_job" "$completed_job" \
    "$ZERO_STEP_MIN_WAIT_SECONDS"; then
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

if [[ ${#unclassified_jobs[@]} -gt 0 && "$runner_shortage_detected" != true ]]; then
  log ""
  log "**No rerun:** unclassified failure jobs present."
  exit 0
fi

if [[ "$runner_shortage_detected" != true ]]; then
  log ""
  log "**No rerun:** no runner-shortage cancellations detected."
  exit 0
fi

sleep_seconds=$((120 * RUN_ATTEMPT))
log ""
log "Backoff: waiting ${sleep_seconds}s (120s × run attempt $RUN_ATTEMPT) before rerun..."
sleep "$sleep_seconds"

log ""
log "**Rerunning failed jobs (single dispatch):** run $RUN_ID"
gh run rerun "$RUN_ID" --repo "$REPO" --failed

log ""
log "**Rerun dispatched.** Dependent publish should resume once all build jobs succeed."