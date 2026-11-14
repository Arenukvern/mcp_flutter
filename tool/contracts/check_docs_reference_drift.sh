#!/usr/bin/env bash
# Regenerates docs/reference from live server/CLI and fails if output drifts.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REF_DIR="$ROOT_DIR/docs/reference"

fail() {
  echo "check_docs_reference_drift: $*" >&2
  exit 1
}

ok() {
  echo "check_docs_reference_drift: $*"
}

command -v dart >/dev/null 2>&1 || fail "dart not found"
command -v flutter >/dev/null 2>&1 || fail "flutter not found"

[[ -d "$REF_DIR" ]] || fail "missing $REF_DIR — run 'make docs-reference' first"

BEFORE="$(mktemp -d)"
cleanup() {
  rm -rf "$BEFORE"
}
trap cleanup EXIT

cp -a "$REF_DIR/." "$BEFORE/"

cd "$ROOT_DIR/mcp_server_dart"
flutter pub get >/dev/null
cd "$ROOT_DIR"
dart run tool/docs/gen_reference.dart >/dev/null

if ! diff -qr "$BEFORE" "$REF_DIR" >/dev/null; then
  fail "docs/reference drifted. Run 'make docs-reference' and commit."
fi

ok "docs/reference in sync"