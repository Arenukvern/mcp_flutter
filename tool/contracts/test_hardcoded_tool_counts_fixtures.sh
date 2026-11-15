#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/tool/contracts/fixtures/hardcoded_tool_counts"
CHECK="$ROOT_DIR/tool/contracts/check_no_hardcoded_tool_counts.sh"

fail() {
  echo "test_hardcoded_tool_counts_fixtures: $*" >&2
  exit 1
}

must_match() {
  local file="$1"
  if ! rg -q -P '(?i)(?:\*\*)?(?:40|3[0-9]|thirty(?:[-\s](?:one|two|three|four|five|six|seven|eight|nine))?|thirty|forty)(?:\*\*)?[\s\*_]{0,16}(?:fmt_\*[\s\*_]{0,8})?(?:MCP[\s\*_]{0,8})?tools\b' "$file"; then
    fail "fixture $file should match violation pattern but did not"
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
  must_match "$f"
  run_probe "$f"
done

bash "$CHECK"
echo "test_hardcoded_tool_counts_fixtures: OK"