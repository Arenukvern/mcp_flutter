#!/usr/bin/env bash
# Synchronize the Flutter MCP Toolkit one-version train from VERSION.
#
# Usage:
#   tool/release/sync_version.sh [--version <semver>]
#
# If --version is supplied, VERSION is updated first. All other release
# touchpoints are derived from VERSION.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION_FILE="$ROOT_DIR/VERSION"

usage() {
  cat <<USAGE
Usage: tool/release/sync_version.sh [--version <semver>]

Synchronizes package versions, same-train dependency constraints, runtime
metadata, plugin manifests, marketplace metadata, release-please manifest,
README dependency snippets, and package changelog entries from root VERSION.
USAGE
}

fail() {
  echo "sync_version: $*" >&2
  exit 1
}

version=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      [[ $# -ge 2 ]] || fail "--version requires a value"
      version="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

if [[ -n "$version" ]]; then
  printf '%s\n' "$version" > "$VERSION_FILE"
else
  [[ -f "$VERSION_FILE" ]] || fail "missing VERSION file"
  version="$(tr -d '[:space:]' < "$VERSION_FILE")"
fi

[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]] ||
  fail "VERSION must be semver-compatible, got '$version'"

major="${version%%.*}"
rest="${version#*.}"
minor="${rest%%.*}"
protocol_version="$major.$minor"

release_touchpoint_files=(
  "$ROOT_DIR/plugin/EXPECTED_SERVER_VERSION"
)
for file in "${release_touchpoint_files[@]}"; do
  printf '%s\n' "$version" > "$file"
done

pubspec_version_files=(
  "$ROOT_DIR/mcp_server_dart/pubspec.yaml"
  "$ROOT_DIR/mcp_toolkit/pubspec.yaml"
  "$ROOT_DIR/packages/core/pubspec.yaml"
  "$ROOT_DIR/packages/server_capability_kernel/pubspec.yaml"
  "$ROOT_DIR/packages/server_capability_core/pubspec.yaml"
)
for file in "${pubspec_version_files[@]}"; do
  perl -0pi -e "s/^version:\\s*[^\\n#]+/version: $version/m" "$file"
done

same_train_constraint_files=(
  "$ROOT_DIR/mcp_server_dart/pubspec.yaml"
  "$ROOT_DIR/mcp_toolkit/pubspec.yaml"
  "$ROOT_DIR/packages/server_capability_kernel/pubspec.yaml"
  "$ROOT_DIR/packages/server_capability_core/pubspec.yaml"
  "$ROOT_DIR/packages/core/README.md"
  "$ROOT_DIR/packages/server_capability_kernel/README.md"
  "$ROOT_DIR/packages/server_capability_core/README.md"
)
same_train_packages=(
  flutter_mcp_toolkit_core
  flutter_mcp_toolkit_capability_kernel
  flutter_mcp_toolkit_capability_core
)
export FMT_RELEASE_VERSION="$version"
for file in "${same_train_constraint_files[@]}"; do
  [[ -f "$file" ]] || continue
  for package in "${same_train_packages[@]}"; do
    perl -0pi -e "s/($package:\\s*)\\^[0-9]+\\.[0-9]+\\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\\+[0-9A-Za-z.-]+)?/\${1}^$version/g" "$file"
  done
done

same_train_readme_files=(
  "$ROOT_DIR/packages/core/README.md"
  "$ROOT_DIR/packages/server_capability_kernel/README.md"
  "$ROOT_DIR/packages/server_capability_core/README.md"
)
for file in "${same_train_readme_files[@]}"; do
  [[ -f "$file" ]] || continue
  perl -0pi \
    -e 'BEGIN { $v = $ENV{FMT_RELEASE_VERSION} } s/(`flutter_mcp_toolkit_core` `)[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?(`)/$1$v$2/g; s/(kernel \+ core `\^?)[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?(`)/$1$v$2/g; s/(kernel and core `)[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?(`)/$1$v$2/g;' \
    "$file"
done

export FMT_RELEASE_DATE="${FMT_RELEASE_DATE:-$(date -u +%F)}"
ruby <<'RUBY'
version = ENV.fetch('FMT_RELEASE_VERSION')
date = ENV.fetch('FMT_RELEASE_DATE')

entries = [
  [
    'packages/core/CHANGELOG.md',
    "## [#{version}] - #{date}\n\n### Changed\n\n- Align package version with the Flutter MCP Toolkit prerelease train.\n\n",
  ],
  [
    'packages/server_capability_kernel/CHANGELOG.md',
    "## [#{version}] - #{date}\n\n### Changed\n\n- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit prerelease train.\n\n",
  ],
  [
    'packages/server_capability_core/CHANGELOG.md',
    "## [#{version}] - #{date}\n\n### Changed\n\n- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit prerelease train.\n\n",
  ],
  [
    'mcp_toolkit/CHANGELOG.md',
    "# #{version}\n\n- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit prerelease train.\n\n",
  ],
]

entries.each do |path, entry|
  next unless File.exist?(path)
  content = File.read(path)
  next if content.include?(version)

  updated =
    if path == 'mcp_toolkit/CHANGELOG.md'
      entry + content
    elsif content.match?(/\n## \[(?!Unreleased\])/)
      content.sub(/\n## \[(?!Unreleased\])/, "\n#{entry}## [")
    else
      content.rstrip + "\n\n" + entry
    end

  File.write(path, updated)
end
RUBY

perl -0pi \
  -e "s{const kFlutterMcpVersion = '[^']+';}{const kFlutterMcpVersion = '$version';};" \
  -e "s{const kFlutterMcpMajorVersion = [0-9]+;}{const kFlutterMcpMajorVersion = $major;};" \
  -e "s{flutter-mcp-toolkit/[0-9]+\\.[0-9]+}{flutter-mcp-toolkit/$protocol_version};" \
  "$ROOT_DIR/packages/core/lib/src/runtime_version.dart"

perl -0pi \
  -e "s{String get version => '[^']+';}{String get version => '$version';};" \
  "$ROOT_DIR/packages/server_capability_core/lib/src/fmt_capability.dart"

ruby <<'RUBY'
require 'json'

version = ENV.fetch('FMT_RELEASE_VERSION')
files = [
  ['plugin/.cursor-plugin/plugin.json', ['version']],
  ['plugin/.codex-plugin/plugin.json', ['version']],
  ['plugin/.claude-plugin/plugin.json', ['version']],
  ['.claude-plugin/marketplace.json', ['plugins', 0, 'version']],
  ['.release-please-manifest.json', ['.']],
]

files.each do |path, keys|
  next unless File.exist?(path)
  json = JSON.parse(File.read(path))
  cursor = json
  keys[0...-1].each { |key| cursor = cursor.fetch(key) }
  cursor[keys.last] = version
  File.write(path, JSON.pretty_generate(json) + "\n")
end
RUBY

echo "sync_version: synchronized release train to $version"
