#!/usr/bin/env bash
# Regenerates skill_assets.g.dart from plugin/ and fails if the committed file drifts.
# Wired into `make check-contracts` (same check as .github/workflows/skill_assets_drift.yml).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GENERATED="$ROOT_DIR/mcp_server_dart/lib/src/skill_assets.g.dart"

fail() {
  echo "check_skill_assets_drift: $*" >&2
  exit 1
}

ok() {
  echo "check_skill_assets_drift: $*"
}

command -v dart >/dev/null 2>&1 || fail "dart not found; install Dart SDK to run this check"

BEFORE="$(mktemp)"
cleanup() {
  rm -f "$BEFORE"
}
trap cleanup EXIT

cp "$GENERATED" "$BEFORE"

cd "$ROOT_DIR/mcp_server_dart"
dart pub get >/dev/null
cd "$ROOT_DIR"
dart run mcp_server_dart/tool/build_skill_assets.dart >/dev/null

if ! cmp -s "$BEFORE" "$GENERATED"; then
  fail "skill_assets.g.dart is out of sync with plugin/. Run 'make sync-skills' and commit the result."
fi

ok "skill_assets.g.dart in sync with plugin/"
