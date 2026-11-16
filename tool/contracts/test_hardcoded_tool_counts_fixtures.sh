#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/tool/contracts/fixtures/hardcoded_tool_counts"
CHECK="$ROOT_DIR/tool/contracts/check_no_hardcoded_tool_counts.sh"
SCANNER="$ROOT_DIR/tool/contracts/hardcoded_tool_count_scan.pl"

fail() {
  echo "test_hardcoded_tool_counts_fixtures: $*" >&2
  exit 1
}

must_fail_scan() {
  local file="$1"
  local hits
  hits="$(perl "$SCANNER" "$file")"
  if [[ -z "$hits" ]]; then
    fail "fixture $file should trip scanner but did not"
  fi
}

run_probe() {
  local fixture="$1"
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/docs/reference"
  printf '%s\n' 'ok prose' >"$tmp/docs/index.mdx"
  cp "$fixture" "$tmp/llms.txt"
  if HARDCODED_TOOL_COUNT_ROOT="$tmp" bash "$CHECK"; then
    rm -rf "$tmp"
    fail "expected failure for $(basename "$fixture")"
  fi
  rm -rf "$tmp"
}

for f in "$FIXTURE_DIR"/should_fail_*.txt; do
  [[ -f "$f" ]] || fail "no should_fail fixtures in $FIXTURE_DIR"
  must_fail_scan "$f"
  run_probe "$f"
done

bash "$CHECK"
echo "test_hardcoded_tool_counts_fixtures: OK"