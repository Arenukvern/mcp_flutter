#!/usr/bin/env bash
# Three-gate IntentCall CI recipe for the Jaspr web example.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
example="${repo_root}/jaspr_web_example"
server="${repo_root}/mcp_server_dart"
cd "${server}"

if [[ ! -d "${example}" ]]; then
  echo "missing jaspr_web_example at ${example}" >&2
  exit 1
fi

intentcall() {
  dart run intentcall_cli:intentcall "$@"
}

echo "== jaspr three-gate: hook presence =="
if ! intentcall platform hooks init --host jaspr --check --project-dir "${example}"; then
  intentcall platform hooks init --host jaspr --project-dir "${example}"
fi

echo "== jaspr three-gate: manifest export --check =="
intentcall manifest export --check --project-dir "${example}"

echo "== jaspr three-gate: platform sync --check =="
intentcall platform sync --platform web --check --project-dir "${example}"

echo "OK: jaspr three-gate CI recipe"
