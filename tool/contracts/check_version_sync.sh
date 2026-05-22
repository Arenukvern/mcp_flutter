#!/usr/bin/env bash
# Verifies repo VERSION matches all release-tagged version touchpoints.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION_FILE="$ROOT_DIR/VERSION"
RUNTIME_VERSION_FILE="$ROOT_DIR/flutter_mcp_toolkit_core/lib/src/runtime_version.dart"
FMT_CAPABILITY_FILE="$ROOT_DIR/flutter_mcp_toolkit_capability_core/lib/src/fmt_capability.dart"

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

server_pubspec_version="$(
  sed -nE 's/^version:[[:space:]]*([^[:space:]#]+).*/\1/p' "$ROOT_DIR/mcp_server_dart/pubspec.yaml" | head -1
)"
[[ "$server_pubspec_version" == "$repo_version" ]] ||
  fail "mcp_server_dart/pubspec.yaml version ($server_pubspec_version) != VERSION ($repo_version)"

toolkit_pubspec_version="$(
  sed -nE 's/^version:[[:space:]]*([^[:space:]#]+).*/\1/p' "$ROOT_DIR/mcp_toolkit/pubspec.yaml" | head -1
)"
[[ "$toolkit_pubspec_version" == "$repo_version" ]] ||
  fail "mcp_toolkit/pubspec.yaml version ($toolkit_pubspec_version) != VERSION ($repo_version)"

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

ok "all version touchpoints match VERSION ($repo_version)"
