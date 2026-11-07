#!/usr/bin/env bash
# Exercises generator idempotence and the post-regen diff pattern used in CI.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GENERATED="$ROOT_DIR/mcp_server_dart/lib/src/skill_assets.g.dart"

fail() { echo "test_skill_asset_sync_idempotence: $*" >&2; exit 1; }
ok() { echo "test_skill_asset_sync_idempotence: $*"; }

command -v dart >/dev/null 2>&1 || fail "dart not found"
command -v flutter >/dev/null 2>&1 || fail "flutter not found"

BEFORE="$(mktemp)"
STALE="$(mktemp)"
AFTER_FIRST="$(mktemp)"
cleanup() { rm -f "$BEFORE" "$STALE" "$AFTER_FIRST"; }
trap cleanup EXIT

cp "$GENERATED" "$BEFORE"

cd "$ROOT_DIR/mcp_server_dart" && flutter pub get >/dev/null
cd "$ROOT_DIR"

# Simulate release-please drift: embedded manifest version lags plugin/.
if ! grep -q '"version":' "$GENERATED"; then
  fail "expected version field in bundle"
fi
sed -i '0,/"version": "/s/"version": "[^"]*"/"version": "0.0.0-stale"/' "$GENERATED"
cp "$GENERATED" "$STALE"

if git diff --exit-code -- "$GENERATED" >/dev/null 2>&1; then
  fail "expected unstaged drift after synthetic stale version"
fi

dart run mcp_server_dart/tool/build_skill_assets.dart >/dev/null
cp "$GENERATED" "$AFTER_FIRST"

if cmp -s "$STALE" "$AFTER_FIRST"; then
  fail "first regen must change stale bundle"
fi
if ! cmp -s "$BEFORE" "$AFTER_FIRST"; then
  fail "first regen must restore bundle matching committed plugin embed"
fi

dart run mcp_server_dart/tool/build_skill_assets.dart >/dev/null
if ! cmp -s "$AFTER_FIRST" "$GENERATED"; then
  fail "second generator run must not change skill_assets.g.dart"
fi

git checkout -- "$GENERATED"

ok "stale→regen→idempotent path OK"
