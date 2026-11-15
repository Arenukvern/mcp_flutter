#!/usr/bin/env bash
# Fails when prose hard-codes tool totals next to "tool(s)" outside generated reference.
set -euo pipefail

ROOT_DIR="${HARDCODED_TOOL_COUNT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$ROOT_DIR"

command -v rg >/dev/null 2>&1 || {
  echo "check_no_hardcoded_tool_counts: rg required" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCANNER="${SCRIPT_DIR}/hardcoded_tool_count_scan.pl"
[[ -x "$SCANNER" ]] || chmod +x "$SCANNER"

mapfile -t files < <(
  find . \( \
    -path './docs/reference/*' -o \
    -path './decisions/*' -o \
    -path './docs/decisions/*' -o \
    -path './maintainers/*' -o \
    -path './.verify-matrix/*' -o \
    -path '*/test/*' -o \
    -path './.agents/*' -o \
    -path './.cursor/*' -o \
    -path './.git/*' -o \
    -path './**/node_modules/*' -o \
    -path './tool/contracts/fixtures/hardcoded_tool_counts/*' -o \
    -name 'CHANGELOG.md' \
  \) -prune -o -type f \( \
    -name '*.md' -o -name '*.mdx' -o -name '*.txt' -o \
    -name '*.json' -o -name '*.yaml' -o -name '*.yml' -o \
    -name '*.dart' \
  \) -print 2>/dev/null | sort
)

hits=""
scanner_failed=0
for f in "${files[@]}"; do
  line_hits=""
  if ! line_hits="$("$SCANNER" "$f")"; then
    echo "check_no_hardcoded_tool_counts: scanner failed on $f (exit $?)" >&2
    scanner_failed=1
    continue
  fi
  if [[ -n "$line_hits" ]]; then
    hits+="$line_hits"
  fi
done

if ((scanner_failed != 0)); then
  exit 1
fi

if [[ -n "$hits" ]]; then
  echo "Hard-coded tool counts found outside docs/reference (use generated reference or add tool-count-allow on the line):" >&2
  echo "$hits" >&2
  exit 1
fi

echo "check_no_hardcoded_tool_counts: OK"