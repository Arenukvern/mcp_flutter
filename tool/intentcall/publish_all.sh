#!/usr/bin/env bash
# Publish intentcall packages to pub.dev in dependency order.
# Default: --dry-run only. Pass --execute to publish (requires pub credentials).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
if [[ -n "${INTENTCALL_ROOT:-}" ]]; then
  intentcall_root="${INTENTCALL_ROOT}"
elif [[ -d "${repo_root}/../agentkit/packages/intentcall_core" ]]; then
  intentcall_root="${repo_root}/../agentkit"
elif [[ -d "${repo_root}/intentcall/packages/intentcall_core" ]]; then
  intentcall_root="${repo_root}/intentcall"
else
  echo "intentcall workspace not found (clone ../agentkit sibling or set INTENTCALL_ROOT)" >&2
  exit 1
fi
dry_run=true

usage() {
  cat <<'EOF'
Usage: tool/intentcall/publish_all.sh [--execute]

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
  intentcall_schema
  intentcall_core
  intentcall_mcp
  intentcall_webmcp
  intentcall_gemma
  intentcall_apple
  intentcall_android
  intentcall_codegen
  intentcall_platform
  intentcall_testing
)

cd "${intentcall_root}"
dart pub get

for pkg in "${publish_order[@]}"; do
  dir="${intentcall_root}/packages/${pkg}"
  echo "== ${pkg} =="
  if [[ "${pkg}" == "intentcall_platform" ]]; then
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
