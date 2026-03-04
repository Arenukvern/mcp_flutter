#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_SOURCE_FILE="$ROOT_DIR/mcp_server_dart/lib/src/core/runtime_version.dart"
DEFAULT_VERSION="$(sed -nE "s/^const kFlutterMcpVersion = '([^']+)';/\1/p" "$VERSION_SOURCE_FILE")"

REPO="${FLUTTER_MCP_REPO:-Arenukvern/mcp_flutter}"
VERSION="${FLUTTER_MCP_VERSION:-$DEFAULT_VERSION}"
INSTALL_DIR="${FLUTTER_MCP_INSTALL_DIR:-$HOME/.local/bin}"
BASE_URL="${FLUTTER_MCP_BASE_URL:-}"

usage() {
  cat <<USAGE
Usage: ./install.sh [--version <semver|vSemver>] [--install-dir <path>] [--repo <owner/name>] [--base-url <url>]

Installs flutter_mcp_cli and flutter_inspector_mcp_server from GitHub release artifacts.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --install-dir)
      INSTALL_DIR="$2"
      shift 2
      ;;
    --repo)
      REPO="$2"
      shift 2
      ;;
    --base-url)
      BASE_URL="$2"
      shift 2
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

if [[ -z "$VERSION" ]]; then
  echo "Unable to resolve install version." >&2
  exit 1
fi

version_no_prefix="${VERSION#v}"
tag="v${version_no_prefix}"

os="$(uname -s)"
arch="$(uname -m)"

case "$os" in
  Darwin)
    platform="darwin"
    ;;
  Linux)
    platform="linux"
    ;;
  *)
    echo "Unsupported OS: $os" >&2
    exit 1
    ;;
esac

case "$arch" in
  arm64|aarch64)
    normalized_arch="arm64"
    ;;
  x86_64|amd64)
    normalized_arch="x64"
    ;;
  *)
    echo "Unsupported architecture: $arch" >&2
    exit 1
    ;;
esac

triple="${platform}-${normalized_arch}"
if [[ "$triple" != "darwin-arm64" && "$triple" != "darwin-x64" && "$triple" != "linux-x64" ]]; then
  echo "No published artifacts for $triple." >&2
  exit 1
fi

archive="flutter_mcp_${version_no_prefix}_${triple}.tar.gz"
if [[ -z "$BASE_URL" ]]; then
  BASE_URL="https://github.com/${REPO}/releases/download/${tag}"
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

fetch() {
  local url="$1"
  local output="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$output"
    return
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -qO "$output" "$url"
    return
  fi
  echo "Neither curl nor wget is available." >&2
  exit 1
}

sha256_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
    return
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
    return
  fi
  echo "No SHA-256 tool available (sha256sum or shasum)." >&2
  exit 1
}

echo "Downloading $archive"
fetch "$BASE_URL/$archive" "$work_dir/$archive"
fetch "$BASE_URL/checksums.txt" "$work_dir/checksums.txt"

checksum_line="$(grep " ${archive}$" "$work_dir/checksums.txt" || true)"
if [[ -z "$checksum_line" ]]; then
  echo "Missing checksum entry for $archive" >&2
  exit 1
fi

expected_checksum="$(awk '{print $1}' <<<"$checksum_line")"
actual_checksum="$(sha256_file "$work_dir/$archive")"
if [[ "$expected_checksum" != "$actual_checksum" ]]; then
  echo "Checksum verification failed for $archive" >&2
  echo "expected: $expected_checksum" >&2
  echo "actual:   $actual_checksum" >&2
  exit 1
fi

echo "Checksum verified"

tar -C "$work_dir" -xzf "$work_dir/$archive"
package_dir="$work_dir/flutter_mcp_${version_no_prefix}_${triple}"

mkdir -p "$INSTALL_DIR"
install -m 0755 "$package_dir/bin/flutter_mcp_cli" "$INSTALL_DIR/flutter_mcp_cli"
install -m 0755 \
  "$package_dir/bin/flutter_inspector_mcp_server" \
  "$INSTALL_DIR/flutter_inspector_mcp_server"

echo "Installed binaries to $INSTALL_DIR"
"$INSTALL_DIR/flutter_mcp_cli" --help >/dev/null

if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  shell_name="$(basename "${SHELL:-sh}")"
  rc_file="$HOME/.profile"
  case "$shell_name" in
    zsh)
      rc_file="$HOME/.zshrc"
      ;;
    bash)
      rc_file="$HOME/.bashrc"
      ;;
  esac

  echo ""
  echo "PATH update required. Run this command:"
  echo "echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> $rc_file && export PATH=\"$INSTALL_DIR:\$PATH\""
fi

echo "Install complete: flutter_mcp_cli ${version_no_prefix}"
echo "Smoke test command: $INSTALL_DIR/flutter_mcp_cli --help"
