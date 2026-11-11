#!/usr/bin/env bash
# Prepare docker build context for MCP Registry Dockerfile smoke builds.
# Tries hosted pub.dev resolution first; when a pinned sibling train version is
# not yet published, assembles a temp context with path overrides (never
# written into the git checkout).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVER_PUBSPEC="${MCP_REGISTRY_SERVER_PUBSPEC:-$ROOT_DIR/mcp_server_dart/pubspec.yaml}"
OUTPUT_DIR="${MCP_REGISTRY_SMOKE_OUTPUT:-${RUNNER_TEMP:-/tmp}/mcp_registry_smoke_ctx}"
GITHUB_OUTPUT="${GITHUB_OUTPUT:-}"

fail() {
  echo "prepare_mcp_registry_smoke_build: $*" >&2
  exit 1
}

log_mode() {
  echo "prepare_mcp_registry_smoke_build: resolution_mode=$1"
}

[[ -f "$SERVER_PUBSPEC" ]] || fail "missing server pubspec: $SERVER_PUBSPEC"

read_sibling_requirements() {
  export SERVER_PUBSPEC
  python3 <<'PY'
import os
import sys

try:
    import yaml
except ImportError:
    sys.exit("prepare_mcp_registry_smoke_build: python3 PyYAML required")

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

pub_dev_has_version() {
  local package="$1"
  local version="$2"
  curl -fsS "https://pub.dev/api/packages/${package}" 2>/dev/null |
    python3 -c "import json,sys; j=json.load(sys.stdin); sys.exit(0 if any(v['version']=='${version}' for v in j.get('versions',[])) else 1)" \
    2>/dev/null
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
    echo "prepare_mcp_registry_smoke_build: pub.dev has ${pkg} ${ver}"
  else
    echo "prepare_mcp_registry_smoke_build: pub.dev missing ${pkg} ${ver} (pre-release train)"
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

[[ -f "$ROOT_DIR/pubspec_overrides.yaml" ]] && \
  fail "refusing to run while repo root pubspec_overrides.yaml exists (use a clean checkout)"

if [[ -n "$GITHUB_OUTPUT" ]]; then
  {
    echo "resolution_mode=workspace_fallback"
    printf 'docker_context=%s\n' "$OUTPUT_DIR"
  } >>"$GITHUB_OUTPUT"
fi
