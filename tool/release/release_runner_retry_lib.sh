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
  jq -cn \
    --arg decision "$decision" \
    --argjson sleep "$sleep_seconds" \
    --argjson dispatch "$dispatch" \
    '{ok: true, decision: $decision, sleep_seconds: $sleep, dispatch_rerun: $dispatch}'
}

release_runner_retry__plan_error() {
  jq -cn --arg e "$1" '{ok: false, error: $e}'
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
    local job_class
    job_class="$(release_runner_retry__classify_job \
      "$job_line" "$not_acquired_re" "$min_wait")"
    case "$job_class" in
      real_failure) real_failure_count=$((real_failure_count + 1)) ;;
      unclassified) unclassified_count=$((unclassified_count + 1)) ;;
      shortage_annotation | shortage_zero) runner_shortage_detected=true ;;
      ignore) ;;
    esac
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
  jq -cn \
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

release_runner_retry__argv_to_line() {
  local arg first=true
  for arg in "$@"; do
    if [[ "$first" == true ]]; then
      printf '%q' "$arg"
      first=false
    else
      printf ' %q' "$arg"
    fi
  done
  printf '\n'
}

release_runner_retry__cb_print_argv() {
  # shellcheck disable=SC2034
  local -n _cmd=$1
  release_runner_retry__argv_to_line "${_cmd[@]}"
}

release_runner_retry__cb_run_argv() {
  # shellcheck disable=SC2034
  local -n _cmd=$1
  "${_cmd[@]}"
}

release_runner_retry__cb_run_argv_quiet() {
  # shellcheck disable=SC2034
  local -n _cmd=$1
  "${_cmd[@]}" 2>/dev/null
}

release_runner_retry__invoke_annotation_fetch_argv() {
  local check_run_url="$1"
  local callback="$2"
  [[ -n "$check_run_url" && "$check_run_url" != "null" ]] || return 0
  local -a argv=(gh api "${check_run_url%/}/annotations" --paginate)
  "$callback" argv || return 1
}

release_runner_retry__gh_api_annotations_json() {
  local check_run_url="$1"
  [[ -n "$check_run_url" && "$check_run_url" != "null" ]] || {
    echo '[]'
    return 0
  }
  release_runner_retry__invoke_annotation_fetch_argv \
    "$check_run_url" release_runner_retry__cb_run_argv_quiet || echo '[]'
}

release_runner_retry__invoke_rerun_argv() {
  local run_id="$1"
  local repo="$2"
  local callback="$3"
  # shellcheck disable=SC2034 # argv is passed by nameref to the rerun callback
  local -a argv=(gh run rerun "$run_id" --repo "$repo" --failed)
  "$callback" argv || return 1
}

release_runner_retry__invoke_each_plan_exec_argv() {
  local state_file="$1"
  local plan="$2"
  local callback="$3"
  local check_run_url
  while IFS= read -r check_run_url; do
    [[ -n "$check_run_url" ]] || continue
    release_runner_retry__invoke_annotation_fetch_argv \
      "$check_run_url" "$callback" || return 1
  done < <(jq -r '.jobs[]? | .check_run_url // empty | select(length > 0)' "$state_file")
  if [[ "$(echo "$plan" | jq -r '.dispatch_rerun')" == "true" ]]; then
    release_runner_retry__invoke_rerun_argv \
      "$(jq -r '.run_id' "$state_file")" \
      "$(jq -r '.repo // "__owner/repo__"' "$state_file")" \
      "$callback" || return 1
  fi
}

release_runner_retry__emit_plan_dry_run_trailer() {
  local state_file="$1"
  local plan="$2"
  local decision
  decision="$(echo "$plan" | jq -r '.decision')"
  echo '---COMMANDS---'
  release_runner_retry__invoke_each_plan_exec_argv \
    "$state_file" "$plan" release_runner_retry__cb_print_argv
  if [[ "$(echo "$plan" | jq -r '.dispatch_rerun')" != "true" ]]; then
    printf 'SKIP: decision=%s\n' "$decision"
  fi
}
