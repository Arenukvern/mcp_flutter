#!/usr/bin/env bash
# Decide whether to re-run GitHub Actions jobs cancelled by hosted-runner shortages.
set -euo pipefail

RUN_ID="${1:-}"
REPO="${2:-}"
RUN_ATTEMPT="${3:-1}"
MAX_ATTEMPTS="${4:-3}"

SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stdout}"
NOT_ACQUIRED_RE='not acquired by a Runner of type hosted'

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
log "- Run attempt: $RUN_ATTEMPT / $MAX_ATTEMPTS"

if [[ "$RUN_ATTEMPT" -gt "$MAX_ATTEMPTS" ]]; then
  log ""
  log "**No rerun:** attempt cap reached."
  exit 0
fi

sleep_seconds=$((120 * RUN_ATTEMPT))
log ""
log "Backing off ${sleep_seconds}s before inspecting jobs..."
sleep "$sleep_seconds"

run_json="$(gh api "repos/$REPO/actions/runs/$RUN_ID")"
head_sha="$(echo "$run_json" | jq -r '.head_sha')"
jobs_json="$(gh api "repos/$REPO/actions/runs/$RUN_ID/jobs" --paginate)"
check_runs_json="$(gh api "repos/$REPO/commits/$head_sha/check-runs" --paginate)"

job_has_not_acquired_annotation() {
  local job_name="$1"
  local check_run_id
  check_run_id="$(echo "$check_runs_json" | jq -r \
    --arg name "$job_name" \
    '[.check_runs[]? | select(.name == $name) | .id] | first // empty')"
  [[ -n "$check_run_id" ]] || return 1
  local annotations
  annotations="$(gh api "repos/$REPO/check-runs/$check_run_id/annotations" --paginate 2>/dev/null || true)"
  echo "$annotations" | jq -e --arg re "$NOT_ACQUIRED_RE" \
    '[.[]? | select(.message | test($re; "i"))] | length > 0' >/dev/null
}

runner_shortage_jobs=()
real_failure_jobs=()

while IFS=$'\t' read -r job_id job_name conclusion runner_id step_count; do
  [[ -n "$job_id" ]] || continue

  if [[ "$conclusion" == "failure" ]]; then
    failed_steps="$(echo "$jobs_json" | jq -r \
      --arg id "$job_id" \
      '[.jobs[] | select(.id == ($id | tonumber)) | .steps[]? | select(.conclusion == "failure")] | length')"
    if [[ "$failed_steps" -gt 0 ]]; then
      real_failure_jobs+=("$job_name ($job_id)")
      continue
    fi
  fi

  if [[ "$conclusion" == "cancelled" ]]; then
  if { [[ "$runner_id" == "0" ]] && [[ "$step_count" == "0" ]]; } || \
    job_has_not_acquired_annotation "$job_name"; then
      runner_shortage_jobs+=("$job_id:$job_name")
    else
      real_failure_jobs+=("$job_name ($job_id)")
    fi
    continue
  fi
done < <(echo "$jobs_json" | jq -r '.jobs[] | "\(.id)\t\(.name)\t\(.conclusion)\t\(.runner_id)\t\(.steps | length)"')

if [[ ${#real_failure_jobs[@]} -gt 0 ]]; then
  log ""
  log "**No rerun:** real build/test failures detected:"
  for name in "${real_failure_jobs[@]}"; do
    log "- $name"
  done
  exit 0
fi

if [[ ${#runner_shortage_jobs[@]} -eq 0 ]]; then
  log ""
  log "**No rerun:** no runner-shortage cancellations detected."
  exit 0
fi

log ""
log "**Rerunning runner-shortage jobs:**"
for entry in "${runner_shortage_jobs[@]}"; do
  job_id="${entry%%:*}"
  job_name="${entry#*:}"
  log "- $job_name ($job_id)"
  gh run rerun "$RUN_ID" --repo "$REPO" --job "$job_id"
done

log ""
log "**Rerun dispatched.** Dependent publish should resume once all build jobs succeed."