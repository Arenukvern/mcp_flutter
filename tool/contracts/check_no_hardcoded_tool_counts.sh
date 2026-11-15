#!/usr/bin/env bash
# Fails when prose hard-codes MCP tool totals (30–40) outside generated reference.
set -euo pipefail

ROOT_DIR="${HARDCODED_TOOL_COUNT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$ROOT_DIR"

command -v rg >/dev/null 2>&1 || {
  echo "check_no_hardcoded_tool_counts: rg required" >&2
  exit 1
}

# Digits or spelled 30–40, optional markdown emphasis, then "tools" (fmt_ allowed between).
PATTERN='(?i)(?:\*\*)?(?:40|3[0-9]|thirty(?:[-\s](?:one|two|three|four|five|six|seven|eight|nine))?|thirty|forty)(?:\*\*)?[\s\*_]{0,16}(?:fmt_\*[\s\*_]{0,8})?(?:MCP[\s\*_]{0,8})?tools\b'

hits="$(rg -n -P "$PATTERN" \
  --glob '*.md' \
  --glob '*.mdx' \
  --glob '*.txt' \
  --glob '!docs/reference/**' \
  --glob '!**/CHANGELOG.md' \
  --glob '!tool/contracts/**' \
  --glob '!**/.agents/**' \
  --glob '!**/skill_assets.g.dart' \
  . || true)"
rg_status=$?
if ((rg_status > 1)); then
  echo "check_no_hardcoded_tool_counts: rg failed (exit $rg_status)" >&2
  exit 1
fi

if [[ -n "$hits" ]]; then
  echo "Hard-coded tool counts found outside docs/reference (use generated reference instead):" >&2
  echo "$hits" >&2
  exit 1
fi

echo "check_no_hardcoded_tool_counts: OK"