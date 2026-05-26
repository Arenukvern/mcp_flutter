#!/usr/bin/env bash
# Fails if consumer pubspecs still use path: agentkit (Phase 7.7 gate after hosted cutover).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"

found=0
while IFS= read -r -d '' f; do
  if grep -q 'agentkit/packages' "$f" 2>/dev/null; then
    echo "path dep still present: $f" >&2
    grep 'agentkit/packages' "$f" >&2 || true
    found=1
  fi
done < <(find mcp_toolkit mcp_server_dart packages flutter_test_app -name pubspec.yaml -print0 2>/dev/null)

if [[ "${found}" -ne 0 ]]; then
  echo "FAIL: migrate to hosted agentkit deps (see docs/agentkit/hosted_cutover.md)" >&2
  exit 1
fi

echo "OK: no agentkit path deps in consumers"
