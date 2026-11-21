#!/usr/bin/env bash
# Fail-closed gate for the MCP Registry publish: the GitHub release MUST carry a
# complete flutter-mcp-toolkit.mcpb whose sha256 matches checksums.txt before
# any mcp-publisher publish runs. Registry versions are immutable, so a missing
# or mismatched bundle blocks the version instead of publishing a hole.
#
# Reads a local directory of downloaded release assets (no gh calls here, so
# contract tests can stage fixtures); the workflow downloads the assets first.
#
# Usage:
#   tool/release/assert_mcp_registry_release_assets.sh \
#     --tag <vX.Y.Z> --version <semver> --assets-dir <dir with *.mcpb + checksums.txt>
#
# Prints "sha256=<hash>" on success for the fileSha256 injection step.
set -euo pipefail

MCPB_ASSET_NAME="flutter-mcp-toolkit.mcpb"
DARWIN_ENTRY="server/darwin-arm64/flutter-mcp-toolkit-server"
LINUX_ENTRY="server/linux-x64/flutter-mcp-toolkit-server"

fail() { echo "assert_mcp_registry_release_assets: $*" >&2; exit 1; }
ok() { echo "assert_mcp_registry_release_assets: $*"; }

TAG=""
VERSION=""
ASSETS_DIR=""

usage() {
  cat <<USAGE
Usage: tool/release/assert_mcp_registry_release_assets.sh \\
  --tag <vX.Y.Z> --version <semver> --assets-dir <dir>
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) TAG="${2:-}"; shift 2 ;;
    --version) VERSION="${2:-}"; shift 2 ;;
    --assets-dir) ASSETS_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "tag must look like vX.Y.Z (got '$TAG')"
[[ -n "$VERSION" ]] || fail "--version is required"
[[ -d "$ASSETS_DIR" ]] || fail "assets dir not found: $ASSETS_DIR"

command -v jq >/dev/null 2>&1 || fail "jq required"
command -v unzip >/dev/null 2>&1 || fail "unzip required"

# --- 1. The bundle asset must exist on the release (fail closed on absence).
shopt -s nullglob
mcpb_files=( "$ASSETS_DIR/$MCPB_ASSET_NAME" )
shopt -u nullglob
[[ ${#mcpb_files[@]} -eq 1 ]] ||
  fail "$MCPB_ASSET_NAME is missing from release $TAG — refusing to publish an immutable registry version without its MCPB package"

mcpb_path="${mcpb_files[0]}"

# --- 2. The release checksums.txt must list the bundle and the hashes must match.
checksums_file="$ASSETS_DIR/checksums.txt"
[[ -f "$checksums_file" ]] || fail "checksums.txt is missing from release $TAG"
listed_sha="$(awk -v asset="$MCPB_ASSET_NAME" '$2 == asset { print $1; exit }' "$checksums_file")"
[[ -n "$listed_sha" ]] ||
  fail "checksums.txt on $TAG does not list $MCPB_ASSET_NAME"
if command -v sha256sum >/dev/null 2>&1; then
  actual_sha="$(sha256sum "$mcpb_path" | awk '{print $1}')"
else
  actual_sha="$(shasum -a 256 "$mcpb_path" | awk '{print $1}')"
fi
[[ "$actual_sha" == "$listed_sha" ]] ||
  fail "$MCPB_ASSET_NAME sha256 ($actual_sha) does not match checksums.txt ($listed_sha) on $TAG"

# --- 3. The bundle must be complete: manifest + both platform binaries.
# Filename-only entries with exact, fixed-string matches: a suffixed name
# (for example flutter-mcp-toolkit-server.bak) must never satisfy the gate.
zip_entries="$(unzip -Z1 "$mcpb_path")" || fail "$MCPB_ASSET_NAME is not a readable MCPB (zip) archive"
echo "$zip_entries" | grep -qxF "manifest.json" || fail "$MCPB_ASSET_NAME is missing manifest.json"
echo "$zip_entries" | grep -qxF "$DARWIN_ENTRY" ||
  fail "$MCPB_ASSET_NAME is missing $DARWIN_ENTRY (darwin bundle missing — blocked)"
echo "$zip_entries" | grep -qxF "$LINUX_ENTRY" ||
  fail "$MCPB_ASSET_NAME is missing $LINUX_ENTRY (linux bundle missing — blocked)"

# --- 4. The bundled manifest must describe this exact release.
work_dir="$(mktemp -d)"
cleanup() { rm -rf "$work_dir"; }
trap cleanup EXIT
bundle_manifest="$work_dir/manifest.json"
unzip -p "$mcpb_path" manifest.json >"$bundle_manifest" ||
  fail "$MCPB_ASSET_NAME does not contain a readable manifest.json"
bundle_version="$(jq -r '.version // empty' "$bundle_manifest")"
[[ "$bundle_version" == "$VERSION" ]] ||
  fail "bundle manifest version ($bundle_version) != release version ($VERSION)"

ok "$MCPB_ASSET_NAME on $TAG verified (sha256 matches checksums.txt; darwin-arm64 + linux-x64 present; manifest version $bundle_version)"
echo "sha256=$actual_sha"
