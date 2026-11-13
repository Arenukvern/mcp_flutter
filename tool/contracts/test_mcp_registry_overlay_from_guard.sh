#!/usr/bin/env bash
# FROM-line-only guard for MCP Registry overlay (no false positives on comments).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OVERLAY="$ROOT_DIR/tool/release/overlay_mcp_registry_tag_sources.sh"
GUARD="$ROOT_DIR/tool/release/dockerfile_registry_from_guard.sh"
MAIN_DOCKERFILE="$ROOT_DIR/mcp_server_dart/Dockerfile.registry"

fail() { echo "test_mcp_registry_overlay_from_guard: $*" >&2; exit 1; }
ok() { echo "test_mcp_registry_overlay_from_guard: $*"; }

[[ -x "$OVERLAY" ]] || fail "missing $OVERLAY"
[[ -f "$GUARD" ]] || fail "missing $GUARD"
# shellcheck source=/dev/null
source "$GUARD"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

[[ -f "$MAIN_DOCKERFILE" ]] || fail "missing main Dockerfile.registry"
if dockerfile_registry_has_forbidden_cirruslabs_from "$MAIN_DOCKERFILE"; then
  fail "main Dockerfile.registry must not match forbidden FROM (comment-only cirruslabs OK)"
fi

fixture_main="$tmpdir/main"
fixture_tag="$tmpdir/tag-src"
mkdir -p "$fixture_main/mcp_server_dart/bin" "$fixture_main/mcp_server_dart/lib" \
  "$fixture_tag/mcp_server_dart/bin" "$fixture_tag/mcp_server_dart/lib"

cp "$MAIN_DOCKERFILE" "$fixture_main/mcp_server_dart/Dockerfile.registry"

printf '%s\n' 'name: flutter_mcp_toolkit_server' 'version: 7.1.1' > "$fixture_tag/mcp_server_dart/pubspec.yaml"
printf '%s\n' '{"name":"io.github.Arenukvern/flutter-mcp-toolkit","version":"7.1.1"}' > "$fixture_tag/mcp_server_dart/server.json"
printf '%s\n' '// stub' > "$fixture_tag/mcp_server_dart/lib/stub.dart"
printf '%s\n' '// stub' > "$fixture_tag/mcp_server_dart/bin/flutter_mcp_toolkit_server.dart"

TOOLING_ROOT="$fixture_main" RELEASE_SRC="$fixture_tag" bash "$OVERLAY" >/dev/null ||
  fail "overlay must succeed when main Dockerfile only mentions cirruslabs in comments"

bad_from="$tmpdir/bad_from/Dockerfile.registry"
mkdir -p "$(dirname "$bad_from")"
printf '%s\n' \
  'FROM ghcr.io/cirruslabs/flutter@sha256:217a3d81b124f3fab82b24633bf66b256cc74528b894e7f17103f70150232077 AS build' \
  > "$bad_from"
dockerfile_registry_has_forbidden_cirruslabs_from "$bad_from" ||
  fail "guard must detect v7.1.0-style FROM ghcr.io/cirruslabs/flutter"

bad_platform="$tmpdir/bad_platform/Dockerfile.registry"
mkdir -p "$(dirname "$bad_platform")"
printf '%s\n' \
  'from --platform=linux/amd64 ghcr.io/cirruslabs/flutter:3.44.0 AS build' \
  > "$bad_platform"
dockerfile_registry_has_forbidden_cirruslabs_from "$bad_platform" ||
  fail "guard must detect case-insensitive FROM with --platform cirruslabs image"

ok "MCP registry overlay FROM guard contracts OK"
