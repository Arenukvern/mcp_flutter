#!/usr/bin/env bash
# Hosted IntentCall consumer gate for mcp_flutter.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"

echo "== hosted intentcall dependency policy =="
bash tool/intentcall/check_no_path_deps.sh --strict-root

echo "== intentcall migration and generated-platform drift =="
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart migrate agent-entries \
  --check flutter_test_app/lib
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart init intentcall-platform \
  --check --project-dir flutter_test_app
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart codegen sync \
  --platform web,android,ios,macos,linux,windows \
  --project-dir flutter_test_app --check

echo "== intentcall skill/doc contract =="
bash tool/contracts/check_intentcall_skills_grep.sh

echo "OK: hosted intentcall consumer gate"
