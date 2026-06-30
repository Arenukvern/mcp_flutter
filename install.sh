#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

DEFAULT_VERSION=""
if [[ -n "$ROOT_DIR" ]]; then
  if [[ -f "$ROOT_DIR/VERSION" ]]; then
    DEFAULT_VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION" 2>/dev/null || true)"
  fi
  if [[ -z "$DEFAULT_VERSION" ]]; then
    VERSION_SOURCE_FILE="$ROOT_DIR/packages/core/lib/src/runtime_version.dart"
    if [[ -f "$VERSION_SOURCE_FILE" ]]; then
      DEFAULT_VERSION="$(sed -nE "s/^const kFlutterMcpVersion = '([^']+)';.*$/\1/p" "$VERSION_SOURCE_FILE" 2>/dev/null || true)"
    fi
  fi
fi

REPO="${FLUTTER_MCP_REPO:-Arenukvern/mcp_flutter}"
VERSION="${FLUTTER_MCP_VERSION:-$DEFAULT_VERSION}"
INSTALL_DIR="${FLUTTER_MCP_INSTALL_DIR:-$HOME/.local/bin}"
BASE_URL="${FLUTTER_MCP_BASE_URL:-}"

usage() {
  cat <<USAGE
Usage: ./install.sh [--version <semver|vSemver>] [--install-dir <path>] [--repo <owner/name>] [--base-url <url>]
       curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | bash -s -- [--version <semver>]

Installs flutter-mcp-toolkit, its short fmtk alias, and flutter-mcp-toolkit-server from GitHub release artifacts.

When run from a git clone, version defaults to the repo VERSION file (or runtime_version.dart).
When piped from curl without --version, the latest GitHub release is used if available.
Override with FLUTTER_MCP_VERSION or --version.
USAGE
}

resolve_latest_release_version() {
  local api_url="https://api.github.com/repos/${REPO}/releases/latest"
  local body tag
  command -v curl >/dev/null 2>&1 || return 1
  body="$(curl -fsSL "$api_url" 2>/dev/null)" || return 1
  tag="$(sed -nE 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v?([^"]+)".*/\1/p' <<<"$body" | head -n1)"
  [[ -n "$tag" ]] || return 1
  printf '%s' "$tag"
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
  VERSION="$(resolve_latest_release_version || true)"
fi

if [[ -z "$VERSION" ]]; then
  cat >&2 <<EOF
Unable to resolve install version.

Specify a version explicitly, for example:
  curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | bash -s -- --version v3.0.4

Or from a git clone:
  ./install.sh
  FLUTTER_MCP_VERSION=3.0.4 ./install.sh
EOF
  usage >&2
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
if [[ "$triple" == "darwin-x64" ]]; then
  cat >&2 <<EOF
Intel Mac (x86_64) is not supported.
Published macOS binaries are Apple Silicon (arm64) only.
Install from source with Flutter/Dart, or use an Apple Silicon Mac.
EOF
  exit 1
fi
if [[ "$triple" != "darwin-arm64" && "$triple" != "linux-x64" ]]; then
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
install -m 0755 "$package_dir/bin/flutter-mcp-toolkit" "$INSTALL_DIR/flutter-mcp-toolkit"
if [[ -f "$package_dir/bin/fmtk" ]]; then
  install -m 0755 "$package_dir/bin/fmtk" "$INSTALL_DIR/fmtk"
else
  # Backward compatibility for pre-fmtk release artifacts: synthesize the alias
  # from the canonical CLI binary so raw-main installers can still install older tags.
  install -m 0755 "$package_dir/bin/flutter-mcp-toolkit" "$INSTALL_DIR/fmtk"
fi
install -m 0755 \
  "$package_dir/bin/flutter-mcp-toolkit-server" \
  "$INSTALL_DIR/flutter-mcp-toolkit-server"

echo "Installed binaries to $INSTALL_DIR"
"$INSTALL_DIR/flutter-mcp-toolkit" --help >/dev/null
"$INSTALL_DIR/fmtk" --help >/dev/null

if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  shell_name="$(basename "${SHELL:-sh}")"
  rc_file="$HOME/.profile"
  case "$shell_name" in
    zsh)
      rc_file="${ZDOTDIR:-$HOME}/.zshrc"
      ;;
    bash)
      rc_file="$HOME/.bashrc"
      ;;
  esac

  if [[ -f "$rc_file" ]] && ! grep -q "$INSTALL_DIR" "$rc_file"; then
    echo "" >> "$rc_file"
    echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$rc_file"
    echo ""
    echo "Added $INSTALL_DIR to PATH in $rc_file (restart your shell or run: source $rc_file)"
  else
    echo ""
    echo "PATH update required. Run this command:"
    echo "echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> $rc_file && export PATH=\"$INSTALL_DIR:\$PATH\""
  fi
fi

echo "Install complete: flutter-mcp-toolkit ${version_no_prefix}"
echo "Smoke test command: $INSTALL_DIR/flutter-mcp-toolkit --help"
echo "Short alias: $INSTALL_DIR/fmtk --help"
