#!/usr/bin/env bash
# Targeted Claude Code plugin manifest checks (not full upstream schema).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() { echo "check_claude_plugin_manifest: $*" >&2; exit 1; }
ok() { echo "check_claude_plugin_manifest: $*"; }

command -v dart >/dev/null 2>&1 || fail "dart not found"
command -v flutter >/dev/null 2>&1 || fail "flutter not found"

cd "$ROOT_DIR/mcp_server_dart"
flutter pub get >/dev/null
cd "$ROOT_DIR"
dart run mcp_server_dart/tool/validate_claude_plugin_manifest.dart "$ROOT_DIR"

ok "Claude plugin manifest OK"
