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

expect_fails_for \
  stale-hosted-version \
  "  intentcall_core: ^0.1.0" \
  "stale hosted intentcall version"

mkdir -p "${tmp}/mcp_server_dart" "${tmp}/packages"
cat > "${tmp}/mcp_toolkit/pubspec.yaml" <<YAML
name: fixture
dependencies:
  intentcall_core: ^0.6.0
YAML

cat > "${tmp}/pubspec.yaml" <<YAML
name: fixture_root
dependency_overrides:
  intentcall_session:
    path: ../agentkit/packages/intentcall_session
YAML
cat > "${tmp}/pubspec.lock" <<YAML
packages:
  intentcall_core:
    dependency: "direct main"
    description:
      name: intentcall_core
      url: "https://pub.dev"
    source: hosted
    version: "0.6.0"
YAML

if ! bash "${tmp}/tool/intentcall/check_no_path_deps.sh" >/dev/null 2>&1; then
  echo "expected default mode to allow root local overrides" >&2
  exit 1
fi

if bash "${tmp}/tool/intentcall/check_no_path_deps.sh" --strict-root >/dev/null 2>"${tmp}/strict.err"; then
  echo "expected strict-root mode to fail root local overrides" >&2
  exit 1
fi

if ! grep -q "root path override still present" "${tmp}/strict.err"; then
  echo "expected strict-root error to mention root path override" >&2
  cat "${tmp}/strict.err" >&2
  exit 1
fi

cat > "${tmp}/pubspec.yaml" <<YAML
name: fixture_root
dependencies:
  intentcall_core: ^0.1.0
YAML

if bash "${tmp}/tool/intentcall/check_no_path_deps.sh" --strict-root >/dev/null 2>"${tmp}/strict-version.err"; then
  echo "expected strict-root mode to fail stale root hosted version" >&2
  exit 1
fi

if ! grep -q "stale hosted intentcall version" "${tmp}/strict-version.err"; then
  echo "expected strict-root error to mention stale hosted version" >&2
  cat "${tmp}/strict-version.err" >&2
  exit 1
fi

echo "OK: check_no_path_deps rejects stale hosted-cutover path dependencies and versions"
