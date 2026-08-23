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
# The MCP Registry rejects OCI packages carrying registryBaseUrl; the canonical
# ghcr.io reference in identifier is required instead (publish run #4 failure).
abort 'OCI package must not carry registryBaseUrl (use canonical identifier)' if package.key?('registryBaseUrl')
abort 'OCI package transport must be stdio' unless package.dig('transport', 'type') == 'stdio'
RUBY

grep -Fq 'io.modelcontextprotocol.server.name="io.github.Arenukvern/flutter-mcp-toolkit"' "$DOCKERFILE" ||
  fail "Dockerfile is missing the exact MCP ownership label"
grep -Fq 'bin/flutter_mcp_toolkit_server.dart' "$DOCKERFILE" ||
  fail "Dockerfile does not compile the published server entrypoint"

export DOCKERFILE RELEASE_WORKFLOW
ruby <<'RUBY'
require 'yaml'

dockerfile = File.read(ENV.fetch('DOCKERFILE'))

# --- Dockerfile: build stage must be a pinned Flutter SDK image ---
# Join continuation lines so each instruction is inspected whole.
instructions = dockerfile.gsub(/\\\s*\n/, ' ').split(/\n+/)
build_from = instructions.grep(/^FROM /i).find { |l| /\bAS\s+build\b/i.match?(l) }
abort 'Dockerfile is missing a build stage named AS build' unless build_from
unless /^FROM\s+ghcr\.io\/cirruslabs\/flutter:(\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?)@sha256:[0-9a-f]{64}\s/i.match?(build_from) ||
       /^FROM\s+ghcr\.io\/cirruslabs\/flutter:\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?\s/i.match?(build_from)
  abort "Dockerfile build stage must use ghcr.io/cirruslabs/flutter with an exact version tag (or digest); got: #{build_from.strip}"
end

# --- Dockerfile: no RUN instruction may use --enforce-lockfile ---
if instructions.grep(/^RUN /i).any? { |l| l.include?('--enforce-lockfile') }
  abort 'Dockerfile must not run --enforce-lockfile: SDK-bundled pins differ per host platform and break cross-platform builds'
end

# --- Workflow: assert exact context/file in the build-push step's with mapping ---
workflow = YAML.safe_load(File.read(ENV.fetch('RELEASE_WORKFLOW')), aliases: true)
steps = workflow.dig('jobs', 'publish', 'steps') || []
build_step = steps.find { |s| s['uses'].to_s.start_with?('docker/build-push-action@') }
abort 'publish workflow has no docker/build-push-action step' unless build_step
with = build_stage_with = build_step['with'] || {}
abort 'publish workflow build step must set with.context exactly to "." (workspace siblings are unpublished)' unless with['context'] == '.'
abort 'publish workflow build step must set with.file exactly to mcp_server_dart/Dockerfile.registry' unless with['file'] == 'mcp_server_dart/Dockerfile.registry'
RUBY

grep -Fq 'github-oidc' "$RELEASE_WORKFLOW" ||
  fail "publish workflow does not use GitHub OIDC for MCP Registry authentication"
grep -Fq 'gh workflow run publish_mcp_registry.yml' "$PUB_WORKFLOW" ||
  fail "pub.dev publication does not trigger the dependent MCP Registry publication"

echo "check_mcp_registry: manifest, OCI metadata, and release wiring are consistent for $(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
