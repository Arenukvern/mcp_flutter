#!/usr/bin/env bash
# Verifies the CLI binary/alias contract for Flutter MCP Toolkit.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PUBSPEC="$ROOT_DIR/mcp_server_dart/pubspec.yaml"
MAKEFILE="$ROOT_DIR/mcp_server_dart/makefile"
RELEASE_SCRIPT="$ROOT_DIR/tool/release/build_release_artifacts.sh"
INSTALL_SCRIPT="$ROOT_DIR/install.sh"

fail() {
  echo "cli-alias-surface: $*" >&2
  exit 1
}

ok() {
  echo "cli-alias-surface: $*"
}

for file in "$PUBSPEC" "$MAKEFILE" "$RELEASE_SCRIPT" "$INSTALL_SCRIPT"; do
  [[ -f "$file" ]] || fail "missing ${file#$ROOT_DIR/}"
done

grep -Eq '^[[:space:]]*fmtk:[[:space:]]*flutter_mcp_toolkit[[:space:]]*$' "$PUBSPEC" ||
  fail "mcp_server_dart/pubspec.yaml must expose fmtk -> flutter_mcp_toolkit"
grep -Eq '^[[:space:]]*flutter-mcp-toolkit:[[:space:]]*flutter_mcp_toolkit[[:space:]]*$' "$PUBSPEC" ||
  fail "mcp_server_dart/pubspec.yaml must keep canonical flutter-mcp-toolkit executable"
grep -Eq '^[[:space:]]*flutter-mcp-toolkit-server:[[:space:]]*flutter_mcp_toolkit_server[[:space:]]*$' "$PUBSPEC" ||
  fail "mcp_server_dart/pubspec.yaml must keep flutter-mcp-toolkit-server executable"

if grep -Eq '^[[:space:]]*fmt:[[:space:]]' "$PUBSPEC"; then
  fail "do not add fmt executable alias; /usr/bin/fmt already exists"
fi

grep -Fq 'cp build/flutter-mcp-toolkit build/fmtk' "$MAKEFILE" ||
  fail "mcp_server_dart/makefile must copy compiled CLI to build/fmtk"
grep -Fq 'bin/fmtk' "$RELEASE_SCRIPT" ||
  fail "release artifact builder must package bin/fmtk"
grep -Fq 'bin/fmtk' "$INSTALL_SCRIPT" ||
  fail "install.sh must install or synthesize fmtk"
grep -Fq 'fmtk" --help' "$INSTALL_SCRIPT" ||
  fail "install.sh must smoke fmtk --help"

ok "fmtk alias, canonical CLI, server binary, and no-fmt contract verified"
