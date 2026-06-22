#!/usr/bin/env bash
# Fails if committed consumer pubspecs still use local intentcall path deps.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
cd "${repo_root}"

strict_root=false

usage() {
  cat <<'EOF'
Usage: tool/intentcall/check_no_path_deps.sh [--strict-root]

Default mode scans committed consumer packages and allows root dependency_overrides
used for deliberate local sibling development.

--strict-root additionally scans the root pubspec and lockfile. Use it before
publishing release/cutover changes that must not rely on local IntentCall paths.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict-root) strict_root=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown: $1" >&2; usage >&2; exit 64 ;;
  esac
done

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

if [[ "${strict_root}" == true ]]; then
  for f in pubspec.yaml pubspec.lock; do
    if [[ -f "${f}" ]] && grep -nE "${patterns}" "$f" >"${matches_file}" 2>/dev/null; then
      echo "root path override still present: $f" >&2
      echo "matched release-blocking path pattern: agentkit/packages | intentcall/packages | path: .*intentcall" >&2
      cat "${matches_file}" >&2
      found=1
    fi
  done
fi

if [[ "${found}" -ne 0 ]]; then
  echo "FAIL: use hosted intentcall deps for committed consumer state (see docs/intentcall/README.md)" >&2
  exit 1
fi

if [[ "${strict_root}" == true ]]; then
  echo "OK: no intentcall path deps in consumers or root release state"
else
  echo "OK: no intentcall path deps in committed consumers (root local overrides not checked; run --strict-root before release/cutover)"
fi
