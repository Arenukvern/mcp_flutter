#!/usr/bin/env bash
# Verifies the MCP Registry manifest, OCI ownership label, and release wiring.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVER_JSON="$ROOT_DIR/mcp_server_dart/server.json"
DOCKERFILE="$ROOT_DIR/mcp_server_dart/Dockerfile.registry"
RELEASE_WORKFLOW="$ROOT_DIR/.github/workflows/publish_mcp_registry.yml"
PUB_WORKFLOW="$ROOT_DIR/.github/workflows/pub_publish.yml"

fail() {
  echo "check_mcp_registry: $*" >&2
  exit 1
}

[[ -f "$SERVER_JSON" ]] || fail "missing mcp_server_dart/server.json"
[[ -f "$DOCKERFILE" ]] || fail "missing mcp_server_dart/Dockerfile.registry"
[[ -f "$RELEASE_WORKFLOW" ]] || fail "missing publish_mcp_registry.yml"
[[ -f "$PUB_WORKFLOW" ]] || fail "missing pub_publish.yml"

export SERVER_JSON ROOT_DIR
ruby <<'RUBY'
require 'json'

server = JSON.parse(File.read(ENV.fetch('SERVER_JSON')))
version = File.read(File.join(ENV.fetch('ROOT_DIR'), 'VERSION')).strip
name = 'io.github.Arenukvern/flutter-mcp-toolkit'
description = server.fetch('description')
package = server.fetch('packages').find { |candidate| candidate['registryType'] == 'oci' }

abort 'server name is not the repository-owned MCP namespace' unless server['name'] == name
abort 'description must be between 1 and 100 characters' unless description.length.between?(1, 100)
abort "server version #{server['version']} != VERSION #{version}" unless server['version'] == version
abort 'OCI package is missing' unless package
expected_identifier = "ghcr.io/arenukvern/flutter-mcp-toolkit:#{version}"
abort "OCI identifier #{package['identifier']} != #{expected_identifier}" unless package['identifier'] == expected_identifier
abort 'OCI package transport must be stdio' unless package.dig('transport', 'type') == 'stdio'
RUBY

grep -Fq 'io.modelcontextprotocol.server.name="io.github.Arenukvern/flutter-mcp-toolkit"' "$DOCKERFILE" ||
  fail "Dockerfile is missing the exact MCP ownership label"
grep -Fq 'bin/flutter_mcp_toolkit_server.dart' "$DOCKERFILE" ||
  fail "Dockerfile does not compile the published server entrypoint"
grep -Fq 'docker/build-push-action' "$RELEASE_WORKFLOW" ||
  fail "publish workflow does not build and push the OCI image"
grep -Fq 'file: Dockerfile.registry' "$RELEASE_WORKFLOW" ||
  fail "publish workflow is not using the dedicated Registry Dockerfile"
grep -Fq 'github-oidc' "$RELEASE_WORKFLOW" ||
  fail "publish workflow does not use GitHub OIDC for MCP Registry authentication"
grep -Fq 'gh workflow run publish_mcp_registry.yml' "$PUB_WORKFLOW" ||
  fail "pub.dev publication does not trigger the dependent MCP Registry publication"

echo "check_mcp_registry: manifest, OCI metadata, and release wiring are consistent for $(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
