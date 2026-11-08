#!/usr/bin/env bash
# Harness-owned fake `adb` for deterministic logcat lifecycle tests.
# Env: ADB_FAKE_MODE=stream|ignore_term
set -euo pipefail
mode="${ADB_FAKE_MODE:-stream}"
if [[ "$1" == "-s" && "$3" == "logcat" && "$4" == "-c" ]]; then
  exit 0
fi
if [[ "$1" == "-s" && "$3" == "logcat" ]]; then
  echo "fake_adb logcat pid=$$ mode=$mode" >&2
  if [[ "$mode" == "ignore_term" ]]; then
    while true; do sleep 0.02; done
  fi
  trap 'exit 0' TERM
  while true; do sleep 0.02; done
fi
echo "fake_adb: unhandled argv: $*" >&2
exit 1
