#!/usr/bin/env bash
# Pack the single flutter-mcp-toolkit.mcpb release asset from the per-triple
# release tarballs (darwin-arm64 + linux-x64 server binaries) and the checked-in
# MCPB manifest (mcp_server_dart/mcpb/manifest.json).
#
# Usage:
#   tool/release/pack_mcpb_bundle.sh \
#     --version <semver> \
#     --darwin-tarball <flutter_mcp_<v>_darwin-arm64.tar.gz> \
#     --linux-tarball <flutter_mcp_<v>_linux-x64.tar.gz> \
#     --manifest <mcp_server_dart/mcpb/manifest.json> \
#     --output <flutter-mcp-toolkit.mcpb>
#
# Prints "sha256=<hash>" on success (the hash that server.json's mcpb package
# carries as fileSha256 in the MCP Registry publish).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Pinned official CLI (npm @anthropic-ai/mcpb). Override for local testing only.
MCPB_CLI_VERSION="${MCPB_CLI_VERSION:-2.1.2}"

fail() { echo "pack_mcpb_bundle: $*" >&2; exit 1; }
ok() { echo "pack_mcpb_bundle: $*"; }

VERSION=""
DARWIN_TARBALL=""
LINUX_TARBALL=""
MANIFEST=""
OUTPUT=""

usage() {
  cat <<USAGE
Usage: tool/release/pack_mcpb_bundle.sh --version <semver> \
  --darwin-tarball <tar.gz> --linux-tarball <tar.gz> \
  --manifest <manifest.json> --output <bundle.mcpb>
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="${2:-}"; shift 2 ;;
    --darwin-tarball) DARWIN_TARBALL="${2:-}"; shift 2 ;;
    --linux-tarball) LINUX_TARBALL="${2:-}"; shift 2 ;;
    --manifest) MANIFEST="${2:-}"; shift 2 ;;
    --output) OUTPUT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$VERSION" && -f "$DARWIN_TARBALL" && -f "$LINUX_TARBALL" && -f "$MANIFEST" && -n "$OUTPUT" ]] ||
  { usage >&2; fail "missing or invalid arguments"; }

command -v jq >/dev/null 2>&1 || fail "jq required"
command -v unzip >/dev/null 2>&1 || fail "unzip required"
command -v file >/dev/null 2>&1 || fail "file required"

# The official mcpb CLI when present, otherwise the exact pinned npm package.
run_mcpb() {
  if command -v mcpb >/dev/null 2>&1; then
    mcpb "$@"
  else
    command -v npx >/dev/null 2>&1 ||
      fail "mcpb CLI missing and npx unavailable (install @anthropic-ai/mcpb@$MCPB_CLI_VERSION)"
    npx --yes "@anthropic-ai/mcpb@$MCPB_CLI_VERSION" "$@"
  fi
}

# --- Manifest contract: version + platform layout (deep matrix check lives in
# tool/contracts/test_mcpb_manifest_matrix.sh; this guard runs on the packed
# artifact's inputs at release time).
[[ "$(jq -r '.manifest_version' "$MANIFEST")" == "0.3" ]] ||
  fail "manifest_version must be 0.3 (got $(jq -r '.manifest_version' "$MANIFEST"))"
[[ "$(jq -r '.version' "$MANIFEST")" == "$VERSION" ]] ||
  fail "manifest version ($(jq -r '.version' "$MANIFEST")) != release version ($VERSION)"
[[ "$(jq -r '.server.type' "$MANIFEST")" == "binary" ]] ||
  fail "server.type must be binary"
platforms_json="$(jq -c '.compatibility.platforms' "$MANIFEST")"
[[ "$platforms_json" == '["darwin","linux"]' ]] ||
  fail "compatibility.platforms must be exactly [\"darwin\",\"linux\"] (got $platforms_json)"

