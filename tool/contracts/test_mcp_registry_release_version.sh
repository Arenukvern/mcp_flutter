#!/usr/bin/env bash
# Registry recovery must use the tag tree version even when main VERSION has moved on.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RESOLVER="$ROOT_DIR/tool/release/resolve_mcp_registry_release_version.sh"

fail() { echo "test_mcp_registry_release_version: $*" >&2; exit 1; }
ok() { echo "test_mcp_registry_release_version: $*"; }

[[ -x "$RESOLVER" ]] || fail "missing $RESOLVER"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

main_src="$tmpdir/main"
tag_src="$tmpdir/tag-src"

mkdir -p "$main_src/mcp_server_dart" "$tag_src/mcp_server_dart"

printf '%s\n' '7.2.0' > "$main_src/VERSION"
printf '%s\n' '7.1.0' > "$tag_src/VERSION"
printf '%s\n' 'name: flutter_mcp_toolkit_server' 'version: 7.1.0' > "$tag_src/mcp_server_dart/pubspec.yaml"

# Older tag + main ahead: must resolve 7.1.0 from tag-src (ignore main).
out="$(RELEASE_SRC="$tag_src" RELEASE_TAG=v7.1.0 bash "$RESOLVER" | tail -n1)"
[[ "$out" == "7.1.0" ]] || fail "expected 7.1.0 from tag-src, got '$out'"

# Tag must match release-src VERSION.
if RELEASE_SRC="$tag_src" RELEASE_TAG=v7.2.0 bash "$RESOLVER" 2>/dev/null; then
  fail "mismatched tag vs release-src VERSION must fail"
fi

printf '%s\n' '7.1.0' > "$tag_src/mcp_server_dart/pubspec.yaml"
cat > "$tag_src/mcp_server_dart/pubspec.yaml" <<'YAML'
name: flutter_mcp_toolkit_server
version: 7.0.9
YAML
if RELEASE_SRC="$tag_src" RELEASE_TAG=v7.1.0 bash "$RESOLVER" 2>/dev/null; then
  fail "mismatched pubspec version must fail"
fi

# Workflow must not gate on root VERSION (main train).
WF="$ROOT_DIR/.github/workflows/publish_mcp_registry.yml"
grep -Fq 'resolve_mcp_registry_release_version.sh' "$WF" || \
  fail "publish_mcp_registry.yml must call resolve_mcp_registry_release_version.sh"
grep -Fq 'RELEASE_SRC:' "$WF" || \
  fail "publish workflow must pass RELEASE_SRC into resolve_mcp_registry_release_version.sh"
if grep -q 'file_version="$(tr -d.*< VERSION)"' "$WF"; then
  fail "publish workflow must not compare release_tag against root VERSION"
fi

ok "MCP registry release version resolution contracts OK"
