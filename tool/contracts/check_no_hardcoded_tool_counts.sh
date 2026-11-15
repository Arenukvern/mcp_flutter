#!/usr/bin/env bash
# Fails when prose hard-codes tool totals next to "tool(s)" outside generated reference.
set -euo pipefail

ROOT_DIR="${HARDCODED_TOOL_COUNT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$ROOT_DIR"

command -v rg >/dev/null 2>&1 || {
  echo "check_no_hardcoded_tool_counts: rg required" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || {
  echo "check_no_hardcoded_tool_counts: git required" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCANNER="${SCRIPT_DIR}/hardcoded_tool_count_scan.pl"
[[ -x "$SCANNER" ]] || chmod +x "$SCANNER"

filter_tracked() {
  while IFS= read -r f; do
    [[ "$f" =~ \.(md|mdx|txt|json|yaml|yml|dart)$ ]] || continue
    [[ "$f" == docs/reference/* ]] && continue
    [[ "$f" == decisions/* ]] && continue
    [[ "$f" == docs/decisions/* ]] && continue
    [[ "$f" == maintainers/* ]] && continue
    [[ "$f" == .verify-matrix/* ]] && continue
    [[ "$f" == */test/* ]] && continue
    [[ "$f" == .agents/* ]] && continue
    [[ "$f" == .cursor/* ]] && continue
    [[ "$f" == tool/contracts/fixtures/hardcoded_tool_counts/* ]] && continue
    [[ "$(basename "$f")" == CHANGELOG.md ]] && continue
    printf '%s\n' "$f"
  done | sort
}

mapfile -t files < <(
  if git -C "$ROOT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$ROOT_DIR" ls-files | filter_tracked
  else
    find . -type f \( \
      -name '*.md' -o -name '*.mdx' -o -name '*.txt' -o \
      -name '*.json' -o -name '*.yaml' -o -name '*.yml' -o -name '*.dart' \
    \) \
      ! -path './docs/reference/*' \
      ! -path './decisions/*' \
      ! -path './docs/decisions/*' \
      ! -path './maintainers/*' \
      ! -path './.verify-matrix/*' \
      ! -path '*/test/*' \
      ! -path './.agents/*' \
      ! -path './.cursor/*' \
      ! -path './tool/contracts/fixtures/hardcoded_tool_counts/*' \
      ! -name 'CHANGELOG.md' \
    | sed 's|^\./||' | filter_tracked
  fi
)

hits=""
scanner_failed=0
for f in "${files[@]}"; do
  [[ -f "$f" ]] || continue
  line_hits=""
  scanner_exit=0
  line_hits="$(perl "$SCANNER" "$f" 2>&1)" || scanner_exit=$?
  if ((scanner_exit != 0)); then
    echo "check_no_hardcoded_tool_counts: scanner failed on $f (exit $scanner_exit)" >&2
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