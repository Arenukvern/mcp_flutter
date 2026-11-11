#!/usr/bin/env bash
# Prepare docker build context for MCP Registry Dockerfile smoke builds.
# Tries hosted pub.dev resolution first; when a pinned sibling train version is
# not yet published, assembles a temp context with path overrides (never
# written into the git checkout).
#
# Runtime (ubuntu-latest smoke / local):
#   - python3 + PyYAML (package python3-yaml on Debian/Ubuntu images)
#   - curl when MCP_REGISTRY_PUB_API_BASE is an https URL (default pub.dev)
#
# Contract tests set MCP_REGISTRY_PUB_API_BASE to
# tool/contracts/fixtures/mcp_registry_pub_api (offline JSON per package).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVER_PUBSPEC="${MCP_REGISTRY_SERVER_PUBSPEC:-$ROOT_DIR/mcp_server_dart/pubspec.yaml}"
OUTPUT_DIR="${MCP_REGISTRY_SMOKE_OUTPUT:-${RUNNER_TEMP:-/tmp}/mcp_registry_smoke_ctx}"
GITHUB_OUTPUT="${GITHUB_OUTPUT:-}"
PUB_API_BASE="${MCP_REGISTRY_PUB_API_BASE:-https://pub.dev/api/packages}"

fail() {
  echo "prepare_mcp_registry_smoke_build: $*" >&2
  exit 1
}

log_mode() {
  echo "prepare_mcp_registry_smoke_build: resolution_mode=$1"
}

normalize_pub_api_base() {
  case "$PUB_API_BASE" in
    file://*) PUB_API_BASE="${PUB_API_BASE#file://}" ;;
  esac
}

[[ -f "$SERVER_PUBSPEC" ]] || fail "missing server pubspec: $SERVER_PUBSPEC"
normalize_pub_api_base

read_sibling_requirements() {
  export SERVER_PUBSPEC
  python3 <<'PY'
import os
import sys

try:
    import yaml
except ImportError:
    sys.exit(
        "prepare_mcp_registry_smoke_build: python3 PyYAML required "
        "(install python3-yaml on ubuntu-latest)"
    )

path = os.environ["SERVER_PUBSPEC"]
with open(path, encoding="utf-8") as f:
    doc = yaml.safe_load(f)
deps = doc.get("dependencies") or {}
names = [
    "flutter_mcp_toolkit_core",
    "flutter_mcp_toolkit_capability_kernel",
    "flutter_mcp_toolkit_capability_core",
]
for name in names:
    raw = deps.get(name)
    if not isinstance(raw, str) or not raw.startswith("^"):
        sys.exit(
            f"prepare: {path} must pin {name} with hosted constraint (got {raw!r})"
        )
    print(f"{name}|{raw[1:]}")
PY
}

