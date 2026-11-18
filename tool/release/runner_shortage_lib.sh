# shellcheck shell=bash
# Shared helpers for release runner-shortage classification (sourced by scripts/tests).

NOT_ACQUIRED_RE_DEFAULT='not acquired by (a )?Runner'
ZERO_STEP_MIN_WAIT_SECONDS_DEFAULT=600

runner_shortage__job_waited_at_least_seconds() {
  local created_at="$1"
  local completed_at="$2"
  local min_seconds="${3:-600}"
  [[ -n "$created_at" && -n "$completed_at" ]] || return 1
  local created_epoch completed_epoch
  created_epoch="$(date -d "$created_at" +%s 2>/dev/null || echo 0)"
  completed_epoch="$(date -d "$completed_at" +%s 2>/dev/null || echo 0)"
  [[ "$created_epoch" -gt 0 && "$completed_epoch" -ge "$created_epoch" ]] || return 1
  [[ $((completed_epoch - created_epoch)) -ge "$min_seconds" ]]
}

runner_shortage__zero_step_shortage_candidate() {
  local runner_id="$1"
  local step_count="$2"
  local created_at="$3"
  local completed_at="$4"
  local min_seconds="${5:-600}"
  [[ "$runner_id" == "0" && "$step_count" == "0" ]] || return 1
  runner_shortage__job_waited_at_least_seconds \
    "$created_at" "$completed_at" "$min_seconds"
}

runner_shortage__annotation_matches() {
  local annotations_json="$1"
  local pattern="${2:-$NOT_ACQUIRED_RE_DEFAULT}"
  echo "$annotations_json" | jq -e --arg re "$pattern" \
    '[.[]? | select(.message | test($re; "i"))] | length > 0' >/dev/null
}
