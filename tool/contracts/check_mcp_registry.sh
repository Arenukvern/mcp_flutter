#!/usr/bin/env bash
# Verifies the MCP Registry manifest, OCI ownership label, and release wiring.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVER_JSON="$ROOT_DIR/mcp_server_dart/server.json"
DOCKERFILE="$ROOT_DIR/mcp_server_dart/Dockerfile.registry"
FLUTTER_PIN="$ROOT_DIR/tool/contracts/flutter_sdk_pin.env"
SERVER_PUBSPEC="$ROOT_DIR/mcp_server_dart/pubspec.yaml"
RELEASE_WORKFLOW="$ROOT_DIR/.github/workflows/publish_mcp_registry.yml"
SMOKE_WORKFLOW="$ROOT_DIR/.github/workflows/mcp_registry_dockerfile.yml"
RELEASE_BINARIES_WORKFLOW="$ROOT_DIR/.github/workflows/release.yml"

fail() {
  echo "check_mcp_registry: $*" >&2
  exit 1
}

[[ -f "$SERVER_JSON" ]] || fail "missing mcp_server_dart/server.json"
[[ -f "$DOCKERFILE" ]] || fail "missing mcp_server_dart/Dockerfile.registry"
[[ -f "$FLUTTER_PIN" ]] || fail "missing tool/contracts/flutter_sdk_pin.env"
[[ -f "$SERVER_PUBSPEC" ]] || fail "missing mcp_server_dart/pubspec.yaml"
[[ -f "$RELEASE_WORKFLOW" ]] || fail "missing publish_mcp_registry.yml"
[[ -f "$SMOKE_WORKFLOW" ]] || fail "missing mcp_registry_dockerfile.yml"
[[ -f "$RELEASE_BINARIES_WORKFLOW" ]] || fail "missing release.yml"

export FLUTTER_PIN
python3 <<'PY'
import json, os, pathlib, urllib.request

pin_path = pathlib.Path(os.environ["FLUTTER_PIN"])
pin = {}
for line in pin_path.read_text().splitlines():
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    key, value = line.split("=", 1)
    pin[key] = value

flutter = pin["FLUTTER_VERSION"]
expected_dart = pin["EXPECTED_DART_SDK_VERSION"]
expected_sha = pin["FLUTTER_SDK_SHA256"]

with urllib.request.urlopen(
    "https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json",
    timeout=60,
) as resp:
    data = json.load(resp)

matches = [
    r
    for r in data.get("releases", [])
    if r.get("version") == flutter and r.get("channel") == "stable"
]
if len(matches) != 1:
    raise SystemExit(f"flutter_sdk_pin: expected one stable linux row for {flutter}, got {len(matches)}")

rel = matches[0]
if rel.get("sha256") != expected_sha:
    raise SystemExit(
        f"flutter_sdk_pin: FLUTTER_SDK_SHA256 mismatch for {flutter} "
        f"(pin {expected_sha}, official {rel.get('sha256')})"
    )
official_dart = rel.get("dart_sdk_version", "")
if official_dart != expected_dart:
    raise SystemExit(
        f"flutter_sdk_pin: EXPECTED_DART_SDK_VERSION must be {official_dart} "
        f"(Flutter {flutter} stable linux), not {expected_dart}"
    )
print(f"flutter_sdk_pin: {flutter} stable linux ships Dart {official_dart} (sha256 verified)")
PY

export SERVER_JSON ROOT_DIR
ruby <<'RUBY'
require 'json'

server = JSON.parse(File.read(ENV.fetch('SERVER_JSON')))
version = File.read(File.join(ENV.fetch('ROOT_DIR'), 'VERSION')).strip
name = 'io.github.Arenukvern/flutter-mcp-toolkit'
description = server.fetch('description')
packages = server.fetch('packages')
package = packages.find { |candidate| candidate['registryType'] == 'oci' }
mcpb_package = packages.find { |candidate| candidate['registryType'] == 'mcpb' }

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

# MCPB package: ordered after the OCI image, tag-addressed download URL, stdio.
# fileSha256 is injected by the publish workflow from the release asset; a
# checked-in (stale) hash must never survive a version bump.
abort "server.json must list exactly two packages (oci first, mcpb second), got #{packages.size}" unless packages.size == 2
abort 'packages[0] must be the OCI image (clients prefer the first entry)' unless packages[0]['registryType'] == 'oci'
abort 'MCPB package is missing' unless mcpb_package
expected_mcpb_identifier =
  "https://github.com/Arenukvern/mcp_flutter/releases/download/v#{version}/flutter-mcp-toolkit.mcpb"
abort "MCPB identifier #{mcpb_package['identifier']} != #{expected_mcpb_identifier}" unless mcpb_package['identifier'] == expected_mcpb_identifier
abort 'MCPB package transport must be stdio' unless mcpb_package.dig('transport', 'type') == 'stdio'
abort 'MCPB package must not carry fileSha256 at rest (publish-time injection)' if mcpb_package.key?('fileSha256')
RUBY

