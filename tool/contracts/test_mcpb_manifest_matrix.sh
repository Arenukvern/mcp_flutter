#!/usr/bin/env bash
# Guards the MCPB bundle manifest against the release build matrix:
# - manifest_version 0.3, binary server, pinned default args
# - compatibility.platforms and mcp_config.platform_overrides cover exactly the
#   release.yml matrix triples (darwin-arm64 -> darwin, linux-x64 -> linux)
# - dropped platforms (win32, darwin-x64, linux-arm64) appear nowhere
# - the pack script pins the official mcpb CLI and stages both binaries
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="$ROOT_DIR/mcp_server_dart/mcpb/manifest.json"
RELEASE_WF="$ROOT_DIR/.github/workflows/release.yml"
PACK_SCRIPT="$ROOT_DIR/tool/release/pack_mcpb_bundle.sh"
MCPB_CLI_VERSION="2.1.2"

fail() { echo "test_mcpb_manifest_matrix: $*" >&2; exit 1; }
ok() { echo "test_mcpb_manifest_matrix: $*"; }

[[ -f "$MANIFEST" ]] || fail "missing mcp_server_dart/mcpb/manifest.json"
[[ -f "$RELEASE_WF" ]] || fail "missing release.yml"
[[ -f "$PACK_SCRIPT" ]] || fail "missing tool/release/pack_mcpb_bundle.sh"

export MANIFEST RELEASE_WF
ruby <<'RUBY'
require 'json'
require 'yaml'

manifest = JSON.parse(File.read(ENV.fetch('MANIFEST')))
wf = YAML.safe_load(File.read(ENV.fetch('RELEASE_WF')), aliases: true)
matrix = wf.dig('jobs', 'build', 'strategy', 'matrix', 'include') || []
triples = matrix.map { |m| m['triple'] }.sort

abort 'release.yml build matrix is empty' if triples.empty?
unless triples == ['darwin-arm64', 'linux-x64']
  abort "MCPB supports darwin-arm64 + linux-x64 only; release matrix is #{triples.inspect}"
end
expected_os = triples.map { |t| t.split('-').first }.sort

abort "manifest_version #{manifest['manifest_version'].inspect} must be '0.3'" unless manifest['manifest_version'] == '0.3'
abort 'server.type must be binary' unless manifest.dig('server', 'type') == 'binary'
unless manifest.dig('server', 'entry_point') == 'server/darwin-arm64/flutter-mcp-toolkit-server'
  abort "server.entry_point must be the darwin-arm64 server binary, got #{manifest.dig('server', 'entry_point').inspect}"
end

platforms = (manifest.dig('compatibility', 'platforms') || []).sort
unless platforms == expected_os
  abort "compatibility.platforms #{platforms.inspect} must match the matrix OS set #{expected_os.inspect}"
end

overrides = manifest.dig('server', 'mcp_config', 'platform_overrides') || {}
unless overrides.keys.sort == expected_os
  abort "mcp_config.platform_overrides keys #{overrides.keys.sort.inspect} must match #{expected_os.inspect}"
end

triples.each do |triple|
  os = triple.split('-').first
  cmd = overrides[os] && overrides[os]['command']
  expected = "server/#{triple}/flutter-mcp-toolkit-server"
  abort "platform_overrides.#{os} command #{cmd.inspect} must point at #{expected}" unless cmd == expected
end

expected_args = [
  '--dart-vm-host=localhost',
  '--dart-vm-port=8181',
  '--resources',
  '--images',
  '--dynamics',
]
args = manifest.dig('server', 'mcp_config', 'args')
abort "mcp_config.args must be #{expected_args.inspect}, got #{args.inspect}" unless args == expected_args

# Platforms dropped from the release train must not resurface in the bundle.
flat = JSON.generate(manifest)
%w[win32 darwin-x64 linux-arm64].each do |banned|
  abort "manifest must not reference dropped platform #{banned}" if flat.include?(banned)
end

puts "manifest matrix consistent: #{triples.join(' + ')} -> #{expected_os.join(' + ')}"
RUBY

# The pack script must pin the official CLI and stage both matrix binaries.
grep -Eq 'MCPB_CLI_VERSION:-[0-9]+\.[0-9]+\.[0-9]+' "$PACK_SCRIPT" ||
  fail "pack script must pin MCPB_CLI_VERSION (expected $MCPB_CLI_VERSION)"
grep -Fq "MCPB_CLI_VERSION:-${MCPB_CLI_VERSION}" "$PACK_SCRIPT" ||
  fail "pack script MCPB_CLI_VERSION pin drifted from the contract (${MCPB_CLI_VERSION})"
grep -Fq 'darwin-arm64' "$PACK_SCRIPT" || fail "pack script does not stage darwin-arm64"
grep -Fq 'linux-x64' "$PACK_SCRIPT" || fail "pack script does not stage linux-x64"

# Network-backed validation with the official CLI is an explicit opt-in
# (MCPB_CONTRACT_VALIDATE=1): an unavailable npm registry or an uncached
# package must not fail `make check-contracts` offline. The release pipeline
# always validates — pack_mcpb_bundle.sh runs `mcpb validate` before packing.
if [[ "${MCPB_CONTRACT_VALIDATE:-0}" == "1" ]]; then
  command -v npx >/dev/null 2>&1 ||
    fail "MCPB_CONTRACT_VALIDATE=1 requires npx"
  npx --yes "@anthropic-ai/mcpb@${MCPB_CLI_VERSION}" validate "$MANIFEST" >/dev/null 2>&1 ||
    fail "official mcpb CLI rejected mcp_server_dart/mcpb/manifest.json"
  ok "official mcpb CLI (${MCPB_CLI_VERSION}) accepted the manifest"
else
  ok "skipped network-backed CLI validation (set MCPB_CONTRACT_VALIDATE=1 to run)"
fi

ok "MCPB manifest matches the release matrix"
