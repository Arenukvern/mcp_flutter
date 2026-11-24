#!/usr/bin/env bash
# Validates harness scenario report schema via package unit tests.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PATH="${ROOT_DIR}/.fvm/flutter_sdk/bin:${PATH:-}"
if ! command -v dart >/dev/null 2>&1; then
  if command -v flutter >/dev/null 2>&1; then
    export PATH="$(dirname "$(command -v flutter)"):${PATH}"
  fi
fi

command -v dart >/dev/null || {
  echo "test_harness_scenario_report_schema: dart not on PATH" >&2
  exit 1
}

cd "$ROOT_DIR/packages/harness"
dart test test/scenario_report_test.dart
echo "test_harness_scenario_report_schema: OK"