#!/usr/bin/env bash
# MCP Registry smoke build: hosted production vs pub.dev-aware sibling fallback.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREPARE="$ROOT_DIR/tool/ci/prepare_mcp_registry_smoke_build.sh"
FIXTURE_API="$ROOT_DIR/tool/contracts/fixtures/mcp_registry_pub_api"
ASSERT_NO_OVR="$ROOT_DIR/tool/release/assert_mcp_registry_no_pubspec_overrides.sh"
SMOKE_WF="$ROOT_DIR/.github/workflows/mcp_registry_dockerfile.yml"
PUBLISH_WF="$ROOT_DIR/.github/workflows/publish_mcp_registry.yml"
DOCKERFILE="$ROOT_DIR/mcp_server_dart/Dockerfile.registry"

fail() { echo "test_mcp_registry_smoke_resolution: $*" >&2; exit 1; }
ok() { echo "test_mcp_registry_smoke_resolution: $*"; }

[[ -x "$PREPARE" ]] || fail "missing executable $PREPARE"
[[ -x "$ASSERT_NO_OVR" ]] || fail "missing executable $ASSERT_NO_OVR"

grep -Fq 'prepare_mcp_registry_smoke_build.sh' "$SMOKE_WF" ||
  fail "smoke workflow must run prepare_mcp_registry_smoke_build.sh"
grep -Fq 'steps.smoke_ctx.outputs.docker_context' "$SMOKE_WF" ||
  fail "smoke workflow must use dynamic docker context from prepare step"
grep -Fq 'prepare_mcp_registry_smoke_build.sh' "$PUBLISH_WF" &&
  fail "publish workflow must not run prepare_mcp_registry_smoke_build.sh"
grep -Fq 'assert_mcp_registry_no_pubspec_overrides.sh' "$PUBLISH_WF" ||
  fail "publish workflow must assert no pubspec_overrides before OCI build"

grep -Fq 'resolution=hosted (pub.dev)' "$DOCKERFILE" ||
  fail "Dockerfile must log hosted resolution mode"
grep -Fq 'resolution=workspace_fallback' "$DOCKERFILE" ||
  fail "Dockerfile must log workspace_fallback resolution mode"

[[ ! -f "$ROOT_DIR/mcp_server_dart/pubspec_overrides.yaml" ]] ||
  fail "mcp_server_dart must not commit pubspec_overrides.yaml"

bash "$ASSERT_NO_OVR" || fail "assert must pass on clean tree"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

fake_fallback_pubspec="$tmpdir/fake_server_pubspec_fallback.yaml"
cat >"$fake_fallback_pubspec" <<'YAML'
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

MCP_REGISTRY_SERVER_PUBSPEC="$fake_fallback_pubspec" \
MCP_REGISTRY_SMOKE_OUTPUT="$out_fallback" \
MCP_REGISTRY_PUB_API_BASE="$FIXTURE_API" \
GITHUB_OUTPUT="$github_out" \
bash "$PREPARE" | grep -Fq 'resolution_mode=workspace_fallback' ||
  fail "prepare must select workspace_fallback for unpublished train 99.0.0 (fixture API)"

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

fake_hosted_pubspec="$tmpdir/fake_server_pubspec_hosted.yaml"
cat >"$fake_hosted_pubspec" <<'YAML'
name: flutter_mcp_toolkit_server
version: 7.1.0
dependencies:
  flutter_mcp_toolkit_core: ^7.1.0
  flutter_mcp_toolkit_capability_kernel: ^7.1.0
  flutter_mcp_toolkit_capability_core: ^7.1.0
YAML

github_out2="$tmpdir/github_output2"
: >"$github_out2"
MCP_REGISTRY_SERVER_PUBSPEC="$fake_hosted_pubspec" \
MCP_REGISTRY_PUB_API_BASE="$FIXTURE_API" \
GITHUB_OUTPUT="$github_out2" \
bash "$PREPARE" | grep -Fq 'resolution_mode=hosted' ||
  fail "prepare must select hosted when fixture index exposes 7.1.0 (not live pubspec)"

grep -Fq 'docker_context=.' "$github_out2" ||
  fail "hosted mode must use repository-root docker context"

missing_fixture="$tmpdir/empty_fixtures"
mkdir -p "$missing_fixture"
if MCP_REGISTRY_SERVER_PUBSPEC="$fake_hosted_pubspec" \
  MCP_REGISTRY_PUB_API_BASE="$missing_fixture" \
  bash "$PREPARE" 2>"$tmpdir/api_err.txt"; then
  fail "prepare must fail when pub API fixture is missing (not silently fallback)"
fi
grep -Fq 'fixture missing' "$tmpdir/api_err.txt" ||
  fail "missing fixture must fail loudly"

touch "$ROOT_DIR/mcp_server_dart/pubspec_overrides.yaml"
if bash "$ASSERT_NO_OVR" 2>"$tmpdir/assert_err.txt"; then
  rm -f "$ROOT_DIR/mcp_server_dart/pubspec_overrides.yaml"
  fail "assert_mcp_registry_no_pubspec_overrides must fail when overrides exist"
fi
rm -f "$ROOT_DIR/mcp_server_dart/pubspec_overrides.yaml"
grep -Fq 'hosted-only' "$tmpdir/assert_err.txt" ||
  fail "assert must mention hosted-only refusal"

ok "MCP Registry smoke resolution contracts OK"
