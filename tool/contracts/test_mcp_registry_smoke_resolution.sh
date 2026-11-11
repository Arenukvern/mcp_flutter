#!/usr/bin/env bash
# MCP Registry smoke build: hosted production vs pub.dev-aware sibling fallback.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREPARE="$ROOT_DIR/tool/ci/prepare_mcp_registry_smoke_build.sh"
SMOKE_WF="$ROOT_DIR/.github/workflows/mcp_registry_dockerfile.yml"
PUBLISH_WF="$ROOT_DIR/.github/workflows/publish_mcp_registry.yml"
DOCKERFILE="$ROOT_DIR/mcp_server_dart/Dockerfile.registry"

fail() { echo "test_mcp_registry_smoke_resolution: $*" >&2; exit 1; }
ok() { echo "test_mcp_registry_smoke_resolution: $*"; }

[[ -x "$PREPARE" ]] || fail "missing executable $PREPARE"

grep -Fq 'prepare_mcp_registry_smoke_build.sh' "$SMOKE_WF" ||
  fail "smoke workflow must run prepare_mcp_registry_smoke_build.sh"
grep -Fq 'steps.smoke_ctx.outputs.docker_context' "$SMOKE_WF" ||
  fail "smoke workflow must use dynamic docker context from prepare step"
grep -Fq 'prepare_mcp_registry_smoke_build.sh' "$PUBLISH_WF" &&
  fail "publish workflow must not run prepare_mcp_registry_smoke_build.sh"

grep -Fq 'resolution=hosted (pub.dev)' "$DOCKERFILE" ||
  fail "Dockerfile must log hosted resolution mode"
grep -Fq 'resolution=workspace_fallback' "$DOCKERFILE" ||
  fail "Dockerfile must log workspace_fallback resolution mode"

[[ ! -f "$ROOT_DIR/mcp_server_dart/pubspec_overrides.yaml" ]] ||
  fail "mcp_server_dart must not commit pubspec_overrides.yaml"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

fake_pubspec="$tmpdir/fake_server_pubspec.yaml"
cat >"$fake_pubspec" <<'YAML'
name: flutter_mcp_toolkit_server
version: 99.0.0
dependencies:
  flutter_mcp_toolkit_core: ^99.0.0
  flutter_mcp_toolkit_capability_kernel: ^99.0.0
  flutter_mcp_toolkit_capability_core: ^99.0.0
YAML

out_fallback="$tmpdir/fallback_ctx"
github_out="$tmpdir/github_output"
: >"$github_out"

MCP_REGISTRY_SERVER_PUBSPEC="$fake_pubspec" \
MCP_REGISTRY_SMOKE_OUTPUT="$out_fallback" \
GITHUB_OUTPUT="$github_out" \
bash "$PREPARE" | grep -Fq 'resolution_mode=workspace_fallback' ||
  fail "prepare must select workspace_fallback for unpublished train 99.0.0"

grep -Fq 'resolution_mode=workspace_fallback' "$github_out" ||
  fail "GITHUB_OUTPUT must record workspace_fallback"
grep -Fq "docker_context=${out_fallback}" "$github_out" ||
  fail "GITHUB_OUTPUT must point at temp docker context"

[[ -f "$out_fallback/mcp_server_dart/pubspec_overrides.yaml" ]] ||
  fail "fallback context must include pubspec_overrides.yaml"
grep -Fq 'path: ../packages/core' "$out_fallback/mcp_server_dart/pubspec_overrides.yaml" ||
  fail "overrides must reference packages/core"
[[ ! -f "$ROOT_DIR/mcp_server_dart/pubspec_overrides.yaml" ]] ||
  fail "prepare must not write overrides into git checkout"

github_out2="$tmpdir/github_output2"
: >"$github_out2"
MCP_REGISTRY_SERVER_PUBSPEC="$ROOT_DIR/mcp_server_dart/pubspec.yaml" \
GITHUB_OUTPUT="$github_out2" \
bash "$PREPARE" | grep -Fq 'resolution_mode=hosted' ||
  fail "prepare must select hosted when pub.dev exposes pinned siblings on main"

grep -Fq 'docker_context=.' "$github_out2" ||
  fail "hosted mode must use repository-root docker context"

ok "MCP Registry smoke resolution contracts OK"
