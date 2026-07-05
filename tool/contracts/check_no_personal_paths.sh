#!/usr/bin/env bash
# Fail if committed files contain maintainer-local absolute paths.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

matches="$(
  pattern="$(printf '/%s/anton' 'Users')"
  rg -n --hidden \
    --glob '!**/.git/**' \
    --glob '!**/.dart_tool/**' \
    --glob '!**/build/**' \
    --glob '!**/node_modules/**' \
    --glob '!**/.plugin_symlinks/**' \
    "$pattern" "$ROOT" 2>/dev/null || true
)"

if [[ -n "$matches" ]]; then
  echo "FAIL: maintainer-local absolute paths are not allowed in committed files." >&2
  echo "$matches" >&2
  exit 1
fi

echo "OK: no maintainer-local absolute paths"
