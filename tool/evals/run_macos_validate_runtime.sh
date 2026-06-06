#!/usr/bin/env bash
# macOS validate-runtime helper (I5). Requires showcase running with VM service URI.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
toolkit=(dart run "${repo_root}/mcp_server_dart/bin/flutter_mcp_toolkit.dart")

ws_uri="${MACOS_WS_URI:-${WS_URI:-}}"
timeout_ms="${TIMEOUT_MS:-45000}"

if [[ -z "${ws_uri}" ]]; then
  echo "Set MACOS_WS_URI or WS_URI to the macOS VM websocket (make showcase)." >&2
  exit 64
fi

"${toolkit[@]}" validate-runtime \
  --target "${ws_uri}" \
  --timeout-ms "${timeout_ms}" \
  --output-dir "${repo_root}/.showcase/macos_validate_runtime"

echo "OK: macOS validate-runtime"
