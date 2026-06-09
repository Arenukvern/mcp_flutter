#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="${repo_root}/tool/intentcall/check_no_path_deps.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

mkdir -p "${tmp}/tool/intentcall" "${tmp}/mcp_toolkit"
cp "${script}" "${tmp}/tool/intentcall/check_no_path_deps.sh"

expect_fails_for() {
  local label="$1"
  local dependency_yaml="$2"
  local expected="$3"
  local out="${tmp}/${label}.out"
  local err="${tmp}/${label}.err"

  cat > "${tmp}/mcp_toolkit/pubspec.yaml" <<YAML
name: fixture
dependencies:
${dependency_yaml}
YAML

  if bash "${tmp}/tool/intentcall/check_no_path_deps.sh" >"${out}" 2>"${err}"; then
    echo "expected ${label} path dependency to fail" >&2
    cat "${out}" >&2
    cat "${err}" >&2
    exit 1
  fi

  if ! grep -q "${expected}" "${err}"; then
    echo "expected ${label} error to mention ${expected}" >&2
    cat "${err}" >&2
    exit 1
  fi
}

expect_fails_for \
  agentkit \
  "  intentcall_core:
    path: ../agentkit/packages/intentcall_core" \
  "agentkit/packages"

expect_fails_for \
  generic-intentcall \
  "  intentcall_schema:
    path: ../third_party/intentcall_schema" \
  "path: .*intentcall"

echo "OK: check_no_path_deps rejects stale hosted-cutover path dependencies"