darwin_command="$(jq -r '.server.mcp_config.platform_overrides.darwin.command // empty' "$MANIFEST")"
linux_command="$(jq -r '.server.mcp_config.platform_overrides.linux.command // empty' "$MANIFEST")"
[[ -n "$darwin_command" && -n "$linux_command" ]] ||
  fail "mcp_config.platform_overrides must define darwin and linux commands"

extract_dir="$(mktemp -d)"
stage_dir="$(mktemp -d)"
cleanup() { rm -rf "$extract_dir" "$stage_dir"; }
trap cleanup EXIT

stage_server_binary() {
  local tarball="$1" triple="$2" override_command="$3"
  local pkg_dir="flutter_mcp_${VERSION}_${triple}"
  local work="$extract_dir/$triple"
  mkdir -p "$work"
  tar -C "$work" -xzf "$tarball"
  local binary="$work/$pkg_dir/bin/flutter-mcp-toolkit-server"
  [[ -f "$binary" ]] || fail "$triple tarball is missing bin/flutter-mcp-toolkit-server"
  # The manifest may prefix commands with ${__dirname}; the staged layout is
  # always relative to the bundle root, so strip that prefix (single-quoted
  # pattern: an unquoted } would terminate the expansion).
  local rel="${override_command/'${__dirname}'/}"
  local staged="$stage_dir/$rel"
  mkdir -p "$(dirname "$staged")"
  cp "$binary" "$staged"
  chmod +x "$staged"
  file "$staged"
}

darwin_file_out="$(stage_server_binary "$DARWIN_TARBALL" darwin-arm64 "$darwin_command")"
echo "$darwin_file_out" | grep -qE 'Mach-O.*arm64' ||
  fail "darwin bundle binary is not arm64: $darwin_file_out"
linux_file_out="$(stage_server_binary "$LINUX_TARBALL" linux-x64 "$linux_command")"
echo "$linux_file_out" | grep -qE 'ELF 64-bit.*x86-64' ||
  fail "linux bundle binary is not x86-64: $linux_file_out"

entry_point="$(jq -r '.server.entry_point' "$MANIFEST")"
[[ -f "$stage_dir/$entry_point" ]] ||
  fail "server.entry_point '$entry_point' does not exist in the staged bundle"
cp "$MANIFEST" "$stage_dir/manifest.json"

run_mcpb validate "$stage_dir/manifest.json" ||
  fail "mcpb validate rejected $MANIFEST"

rm -f "$OUTPUT"
run_mcpb pack "$stage_dir" "$OUTPUT" ||
  fail "mcpb pack failed"
[[ -f "$OUTPUT" ]] || fail "mcpb pack produced no output at $OUTPUT"

# mcpb pack stamps entries with the wall clock, so identical inputs otherwise
# produce different bytes and a different sha256 on every rerun — which would
# break checksum-based recovery after a partially published release. Patching
# the timestamps to a fixed epoch makes the archive deterministic (payloads,
# CRCs, permissions, and entry order are preserved byte-for-byte).
command -v python3 >/dev/null 2>&1 ||
  fail "python3 required to normalize bundle timestamps"
python3 "$ROOT_DIR/tool/release/normalize_mcpb_timestamps.py" "$OUTPUT" ||
  fail "timestamp normalization failed"

# --- Bundle contents must carry both platform binaries.
zip_listing="$(unzip -l "$OUTPUT")"
echo "$zip_listing" | grep -q "$entry_point" ||
  fail "packed bundle is missing $entry_point"
echo "$zip_listing" | grep -q "server/linux-x64/flutter-mcp-toolkit-server" ||
  fail "packed bundle is missing server/linux-x64/flutter-mcp-toolkit-server"
echo "$zip_listing" | grep -q "manifest.json" ||
  fail "packed bundle is missing manifest.json"

bundle_sha="$(
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$OUTPUT" | awk '{print $1}'
  else
    shasum -a 256 "$OUTPUT" | awk '{print $1}'
  fi
)"

ok "packed $(basename "$OUTPUT") from darwin-arm64 + linux-x64 server binaries"
echo "sha256=$bundle_sha"
