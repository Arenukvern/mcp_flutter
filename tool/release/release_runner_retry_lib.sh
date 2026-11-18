# shellcheck shell=bash
# Pure helpers for release runner-retry decisions (sourced by scripts and contract tests).

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

release_runner_retry__attempt_cap_reached() {
  local run_attempt="$1"
  local max_attempts="$2"
  [[ "$run_attempt" -ge "$max_attempts" ]]
}

# Emits: ignore | real_failure | unclassified | shortage_annotation | shortage_zero
release_runner_retry__classify_job() {
  local job_line="$1"
  local not_acquired_re="$2"
  local min_wait="$3"
  local conclusion runner_id step_count created_job completed_job ann

  conclusion="$(echo "$job_line" | jq -r '.conclusion')"

  if [[ "$conclusion" == "failure" ]]; then
    local failed_steps
    failed_steps="$(echo "$job_line" | jq -r \
      '[.steps[]? | select(.conclusion == "failure")] | length')"
    if [[ "$failed_steps" -gt 0 ]]; then
      echo real_failure
      return 0
    fi
    echo unclassified
    return 0
  fi

  [[ "$conclusion" == "cancelled" ]] || {
    echo ignore
    return 0
  }

  runner_id="$(echo "$job_line" | jq -r '.runner_id')"
  step_count="$(echo "$job_line" | jq -r '.steps | length')"
  created_job="$(echo "$job_line" | jq -r '.created_at // empty')"
  completed_job="$(echo "$job_line" | jq -r '.completed_at // empty')"
  ann="$(echo "$job_line" | jq -c '.annotations // []')"

  if runner_shortage__annotation_matches "$ann" "$not_acquired_re"; then
    echo shortage_annotation
    return 0
  fi

  if runner_shortage__zero_step_shortage_candidate \
    "$runner_id" "$step_count" "$created_job" "$completed_job" "$min_wait"; then
    echo shortage_zero
    return 0
  fi

  echo real_failure
}

release_runner_retry__plan_emit() {
  local decision="$1"
  local sleep_seconds="$2"
  local dispatch="$3"
  jq -n \
    --arg decision "$decision" \
    --argjson sleep "$sleep_seconds" \
    --argjson dispatch "$dispatch" \
    '{ok: true, decision: $decision, sleep_seconds: $sleep, dispatch_rerun: $dispatch}'
}

release_runner_retry__plan_error() {
  jq -n --arg e "$1" '{ok: false, error: $e}'
}

# Classify using jobs that already carry `annotations` arrays (production fetches via gh).
release_runner_retry__plan_from_state_file() {
  local state_file="$1"
  local not_acquired_re
  not_acquired_re="$(jq -r '.not_acquired_re // empty' "$state_file")"
  [[ -n "$not_acquired_re" ]] || not_acquired_re="$NOT_ACQUIRED_RE_DEFAULT"
  local min_wait
  min_wait="$(jq -r '.zero_step_min_wait_seconds // empty' "$state_file")"
  [[ -n "$min_wait" ]] || min_wait="$ZERO_STEP_MIN_WAIT_SECONDS_DEFAULT"

  local run_attempt max_attempts
  run_attempt="$(jq -r '.run_attempt' "$state_file")"
  max_attempts="$(jq -r '.max_attempts' "$state_file")"

  if release_runner_retry__attempt_cap_reached "$run_attempt" "$max_attempts"; then
    release_runner_retry__plan_emit cap 0 false
    return 0
  fi

  local run_event
  run_event="$(jq -r '.workflow_event // "push"' "$state_file")"
  if [[ "$run_event" != "push" ]]; then
    release_runner_retry__plan_emit skip_event 0 false
    return 0
  fi

  local head_branch created_at run_id workflow_runs_json
  head_branch="$(jq -r '.head_branch // empty' "$state_file")"
  created_at="$(jq -r '.created_at // empty' "$state_file")"
  run_id="$(jq -r '.run_id' "$state_file")"
  workflow_runs_json="$(jq -c '.workflow_runs // {workflow_runs:[]}' "$state_file")"

  if [[ -n "$head_branch" && -n "$created_at" ]] && \
    release_runner_retry__is_superseded \
      "$workflow_runs_json" "$head_branch" "$created_at" "$run_id"; then
    release_runner_retry__plan_emit superseded 0 false
    return 0
  fi

  local runner_shortage_detected=false
  local real_failure_count=0
  local unclassified_count=0

  while IFS= read -r job_line; do
    [[ -n "$job_line" ]] || continue
    local conclusion
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

    [[ "$conclusion" == "cancelled" ]] || continue

    local runner_id step_count created_job completed_job ann
    runner_id="$(echo "$job_line" | jq -r '.runner_id')"
    step_count="$(echo "$job_line" | jq -r '.steps | length')"
    created_job="$(echo "$job_line" | jq -r '.created_at // empty')"
    completed_job="$(echo "$job_line" | jq -r '.completed_at // empty')"
    ann="$(echo "$job_line" | jq -c '.annotations // []')"

    if runner_shortage__annotation_matches "$ann" "$not_acquired_re"; then
      runner_shortage_detected=true
      continue
    fi

    if runner_shortage__zero_step_shortage_candidate \
      "$runner_id" "$step_count" "$created_job" "$completed_job" "$min_wait"; then
      runner_shortage_detected=true
      continue
    fi

    real_failure_count=$((real_failure_count + 1))
  done < <(jq -c '.jobs[]?' "$state_file")

  if [[ "$real_failure_count" -gt 0 ]]; then
    release_runner_retry__plan_emit real_failure 0 false
    return 0
  fi
  if [[ "$unclassified_count" -gt 0 && "$runner_shortage_detected" != true ]]; then
    release_runner_retry__plan_emit unclassified 0 false
    return 0
  fi
  if [[ "$runner_shortage_detected" != true ]]; then
    release_runner_retry__plan_emit no_shortage 0 false
    return 0
  fi

  local sleep_seconds=$((120 * run_attempt))
  release_runner_retry__plan_emit rerun "$sleep_seconds" true
}

release_runner_retry__decide() {
  local state_tmp
  state_tmp="$(mktemp)"
  jq -n \
    --argjson run_attempt "$1" \
    --argjson max_attempts "$2" \
    --argjson workflow_runs "$3" \
    --arg hb "$4" \
    --arg ts "$5" \
    --argjson run_id "$6" \
    --argjson jobs "$7" \
    --arg re "${8:-not acquired by (a )?Runner}" \
    --argjson min_wait "${9:-600}" \
    '{
      run_attempt: $run_attempt,
      max_attempts: $max_attempts,
      workflow_runs: $workflow_runs,
      head_branch: $hb,
      created_at: $ts,
      run_id: $run_id,
      workflow_event: "push",
      jobs: ($jobs.jobs // []),
      not_acquired_re: $re,
      zero_step_min_wait_seconds: $min_wait
    }' >"$state_tmp"
  release_runner_retry__plan_from_state_file "$state_tmp" | jq -r '.decision // empty'
  rm -f "$state_tmp"
}