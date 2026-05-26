#!/usr/bin/env bash
# Publish agentkit packages to pub.dev in dependency order.
# Default: --dry-run only. Pass --execute to publish (requires pub credentials).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
agentkit_root="${AGENTKIT_ROOT:-${repo_root}/agentkit}"
dry_run=true

usage() {
  cat <<'EOF'
Usage: tool/agentkit/publish_all.sh [--execute]

Publishes packages in order (schema → core → adapters → platform → testing).
Without --execute, runs `dart pub publish --dry-run` only.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute) dry_run=false; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown: $1" >&2; usage >&2; exit 64 ;;
  esac
done

publish_order=(
  agentkit_schema
  agentkit_core
  agentkit_mcp
  agentkit_webmcp
  agentkit_gemma
  agentkit_apple
  agentkit_android
  agentkit_codegen
  agentkit_platform
  agentkit_testing
)

cd "${agentkit_root}"
dart pub get

for pkg in "${publish_order[@]}"; do
  dir="${agentkit_root}/packages/${pkg}"
  echo "== ${pkg} =="
  if [[ "${pkg}" == "agentkit_platform" ]]; then
    if [[ "${dry_run}" == true ]]; then
      (cd "${dir}" && flutter pub publish --dry-run)
    else
      (cd "${dir}" && flutter pub publish --force)
    fi
  elif [[ "${dry_run}" == true ]]; then
    (cd "${dir}" && dart pub publish --dry-run)
  else
    (cd "${dir}" && dart pub publish --force)
  fi
done

echo "OK: publish_all complete (dry_run=${dry_run})"
