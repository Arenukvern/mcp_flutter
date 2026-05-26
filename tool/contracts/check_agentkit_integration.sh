#!/usr/bin/env bash
# Full in-repo agentkit integration gate (I2).
# Wired into: make check-agentkit-integration, .github/workflows/agentkit_eval.yml
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
agentkit_root="${AGENTKIT_ROOT:-${repo_root}/agentkit}"
cd "${repo_root}"

if [[ ! -d "${agentkit_root}/packages/agentkit_core" ]]; then
  echo "agentkit monorepo missing at ${agentkit_root} (clone sibling or set AGENTKIT_ROOT)" >&2
  exit 1
fi

echo "== agentkit package matrix (${agentkit_root}) =="
(
  cd "${agentkit_root}"
  make test
)
dart test packages/server_capability_kernel packages/server_capability_core

echo "== mcp_server_dart =="
(
  cd mcp_server_dart
  dart test
  dart test test/contract/
)

echo "== agentkit contracts =="
bash tool/contracts/check_agentkit_skills_grep.sh

echo "== migrate / init / codegen --check =="
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart migrate agent-entries \
  --check flutter_test_app/lib
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart init agentkit-platform \
  --check --project-dir flutter_test_app
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart codegen sync \
  --platform web,android,ios,macos,linux,windows \
  --project-dir flutter_test_app --check

echo "OK: agentkit integration gate"