fetch_package_index_json() {
  local package="$1"
  local dest="$2"
  if [[ "$PUB_API_BASE" =~ ^https?:// ]]; then
    local code
    code="$(curl -sS -o "$dest" -w '%{http_code}' "${PUB_API_BASE%/}/${package}" || true)"
    if [[ "$code" == "404" ]]; then
      fail "pub.dev package not found: ${package} (HTTP 404)"
    fi
    if [[ "$code" != "200" ]]; then
      fail "pub.dev API error for ${package}: HTTP ${code}"
    fi
    return 0
  fi
  local fixture="${PUB_API_BASE%/}/${package}.json"
  [[ -f "$fixture" ]] || fail "pub API fixture missing for ${package}: ${fixture}"
  cp "$fixture" "$dest"
}

pub_dev_has_version() {
  local package="$1"
  local version="$2"
  local body_file
  body_file="$(mktemp)"
  fetch_package_index_json "$package" "$body_file"
  local py_rc=0
  BODY_FILE="$body_file" PUB_PKG="$package" PUB_VER="$version" python3 <<'PY' || py_rc=$?
import json, os, sys

try:
    with open(os.environ["BODY_FILE"], encoding="utf-8") as f:
        j = json.load(f)
except json.JSONDecodeError as exc:
    print(
        "prepare_mcp_registry_smoke_build: invalid JSON for "
        + os.environ["PUB_PKG"]
        + ": "
        + str(exc),
        file=sys.stderr,
    )
    sys.exit(3)
vers = j.get("versions") or []
if not isinstance(vers, list):
    print(
        "prepare_mcp_registry_smoke_build: invalid versions list for "
        + os.environ["PUB_PKG"],
        file=sys.stderr,
    )
    sys.exit(3)
has = any(
    isinstance(v, dict) and v.get("version") == os.environ["PUB_VER"] for v in vers
)
sys.exit(0 if has else 1)
PY
  rm -f "$body_file"
  if [[ "$py_rc" -eq 0 ]]; then
    return 0
  fi
  if [[ "$py_rc" -eq 1 ]]; then
    return 1
  fi
  fail "pub index parse/query failed for ${package} (python exit ${py_rc})"
}

strip_workspace_resolution() {
  local pubspec="$1"
  [[ -f "$pubspec" ]] || return 0
  sed -i '/^resolution: workspace/d' "$pubspec"
}

copy_tree() {
  local src="$1"
  local dest="$2"
  mkdir -p "$dest"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --exclude '.dart_tool' --exclude 'build' "$src/" "$dest/"
  else
    cp -a "$src/." "$dest/"
    rm -rf "$dest/.dart_tool" "$dest/build" 2>/dev/null || true
  fi
}

needs_fallback=0
while IFS='|' read -r pkg ver; do
  [[ -z "$pkg" ]] && continue
  if pub_dev_has_version "$pkg" "$ver"; then
    echo "prepare_mcp_registry_smoke_build: pub index has ${pkg} ${ver}"
  else
    echo "prepare_mcp_registry_smoke_build: pub index missing ${pkg} ${ver} (pre-release train)"
    needs_fallback=1
  fi
done < <(read_sibling_requirements)

if [[ "$needs_fallback" -eq 0 ]]; then
  log_mode hosted
  if [[ -n "$GITHUB_OUTPUT" ]]; then
    {
      echo "resolution_mode=hosted"
      echo "docker_context=."
    } >>"$GITHUB_OUTPUT"
  fi
  exit 0
fi

log_mode workspace_fallback
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/mcp_server_dart" \
  "$OUTPUT_DIR/packages/core" \
  "$OUTPUT_DIR/packages/server_capability_kernel" \
  "$OUTPUT_DIR/packages/server_capability_core"

copy_tree "$ROOT_DIR/mcp_server_dart" "$OUTPUT_DIR/mcp_server_dart"
copy_tree "$ROOT_DIR/packages/core" "$OUTPUT_DIR/packages/core"
copy_tree "$ROOT_DIR/packages/server_capability_kernel" "$OUTPUT_DIR/packages/server_capability_kernel"
copy_tree "$ROOT_DIR/packages/server_capability_core" "$OUTPUT_DIR/packages/server_capability_core"

strip_workspace_resolution "$OUTPUT_DIR/mcp_server_dart/pubspec.yaml"
strip_workspace_resolution "$OUTPUT_DIR/packages/core/pubspec.yaml"
strip_workspace_resolution "$OUTPUT_DIR/packages/server_capability_kernel/pubspec.yaml"
strip_workspace_resolution "$OUTPUT_DIR/packages/server_capability_core/pubspec.yaml"

cat >"$OUTPUT_DIR/mcp_server_dart/pubspec_overrides.yaml" <<'YAML'
# GENERATED: MCP Registry smoke build (ephemeral docker context only).
dependency_overrides:
  flutter_mcp_toolkit_core:
    path: ../packages/core
  flutter_mcp_toolkit_capability_kernel:
    path: ../packages/server_capability_kernel
  flutter_mcp_toolkit_capability_core:
    path: ../packages/server_capability_core
YAML

if [[ -n "$GITHUB_OUTPUT" ]]; then
  {
    echo "resolution_mode=workspace_fallback"
    printf 'docker_context=%s\n' "$OUTPUT_DIR"
  } >>"$GITHUB_OUTPUT"
fi
