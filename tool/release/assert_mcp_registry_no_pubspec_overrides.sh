#!/usr/bin/env bash
# Fail when mcp_server_dart/pubspec_overrides.yaml is present — production
# registry images must resolve hosted siblings on pub.dev only.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
override="${ROOT_DIR}/mcp_server_dart/pubspec_overrides.yaml"

if [[ -f "$override" ]]; then
  echo "assert_mcp_registry_no_pubspec_overrides: refusing build — $override exists (hosted-only)" >&2
  exit 1
fi

echo "assert_mcp_registry_no_pubspec_overrides: no pubspec_overrides.yaml (hosted resolution)"
