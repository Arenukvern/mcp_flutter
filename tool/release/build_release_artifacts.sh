#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist/release}"
VERSION_SOURCE_FILE="$ROOT_DIR/mcp_shared_core/lib/src/runtime_version.dart"

VERSION="${VERSION:-$(sed -nE "s/^const kFlutterMcpVersion = '([^']+)';.*$/\1/p" "$VERSION_SOURCE_FILE")}"
if [[ -z "$VERSION" ]]; then
  echo "Failed to resolve release version from $VERSION_SOURCE_FILE" >&2
  exit 1
fi

declare -a TRIPLES=()
CLEAN=0

usage() {
  cat <<USAGE
Usage: tool/release/build_release_artifacts.sh [--version <semver>] [--triple <darwin-arm64|darwin-x64|linux-x64>] [--clean]

Builds release tarballs for flutter-mcp-toolkit and flutter-mcp-toolkit-server.
Generates SHA-256 checksums at dist/release/checksums.txt.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --triple)
      TRIPLES+=("$2")
      shift 2
      ;;
    --clean)
      CLEAN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ${#TRIPLES[@]} -eq 0 ]]; then
  TRIPLES=(darwin-arm64 darwin-x64 linux-x64)
fi

if [[ "$CLEAN" -eq 1 ]]; then
  rm -rf "$DIST_DIR"
fi
mkdir -p "$DIST_DIR"

resolve_target() {
  local triple="$1"
  case "$triple" in
    darwin-arm64)
      echo "macos arm64"
      ;;
    darwin-x64)
      echo "macos x64"
      ;;
    linux-x64)
      echo "linux x64"
      ;;
    *)
      echo "Unsupported triple: $triple" >&2
      exit 1
      ;;
  esac
}

compile_binary() {
  local entrypoint="$1"
  local output="$2"
  local target_os="$3"
  local target_arch="$4"

  (
    cd "$ROOT_DIR/mcp_server_dart"
    HOME=/tmp DART_SUPPRESS_ANALYTICS=true dart compile exe \
      "$entrypoint" \
      --target-os "$target_os" \
      --target-arch "$target_arch" \
      -o "$output"
  )
}

for triple in "${TRIPLES[@]}"; do
  read -r target_os target_arch <<<"$(resolve_target "$triple")"

  package_name="flutter_mcp_${VERSION}_${triple}"
  stage_dir="$DIST_DIR/$package_name"
  archive_path="$DIST_DIR/${package_name}.tar.gz"

  rm -rf "$stage_dir" "$archive_path"
  mkdir -p "$stage_dir/bin"

  compile_binary "bin/flutter_mcp_toolkit.dart" "$stage_dir/bin/flutter-mcp-toolkit" "$target_os" "$target_arch"
  compile_binary "bin/flutter_mcp_toolkit_server.dart" "$stage_dir/bin/flutter-mcp-toolkit-server" "$target_os" "$target_arch"

  cp "$ROOT_DIR/LICENSE" "$stage_dir/LICENSE"

  tar -C "$DIST_DIR" -czf "$archive_path" "$package_name"

  smoke_dir="$(mktemp -d)"
  tar -C "$smoke_dir" -xzf "$archive_path"
  "$smoke_dir/$package_name/bin/flutter-mcp-toolkit" --help >/dev/null
  "$smoke_dir/$package_name/bin/flutter-mcp-toolkit-server" --help >/dev/null
  rm -rf "$smoke_dir"

  rm -rf "$stage_dir"
  echo "Built $archive_path"
done

if command -v sha256sum >/dev/null 2>&1; then
  (
    cd "$DIST_DIR"
    sha256sum flutter_mcp_"$VERSION"_*.tar.gz > checksums.txt
  )
else
  (
    cd "$DIST_DIR"
    shasum -a 256 flutter_mcp_"$VERSION"_*.tar.gz > checksums.txt
  )
fi

echo "Checksums written to $DIST_DIR/checksums.txt"
