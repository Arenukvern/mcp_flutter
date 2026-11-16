#!/usr/bin/env bash
# Root decisions/ is canonical; docs/decisions/ must match for docs.page.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CANON="$ROOT_DIR/decisions"
DOCS="$ROOT_DIR/docs/decisions"

fail() {
  echo "check_decisions_docs_sync: $*" >&2
  exit 1
}

[[ -d "$CANON" && -d "$DOCS" ]] || fail "missing decisions directories"

if ! diff -qr "$CANON" "$DOCS" >/dev/null; then
  fail "docs/decisions out of sync with decisions/. Run: rsync -a --delete decisions/ docs/decisions/"
fi

echo "check_decisions_docs_sync: OK"