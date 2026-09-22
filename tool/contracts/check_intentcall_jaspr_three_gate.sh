#!/usr/bin/env bash
# Three-gate IntentCall CI recipe for the Jaspr web example.
# Invokes the sibling IntentCall CLI directly so this check does not
# pub-solve the Flutter workspace.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
example="${repo_root}/jaspr_web_example"

if [[ -n "${INTENTCALL_ROOT:-}" ]]; then
  intentcall_root="${INTENTCALL_ROOT}"
elif [[ -d "${repo_root}/../intentcall/packages/intentcall_cli" ]]; then
  intentcall_root="${repo_root}/../intentcall"
elif [[ -d "${repo_root}/../agentkit/packages/intentcall_cli" ]]; then
  intentcall_root="${repo_root}/../agentkit"
else
  echo "intentcall checkout missing (set INTENTCALL_ROOT or clone ../intentcall)" >&2
  exit 1
fi

cli="${intentcall_root}/packages/intentcall_cli"
if [[ ! -d "${example}" ]]; then
  echo "missing jaspr_web_example at ${example}" >&2
  exit 1
fi

intentcall() {
  (cd "${cli}" && dart bin/intentcall.dart "$@")
}

echo "== jaspr three-gate: hook presence (${intentcall_root}) =="
if ! intentcall platform hooks init --host jaspr --check --project-dir "${example}"; then
  intentcall platform hooks init --host jaspr --project-dir "${example}"
fi

echo "== jaspr three-gate: manifest export --check =="
intentcall manifest export --check --project-dir "${example}"

echo "== jaspr three-gate: platform sync --check =="
intentcall platform sync --platform web --check --project-dir "${example}"

echo "OK: jaspr three-gate CI recipe"
