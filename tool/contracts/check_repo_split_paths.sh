#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

required_dirs=(
  "$ROOT_DIR/packages/core"
  "$ROOT_DIR/packages/server_capability_kernel"
  "$ROOT_DIR/packages/server_capability_core"
)

legacy_dirs=(
  "$ROOT_DIR/flutter_mcp_toolkit_core"
  "$ROOT_DIR/flutter_mcp_toolkit_capability_kernel"
  "$ROOT_DIR/flutter_mcp_toolkit_capability_core"
)

for dir in "${required_dirs[@]}"; do
  if [[ ! -d "$dir" ]]; then
    echo "Missing required package directory: $dir" >&2
    exit 1
  fi
done

for dir in "${legacy_dirs[@]}"; do
  if [[ -e "$dir" ]]; then
    echo "Legacy package directory must not exist: $dir" >&2
    exit 1
  fi
done

echo "OK: packages/ layout (core, server_capability_kernel, server_capability_core)"
