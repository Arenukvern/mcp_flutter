#!/usr/bin/env bash
# Verifies repo VERSION matches every Flutter MCP Toolkit package and plugin
# release touchpoint.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION_FILE="$ROOT_DIR/VERSION"
RUNTIME_VERSION_FILE="$ROOT_DIR/packages/core/lib/src/runtime_version.dart"
FMT_CAPABILITY_FILE="$ROOT_DIR/packages/server_capability_core/lib/src/fmt_capability.dart"

fail() {
  echo "check_version_sync: $*" >&2
  exit 1
}

ok() {
  echo "check_version_sync: $*"
}

[[ -f "$VERSION_FILE" ]] || fail "missing $VERSION_FILE"
repo_version="$(tr -d '[:space:]' < "$VERSION_FILE")"
[[ -n "$repo_version" ]] || fail "VERSION file is empty"

runtime_version="$(
  sed -nE "s/^const kFlutterMcpVersion = '([^']+)';.*$/\1/p" "$RUNTIME_VERSION_FILE" | head -1
)"
[[ "$runtime_version" == "$repo_version" ]] ||
  fail "kFlutterMcpVersion ($runtime_version) != VERSION ($repo_version)"

for pubspec in \
  "$ROOT_DIR/mcp_server_dart/pubspec.yaml" \
  "$ROOT_DIR/mcp_toolkit/pubspec.yaml" \
  "$ROOT_DIR/packages/core/pubspec.yaml" \
  "$ROOT_DIR/packages/server_capability_kernel/pubspec.yaml" \
  "$ROOT_DIR/packages/server_capability_core/pubspec.yaml"; do
  pubspec_version="$(
    sed -nE 's/^version:[[:space:]]*([^[:space:]#]+).*/\1/p' "$pubspec" | head -1
  )"
  [[ "$pubspec_version" == "$repo_version" ]] ||
    fail "${pubspec#$ROOT_DIR/} version ($pubspec_version) != VERSION ($repo_version)"
done

fmt_capability_version="$(
  sed -nE "s/.*version => '([^']+)';.*$/\1/p" "$FMT_CAPABILITY_FILE" | head -1
)"
[[ "$fmt_capability_version" == "$repo_version" ]] ||
  fail "FmtCapability.version ($fmt_capability_version) != VERSION ($repo_version)"

for manifest in \
  "$ROOT_DIR/plugin/.cursor-plugin/plugin.json" \
  "$ROOT_DIR/plugin/.codex-plugin/plugin.json" \
  "$ROOT_DIR/plugin/.claude-plugin/plugin.json"; do
  manifest_version="$(
    sed -nE 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$manifest" | head -1
  )"
  [[ "$manifest_version" == "$repo_version" ]] ||
    fail "$(basename "$(dirname "$manifest")") version ($manifest_version) != VERSION ($repo_version)"
done

marketplace_version="$(
  sed -nE 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$ROOT_DIR/.claude-plugin/marketplace.json" | head -1
)"
[[ "$marketplace_version" == "$repo_version" ]] ||
  fail ".claude-plugin/marketplace.json plugins[0].version ($marketplace_version) != VERSION ($repo_version)"

for dep in \
  flutter_mcp_toolkit_core \
  flutter_mcp_toolkit_capability_kernel \
  flutter_mcp_toolkit_capability_core; do
  if ! grep -R "^[[:space:]]*$dep:[[:space:]]*\\^$repo_version\\b" \
    "$ROOT_DIR/mcp_toolkit/pubspec.yaml" \
    "$ROOT_DIR/mcp_server_dart/pubspec.yaml" \
    "$ROOT_DIR/packages/server_capability_kernel/pubspec.yaml" \
    "$ROOT_DIR/packages/server_capability_core/pubspec.yaml" >/dev/null; then
    fail "no hosted dependency constraint found for $dep ^$repo_version"
  fi
done

ok "package/plugin version touchpoints match VERSION ($repo_version)"
