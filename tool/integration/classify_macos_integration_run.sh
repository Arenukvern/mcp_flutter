#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  classify_macos_integration_run.sh [--log <path>] -- <command...>
  classify_macos_integration_run.sh --from-log <path> [--command-exit-code <n>]

Examples:
  classify_macos_integration_run.sh -- \
    flutter test integration_test/live_edit_test.dart -d macos --timeout 2m

  classify_macos_integration_run.sh --log /tmp/macos_gate.log -- \
    flutter test integration_test -d macos --timeout 3m

  classify_macos_integration_run.sh --from-log /tmp/macos_gate.log \
    --command-exit-code 0
EOF
}

log_file=""
from_log=0
command_exit_code=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log)
      if [[ $# -lt 2 ]]; then
        usage >&2
        exit 2
      fi
      log_file="$2"
      shift 2
      ;;
    --from-log)
      if [[ $# -lt 2 ]]; then
        usage >&2
        exit 2
      fi
      from_log=1
      log_file="$2"
      shift 2
      ;;
    --command-exit-code)
      if [[ $# -lt 2 ]]; then
        usage >&2
        exit 2
      fi
      command_exit_code="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

if [[ -z "$log_file" ]]; then
  log_file="/tmp/macos_integration_gate_$(date +%Y%m%d_%H%M%S).log"
fi

known_non_fatal_warning='Failed to foreground app; open returned 1'
semantic_error_regex='did not complete \[E\]|\[E\]|Some tests failed\.|One or more uncaught errors occurred shutting down|Bad state: Cannot close sink while adding stream|Unhandled exception'

if [[ $from_log -eq 1 ]]; then
  if [[ ! -f "$log_file" ]]; then
    echo "Log file not found: $log_file" >&2
    exit 2
  fi
  if [[ -z "$command_exit_code" ]]; then
    command_exit_code=0
  fi
  if [[ ! "$command_exit_code" =~ ^-?[0-9]+$ ]]; then
    echo "--command-exit-code must be an integer" >&2
    exit 2
  fi
  echo "Classifying existing log:"
  echo "  log_file=$log_file"
  echo "  command_exit_code=$command_exit_code"
else
  if [[ $# -eq 0 ]]; then
    usage >&2
    exit 2
  fi
  echo "Running command:"
  printf '  %q' "$@"
  printf '\n'
  echo "Log file: $log_file"

  set +e
  "$@" 2>&1 | tee "$log_file"
  command_exit_code=${PIPESTATUS[0]}
  set -e
fi

has_known_warning=0
if grep -Fq "$known_non_fatal_warning" "$log_file"; then
  has_known_warning=1
fi

semantic_hits="$(grep -nE "$semantic_error_regex" "$log_file" || true)"

has_pass_summary=0
if grep -Fq 'All tests passed!' "$log_file"; then
  has_pass_summary=1
fi

has_skipped_summary=0
if grep -Fq 'All tests skipped.' "$log_file"; then
  has_skipped_summary=1
fi

verdict=""
exit_code=1

if [[ $command_exit_code -ne 0 ]]; then
  verdict="FAIL_EXIT_CODE"
  exit_code=1
elif [[ -n "$semantic_hits" ]]; then
  verdict="FAIL_SEMANTIC_ERRORS_IN_LOG"
  exit_code=1
elif [[ $has_pass_summary -eq 1 || $has_skipped_summary -eq 1 ]]; then
  if [[ $has_known_warning -eq 1 ]]; then
    verdict="PASS_WITH_KNOWN_WARNING"
  else
    verdict="PASS_CLEAN"
  fi
  exit_code=0
else
  verdict="BLOCKED_NO_TERMINAL_SUMMARY"
  exit_code=2
fi

echo
echo "Classification:"
echo "  command_exit_code=$command_exit_code"
echo "  known_non_fatal_warning_detected=$has_known_warning"
echo "  pass_summary_detected=$has_pass_summary"
echo "  skipped_summary_detected=$has_skipped_summary"
echo "  verdict=$verdict"

if [[ -n "$semantic_hits" ]]; then
  echo "  semantic_error_matches:"
  while IFS= read -r line; do
    echo "    $line"
  done <<<"$semantic_hits"
fi

exit "$exit_code"
