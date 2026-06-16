#!/usr/bin/env bash
# Fails if consumer pubspecs still use local intentcall path deps
# (Phase 7.7 gate after hosted cutover).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"

found=0
patterns='agentkit/packages|intentcall/packages|path:[[:space:]]*.*intentcall'
matches_file="$(mktemp)"
trap 'rm -f "${matches_file}"' EXIT
while IFS= read -r -d '' f; do
  if grep -nE "${patterns}" "$f" >"${matches_file}" 2>/dev/null; then
    echo "path dep still present: $f" >&2
    echo "matched stale path pattern: agentkit/packages | intentcall/packages | path: .*intentcall" >&2
    cat "${matches_file}" >&2
    found=1
  fi
done < <(find mcp_toolkit mcp_server_dart packages flutter_test_app -name pubspec.yaml -print0 2>/dev/null)

if [[ "${found}" -ne 0 ]]; then
  echo "FAIL: use hosted intentcall deps for committed consumer state (see docs/intentcall/README.md)" >&2
  exit 1
fi

echo "OK: no intentcall path deps in consumers"
