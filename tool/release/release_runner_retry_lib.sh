# shellcheck shell=bash
# Pure helpers for release runner-retry decisions (sourced by scripts and contract tests).

# Count newer Release workflow runs on the same branch (supersedes this run).
release_runner_retry__newer_run_count() {
  local workflow_runs_json="$1"
  local head_branch="$2"
  local created_at="$3"
  local run_id="$4"
  echo "$workflow_runs_json" | jq --arg hb "$head_branch" \
    --arg ts "$created_at" --argjson rid "$run_id" \
    '[.workflow_runs[]? | select(.head_branch == $hb and .created_at > $ts and .id != $rid)] | length'
}

release_runner_retry__is_superseded() {
  local workflow_runs_json="$1"
  local head_branch="$2"
  local created_at="$3"
  local run_id="$4"
  [[ -n "$head_branch" && -n "$created_at" ]] || return 1
  local newer
  newer="$(release_runner_retry__newer_run_count \
    "$workflow_runs_json" "$head_branch" "$created_at" "$run_id")"
  [[ "$newer" -gt 0 ]]
}

# Echo one of: cap | superseded | real_failure | unclassified | no_shortage | rerun
release_runner_retry__decide() {
  local run_attempt="$1"
  local max_attempts="$2"
  local workflow_runs_json="$3"
  local head_branch="$4"
  local created_at="$5"
  local run_id="$6"
  local jobs_json="$7"
  local not_acquired_re="${8:-$NOT_ACQUIRED_RE_DEFAULT}"
  local zero_step_min_wait="${9:-$ZERO_STEP_MIN_WAIT_SECONDS_DEFAULT}"

  if [[ "$run_attempt" -ge "$max_attempts" ]]; then
    echo cap
    return 0
  fi

  if release_runner_retry__is_superseded \
    "$workflow_runs_json" "$head_branch" "$created_at" "$run_id"; then
    echo superseded
    return 0
  fi

  local runner_shortage_detected=false
  local real_failure_count=0
  local unclassified_count=0

  while IFS= read -r job_line; do
    [[ -n "$job_line" ]] || continue
    local conclusion runner_id step_count created_job completed_job
    conclusion="$(echo "$job_line" | jq -r '.conclusion')"

    if [[ "$conclusion" == "failure" ]]; then
      local failed_steps
      failed_steps="$(echo "$job_line" | jq -r \
        '[.steps[]? | select(.conclusion == "failure")] | length')"
      if [[ "$failed_steps" -gt 0 ]]; then
        real_failure_count=$((real_failure_count + 1))
      else
        unclassified_count=$((unclassified_count + 1))
      fi
      continue
    fi

    if [[ "$conclusion" != "cancelled" ]]; then
      continue
    fi

    runner_id="$(echo "$job_line" | jq -r '.runner_id')"
    step_count="$(echo "$job_line" | jq -r '.steps | length')"
    created_job="$(echo "$job_line" | jq -r '.created_at // empty')"
    completed_job="$(echo "$job_line" | jq -r '.completed_at // empty')"

    if echo "$job_line" | jq -e '._contract_annotations' >/dev/null 2>&1; then
      local ann
      ann="$(echo "$job_line" | jq -c '._contract_annotations')"
      if runner_shortage__annotation_matches "$ann" "$not_acquired_re"; then
        runner_shortage_detected=true
        continue
      fi
    fi

    if runner_shortage__zero_step_shortage_candidate \
      "$runner_id" "$step_count" "$created_job" "$completed_job" \
      "$zero_step_min_wait"; then
      runner_shortage_detected=true
      continue
    fi

    real_failure_count=$((real_failure_count + 1))
  done < <(echo "$jobs_json" | jq -c '.jobs[]?')

  if [[ "$real_failure_count" -gt 0 ]]; then
    echo real_failure
    return 0
  fi
  if [[ "$unclassified_count" -gt 0 && "$runner_shortage_detected" != true ]]; then
    echo unclassified
    return 0
  fi
  if [[ "$runner_shortage_detected" != true ]]; then
    echo no_shortage
    return 0
  fi
  echo rerun
}