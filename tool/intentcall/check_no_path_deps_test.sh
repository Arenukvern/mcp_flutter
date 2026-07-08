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
    echo "expected ${label} dependency to fail" >&2
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
  hosted \
  "  intentcall_core: ^0.6.0" \
  "hosted intentcall dependency"

expect_fails_for \
  wrong-path \
  "  intentcall_schema:
    path: ../third_party/intentcall_schema" \
  "unexpected intentcall path dependency"

mkdir -p "${tmp}/mcp_toolkit"
cat > "${tmp}/mcp_toolkit/pubspec.yaml" <<YAML
name: fixture
dependencies:
  intentcall_core:
    path: ../../agentkit/packages/intentcall_core
YAML

if ! bash "${tmp}/tool/intentcall/check_no_path_deps.sh" >/dev/null 2>&1; then
  echo "expected valid agentkit path dependency to pass" >&2
  exit 1
fi

echo "OK: check_no_path_deps requires sibling agentkit intentcall path dependencies"
