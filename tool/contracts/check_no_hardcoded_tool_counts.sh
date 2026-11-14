#!/usr/bin/env bash
# Fails when prose hard-codes MCP tool totals outside generated reference.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

PATTERN='([0-9]{2,3}[[:space:]]+(built-in[[:space:]]+)?fmt_\*|[0-9]{2,3}[[:space:]]+MCP[[:space:]]+tools|exposes[[:space:]]+[0-9]{2,3}[[:space:]]+MCP|The default toolkit surface exposes[[:space:]]+[0-9]+)'

if command -v rg >/dev/null 2>&1; then
  hits="$(rg -n -i --pcre2 "$PATTERN" \
    --glob '*.md' --glob '*.mdx' \
    --glob '!docs/reference/**' \
    --glob '!**/CHANGELOG.md' \
    --glob '!tool/contracts/**' \
    --glob '!**/.agents/**' \
    --glob '!**/skill_assets.g.dart' \
    . 2>/dev/null || true)"
else
  hits="$(grep -RIn -E '[0-9]{2,3}[[:space:]]+MCP tools|exposes [0-9]{2,3}' \
    --include='*.md' --include='*.mdx' . 2>/dev/null | grep -v docs/reference || true)"
fi

if [[ -n "$hits" ]]; then
  echo "Hard-coded tool counts found outside docs/reference (use generated reference instead):" >&2
  echo "$hits" >&2
  exit 1
fi

echo "check_no_hardcoded_tool_counts: OK"