grep -Fq 'io.modelcontextprotocol.server.name="io.github.Arenukvern/flutter-mcp-toolkit"' "$DOCKERFILE" ||
  fail "Dockerfile is missing the exact MCP ownership label"
grep -Fq 'bin/flutter_mcp_toolkit_server.dart' "$DOCKERFILE" ||
  fail "Dockerfile does not compile the published server entrypoint"

export DOCKERFILE RELEASE_WORKFLOW FLUTTER_PIN SERVER_PUBSPEC
ruby <<'RUBY'
require 'yaml'

dockerfile = File.read(ENV.fetch('DOCKERFILE'))
pin = {}
File.readlines(ENV.fetch('FLUTTER_PIN'), chomp: true).each do |line|
  next if line.strip.empty? || line.start_with?('#')
  key, value = line.split('=', 2)
  pin[key] = value
end

%w[FLUTTER_VERSION FLUTTER_SDK_SHA256 EXPECTED_DART_SDK_VERSION].each do |key|
  abort "flutter_sdk_pin.env missing #{key}" unless pin[key]&.length&.positive?
end
abort 'FLUTTER_SDK_SHA256 must be 64 hex chars' unless pin['FLUTTER_SDK_SHA256'] =~ /\A[0-9a-f]{64}\z/

server_pubspec = File.read(ENV.fetch('SERVER_PUBSPEC'))
sdk_constraint = server_pubspec[/^\s*sdk:\s*'([^']+)'/m, 1]
unless (m = sdk_constraint&.match(/\A>=\s*([^<\s]+)/))
  abort 'mcp_server_dart pubspec must declare sdk lower bound (e.g. >=3.13.0 <4.0.0)'
end
required_dart = Gem::Version.new(m[1])
bundled_dart = Gem::Version.new(pin.fetch('EXPECTED_DART_SDK_VERSION'))
abort "Docker Flutter pin Dart #{bundled_dart} does not satisfy server sdk #{required_dart}" if bundled_dart < required_dart

# --- Dockerfile: build stage pins the same Flutter SDK as CI ---
instructions = dockerfile.gsub(/\\\s*\n/, ' ').split(/\n+/).map(&:strip)
build_from = instructions.grep(/^FROM\b/i).find { |l| /\bAS\s+build(\s|$)/i.match?(l) }
abort 'Dockerfile is missing a build stage named AS build' unless build_from

arg_flutter = dockerfile[/^\s*ARG\s+FLUTTER_VERSION=(\S+)/m, 1]
arg_sha = dockerfile[/^\s*ARG\s+FLUTTER_SDK_SHA256=(\S+)/m, 1]
abort 'Dockerfile must declare ARG FLUTTER_VERSION matching flutter_sdk_pin.env' unless arg_flutter == pin['FLUTTER_VERSION']
abort 'Dockerfile must declare ARG FLUTTER_SDK_SHA256 matching flutter_sdk_pin.env' unless arg_sha == pin['FLUTTER_SDK_SHA256']

unless dockerfile.include?('storage.googleapis.com/flutter_infra_release')
  abort 'Dockerfile must install Flutter from the official stable linux archive'
end
unless dockerfile.include?('sha256sum --check --strict')
  abort 'Dockerfile must verify the Flutter SDK archive sha256 before extraction'
end
unless dockerfile.include?('safe.directory /opt/flutter')
  abort 'Dockerfile must mark /opt/flutter as a git safe.directory before invoking flutter'
end

# --- Dockerfile: no RUN instruction may use --enforce-lockfile ---
if instructions.grep(/^RUN\b/i).any? { |l| l.include?('--enforce-lockfile') }
  abort 'Dockerfile must not run --enforce-lockfile: SDK-bundled pins differ per host platform and break cross-platform builds'
end

# --- Workflow: assert exact context/file in the build-push step's with mapping ---
workflow = YAML.safe_load(File.read(ENV.fetch('RELEASE_WORKFLOW')), aliases: true)
steps = workflow.dig('jobs', 'publish', 'steps') || []
build_step = steps.find { |s| s['uses'].to_s.start_with?('docker/build-push-action@') }
abort 'publish workflow has no docker/build-push-action step' unless build_step
with = build_stage_with = build_step['with'] || {}
abort 'publish workflow build step must set with.context exactly to "." (hosted resolution; no smoke overrides)' unless with['context'] == '.'
abort 'publish workflow build step must set with.file exactly to mcp_server_dart/Dockerfile.registry' unless with['file'] == 'mcp_server_dart/Dockerfile.registry'

smoke = YAML.safe_load(File.read(File.join(ENV.fetch('ROOT_DIR'), '.github/workflows/mcp_registry_dockerfile.yml')), aliases: true)
smoke_steps = smoke.dig('jobs', 'build-smoke', 'steps') || []
abort 'smoke workflow must call prepare_mcp_registry_smoke_build.sh' unless smoke_steps.any? { |s|
  s['run'].to_s.include?('prepare_mcp_registry_smoke_build.sh')
}
smoke_build = smoke_steps.find { |s| s['uses'].to_s.start_with?('docker/build-push-action@') }
abort 'smoke workflow has no docker/build-push-action step' unless smoke_build
smoke_with = smoke_build['with'] || {}
abort 'smoke workflow must use dynamic docker context outputs' unless smoke_with['context'].to_s.include?('smoke_ctx.outputs.docker_context')

