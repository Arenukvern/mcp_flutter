#!/usr/bin/env bash
# Verifies repo VERSION matches every Flutter MCP Toolkit package and plugin
# release touchpoint.
set -euo pipefail

ROOT_DIR="${RELEASE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
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
  sed -nE "s/^const (String )?kFlutterMcpVersion = '([^']+)';.*$/\2/p" "$RUNTIME_VERSION_FILE" | head -1
)"
[[ "$runtime_version" == "$repo_version" ]] ||
  fail "kFlutterMcpVersion ($runtime_version) != VERSION ($repo_version)"

# Per-package versions are owned by dart_changesets: a package bumped on its
# own may sit ahead of VERSION until the product train moves, so only the
# product package pins VERSION. Tag/pubspec drift is the engine's check
# (dart_changesets version / publish-tag).
product_pubspec="$ROOT_DIR/mcp_toolkit/pubspec.yaml"
pubspec_version="$(
  sed -nE 's/^version:[[:space:]]*([^[:space:]#]+).*/\1/p' "$product_pubspec" | head -1
)"
[[ "$pubspec_version" == "$repo_version" ]] ||
  fail "mcp_toolkit/pubspec.yaml version ($pubspec_version) != VERSION ($repo_version)"

fmt_capability_version="$(
  sed -nE "s/.*version => '([^']+)';.*$/\1/p" "$FMT_CAPABILITY_FILE" | head -1
)"
[[ "$fmt_capability_version" == "$repo_version" ]] ||
  fail "FmtCapability.version ($fmt_capability_version) != VERSION ($repo_version)"

for manifest in \
  "$ROOT_DIR/plugin/.cursor-plugin/plugin.json" \
  "$ROOT_DIR/plugin/.codex-plugin/plugin.json" \
  "$ROOT_DIR/plugin/.claude-plugin/plugin.json" \
  "$ROOT_DIR/plugin/.zcode-plugin/plugin.json"; do
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

mcpb_manifest="$ROOT_DIR/mcp_server_dart/mcpb/manifest.json"
if [[ -f "$mcpb_manifest" ]]; then
  mcpb_version="$(
    sed -nE 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$mcpb_manifest" | head -1
  )"
  [[ "$mcpb_version" == "$repo_version" ]] ||
    fail "mcp_server_dart/mcpb/manifest.json version ($mcpb_version) != VERSION ($repo_version)"
else
  fail "missing mcp_server_dart/mcpb/manifest.json (MCPB release package)"
fi

for dep in \
  flutter_mcp_toolkit_core \
  flutter_mcp_toolkit_capability_kernel \
  flutter_mcp_toolkit_capability_core; do
  if ! grep -R "^[[:space:]]*$dep:[[:space:]]*\\^[0-9]" \
    "$ROOT_DIR/mcp_toolkit/pubspec.yaml" \
    "$ROOT_DIR/mcp_server_dart/pubspec.yaml" \
    "$ROOT_DIR/packages/server_capability_kernel/pubspec.yaml" \
    "$ROOT_DIR/packages/server_capability_core/pubspec.yaml" \
    "$ROOT_DIR/packages/harness/pubspec.yaml" >/dev/null; then
    fail "no hosted dependency constraint found for $dep"
  fi
done

ok "package/plugin version touchpoints match VERSION ($repo_version)"
