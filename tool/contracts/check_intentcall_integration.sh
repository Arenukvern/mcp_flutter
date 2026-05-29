#!/usr/bin/env bash
# Full in-repo intentcall integration gate (I2).
# Wired into: make check-intentcall-integration, .github/workflows/intentcall_eval.yml
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
if [[ -n "${INTENTCALL_ROOT:-}" ]]; then
  intentcall_root="${INTENTCALL_ROOT}"
elif [[ -d "${repo_root}/../intentcall/packages/intentcall_core" ]]; then
  intentcall_root="${repo_root}/../intentcall"
elif [[ -d "${repo_root}/../agentkit/packages/intentcall_core" ]]; then
  intentcall_root="${repo_root}/../agentkit"
elif [[ -d "${repo_root}/intentcall/packages/intentcall_core" ]]; then
  intentcall_root="${repo_root}/intentcall"
else
  intentcall_root="${repo_root}/intentcall"
fi
cd "${repo_root}"

if [[ ! -d "${intentcall_root}/packages/intentcall_core" ]]; then
  echo "intentcall monorepo missing at ${intentcall_root} (clone sibling or set INTENTCALL_ROOT)" >&2
  exit 1
fi

echo "== intentcall package matrix (${intentcall_root}) =="
(
  cd "${intentcall_root}"
  make test
)
dart test packages/server_capability_kernel packages/server_capability_core

echo "== mcp_server_dart =="
(
  cd mcp_server_dart
  dart test
  dart test test/contract/
)

echo "== intentcall contracts =="
bash tool/contracts/check_intentcall_skills_grep.sh

echo "== migrate / init / codegen --check =="
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart migrate agent-entries \
  --check flutter_test_app/lib
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart init intentcall-platform \
  --check --project-dir flutter_test_app
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart codegen sync \
  --platform web,android,ios,macos,linux,windows \
  --project-dir flutter_test_app --check

echo "OK: intentcall integration gate"
