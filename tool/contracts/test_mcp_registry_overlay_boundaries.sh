#!/usr/bin/env bash
# Assert MCP Registry publish keeps Dockerfile.registry from main after tag overlay.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OVERLAY="$ROOT_DIR/tool/release/overlay_mcp_registry_tag_sources.sh"
WF="$ROOT_DIR/.github/workflows/publish_mcp_registry.yml"

fail() { echo "test_mcp_registry_overlay_boundaries: $*" >&2; exit 1; }
ok() { echo "test_mcp_registry_overlay_boundaries: $*"; }

[[ -x "$OVERLAY" ]] || fail "missing $OVERLAY"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

main="$tmpdir/main"
tag="$tmpdir/tag-src"
mkdir -p "$main/mcp_server_dart/bin" "$main/mcp_server_dart/lib" "$tag/mcp_server_dart/bin" "$tag/mcp_server_dart/lib"

printf '%s\n' 'FROM debian:bookworm-slim AS build' 'storage.googleapis.com/flutter_infra_release' \
  > "$main/mcp_server_dart/Dockerfile.registry"
printf '%s\n' 'FROM ghcr.io/cirruslabs/flutter@sha256:217a3d81b124f3fab82b24633bf66b256cc74528b894e7f17103f70150232077 AS build' \
  > "$tag/mcp_server_dart/Dockerfile.registry"

printf '%s\n' 'name: flutter_mcp_toolkit_server' 'version: 7.1.0' > "$tag/mcp_server_dart/pubspec.yaml"
printf '%s\n' '{"name":"io.github.Arenukvern/flutter-mcp-toolkit","version":"7.1.0"}' > "$tag/mcp_server_dart/server.json"
printf '%s\n' '// stub' > "$tag/mcp_server_dart/lib/stub.dart"
printf '%s\n' '// stub' > "$tag/mcp_server_dart/bin/flutter_mcp_toolkit_server.dart"

TOOLING_ROOT="$main" RELEASE_SRC="$tag" bash "$OVERLAY"

effective="$main/mcp_server_dart/Dockerfile.registry"
grep -Fq 'storage.googleapis.com/flutter_infra_release' "$effective" || \
  fail "effective Dockerfile must remain main's tooling after overlay"
grep -Fq 'cirruslabs/flutter' "$effective" && fail "tag Dockerfile must not replace main Dockerfile.registry"

grep -Fq 'overlay_mcp_registry_tag_sources.sh' "$WF" || \
  fail "publish workflow must use overlay_mcp_registry_tag_sources.sh"
grep -Fq 'persist-credentials: false' "$WF" || fail "workflow must disable persist-credentials"
if grep -q 'rm -rf mcp_server_dart' "$WF"; then
  fail "workflow must not replace entire mcp_server_dart from tag"
fi

ok "MCP registry overlay boundary contracts OK"