# --- Registry publish: MCPB gate + fileSha256 injection must precede mcp-publisher publish
publish_steps = workflow.dig('jobs', 'publish', 'steps') || []
gate_index = publish_steps.index { |s| s['run'].to_s.include?('assert_mcp_registry_release_assets.sh') }
abort 'publish workflow must run the fail-closed MCPB asset gate (assert_mcp_registry_release_assets.sh)' unless gate_index
inject_index = publish_steps.index { |s| s['run'].to_s.include?('fileSha256') }
abort 'publish workflow must inject fileSha256 into server.json before publishing' unless inject_index
publisher_index = publish_steps.index { |s| s['run'].to_s.include?('mcp-publisher publish') }
abort 'publish workflow has no mcp-publisher publish step' unless publisher_index
abort 'MCPB asset gate must run before mcp-publisher publish' unless gate_index < publisher_index
abort 'fileSha256 injection must run after the MCPB gate and before publish' unless gate_index < inject_index && inject_index < publisher_index
download_step = publish_steps.find { |s| s['run'].to_s.include?("gh release download") && s['run'].to_s.include?('flutter-mcp-toolkit.mcpb') }
abort 'publish workflow must download flutter-mcp-toolkit.mcpb from the release before the gate' unless download_step
download_index = publish_steps.index(download_step)
abort 'MCPB download must precede the fail-closed gate' unless download_index < gate_index

# --- Binary release: the MCPB job packs and uploads the bundle; publish ships it
binaries = YAML.safe_load(File.read(File.join(ENV.fetch('ROOT_DIR'), '.github/workflows/release.yml')), aliases: true)
abort 'release.yml must have an mcpb job' unless binaries.dig('jobs', 'mcpb')
abort 'release.yml mcpb job must pack via pack_mcpb_bundle.sh' unless
  (binaries.dig('jobs', 'mcpb', 'steps') || []).any? { |s| s['run'].to_s.include?('pack_mcpb_bundle.sh') }
mcpb_upload = (binaries.dig('jobs', 'mcpb', 'steps') || []).find { |s|
  s['uses'].to_s.start_with?('actions/upload-artifact@') && s['with'].to_s.include?('release-mcpb')
}
abort 'release.yml mcpb job must upload the release-mcpb artifact' unless mcpb_upload
publish_needs = binaries.dig('jobs', 'publish', 'needs') || []
abort 'release.yml publish job must depend on the mcpb job' unless publish_needs.include?('mcpb')
checksum_step = (binaries.dig('jobs', 'publish', 'steps') || []).find { |s| s['run'].to_s.include?('checksums.txt') }
abort 'release.yml publish job must generate checksums.txt' unless checksum_step
abort 'checksums.txt must include the .mcpb bundle' unless checksum_step['run'].to_s.include?('.mcpb')
RUBY

grep -Fq 'flutter-mcp-toolkit.mcpb' "$ROOT_DIR/tool/release/release_assets_conflict_lib.sh" ||
  fail "release asset conflict guard must expect flutter-mcp-toolkit.mcpb"
grep -Fq 'mcp_server_dart/mcpb/manifest.json' "$ROOT_DIR/tool/release/sync_version.sh" ||
  fail "sync_version must keep mcp_server_dart/mcpb/manifest.json in the release train"

grep -Fq 'prepare_mcp_registry_smoke_build.sh' "$RELEASE_WORKFLOW" &&
  fail "publish workflow must not invoke prepare_mcp_registry_smoke_build.sh"
grep -Fq 'assert_mcp_registry_no_pubspec_overrides.sh' "$RELEASE_WORKFLOW" ||
  fail "publish workflow must assert no pubspec_overrides before OCI build"

grep -Fq 'release_tag:' "$RELEASE_WORKFLOW" ||
  fail "publish workflow must declare workflow_dispatch release_tag input"
grep -Fq 'github-oidc' "$RELEASE_WORKFLOW" ||
  fail "publish workflow does not use GitHub OIDC for MCP Registry authentication"
grep -Fq 'gh workflow run publish_mcp_registry.yml' "$RELEASE_BINARIES_WORKFLOW" ||
  fail "binary release does not trigger the dependent MCP Registry publication"
grep -Fq 'needs.prepare.outputs.release_tag' "$RELEASE_BINARIES_WORKFLOW" ||
  fail "registry trigger must use prepare.outputs.release_tag"
grep -Fq 'resolve_mcp_registry_release_version.sh' "$RELEASE_WORKFLOW" ||
  fail "publish_mcp_registry must resolve version from release-src"
grep -Fq 'overlay_mcp_registry_tag_sources.sh' "$RELEASE_WORKFLOW" ||
  fail "publish_mcp_registry must overlay tag sources without replacing Dockerfile.registry"

echo "check_mcp_registry: manifest, OCI metadata, and release wiring are consistent for $(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
