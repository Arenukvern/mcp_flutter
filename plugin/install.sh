#!/usr/bin/env bash
# flutter-mcp-toolkit plugin installer
# Verifies prerequisites and helps locate/build the flutter-mcp-toolkit-server binary.
# Idempotent — safe to re-run.

set -euo pipefail

log()  { printf "\033[1;34m[flutter-mcp-toolkit]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[flutter-mcp-toolkit]\033[0m %s\n" "$*" >&2; }
err()  { printf "\033[1;31m[flutter-mcp-toolkit]\033[0m %s\n" "$*" >&2; exit 1; }

# 1. Dart
if ! command -v dart >/dev/null 2>&1; then
  err "Dart SDK not found on PATH. Install from https://dart.dev/get-dart and retry."
fi
log "Dart found: $(dart --version 2>&1 | head -n1)"

# 2. Locate binary
BIN_NAME="flutter-mcp-toolkit-server"
BIN_PATH=""

if [[ -n "${FLUTTER_MCP_BIN:-}" && -x "${FLUTTER_MCP_BIN}" ]]; then
  BIN_PATH="${FLUTTER_MCP_BIN}"
  log "Using FLUTTER_MCP_BIN: ${BIN_PATH}"
elif command -v "${BIN_NAME}" >/dev/null 2>&1; then
  BIN_PATH="$(command -v "${BIN_NAME}")"
  log "Found on PATH: ${BIN_PATH}"
else
  warn "${BIN_NAME} not on PATH and FLUTTER_MCP_BIN not set."
  cat <<EOF

To build it from source:

  git clone https://github.com/Arenukvern/mcp_flutter
  cd mcp_flutter
  make install && make build

Then either:
  - add mcp_flutter/mcp_server_dart/build/ to your PATH, or
  - export FLUTTER_MCP_BIN=/absolute/path/to/mcp_flutter/mcp_server_dart/build/${BIN_NAME}

After that, re-run this installer.
EOF
  exit 1
fi

# 3. Smoke test the binary
if ! "${BIN_PATH}" --help >/dev/null 2>&1; then
  err "${BIN_PATH} failed --help. Rebuild with: cd mcp_flutter && make build"
fi
log "Binary smoke test: ok"

# 3b. Version pin — reject mismatched binaries against this plugin release.
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPECTED_VERSION_FILE="${PLUGIN_DIR}/EXPECTED_SERVER_VERSION"
if [[ -f "${EXPECTED_VERSION_FILE}" ]]; then
  EXPECTED="$(tr -d '[:space:]' < "${EXPECTED_VERSION_FILE}")"
  ACTUAL="$("${BIN_PATH}" --version 2>/dev/null | tr -d '[:space:]' || true)"
  # Binary --version may print "flutter-mcp-toolkit-server 3.0.0" or just "3.0.0" —
  # match by substring so either form works.
  if [[ -z "${ACTUAL}" ]]; then
    warn "Could not read --version from ${BIN_PATH}; skipping pin check."
  elif [[ "${ACTUAL}" != *"${EXPECTED}"* ]]; then
    err "Version mismatch: plugin expects ${EXPECTED}, binary reports '${ACTUAL}'. Rebuild from the matching mcp_flutter tag, or set FLUTTER_MCP_SKIP_VERSION_PIN=1 to override."
  else
    log "Version pin: ok (${EXPECTED})"
  fi
elif [[ "${FLUTTER_MCP_SKIP_VERSION_PIN:-0}" == "1" ]]; then
  warn "Skipping version pin (FLUTTER_MCP_SKIP_VERSION_PIN=1)."
fi

# 4. flutter-mcp-toolkit CLI (optional but recommended for doctor preflight)
CLI_NAME="flutter-mcp-toolkit"
if command -v "${CLI_NAME}" >/dev/null 2>&1; then
  log "${CLI_NAME} on PATH: $(command -v ${CLI_NAME})"
else
  BIN_DIR="$(dirname "${BIN_PATH}")"
  if [[ -x "${BIN_DIR}/${CLI_NAME}" ]]; then
    log "${CLI_NAME} found alongside server: ${BIN_DIR}/${CLI_NAME}"
  else
    warn "${CLI_NAME} not found. It's built by the same 'make build' step — preflight doctor will be less convenient without it."
  fi
fi

# 5. macOS screen-recording nudge
if [[ "$(uname -s)" == "Darwin" ]]; then
  cat <<EOF

Reminder (macOS): Screen Recording permission belongs to the process invoking
visual capture (the MCP host or flutter-mcp-toolkit). If screenshots come back blank:

  flutter-mcp-toolkit permissions status
  flutter-mcp-toolkit permissions request
  flutter-mcp-toolkit permissions open-settings

EOF
fi

log "Install verified. plugin/mcp.json resolves \${FLUTTER_MCP_BIN:-${BIN_NAME}} — set PATH or FLUTTER_MCP_BIN."
