#!/usr/bin/env bash
# Compile-proof gate: Runner Generated Swift must build against intentcall_platform_apple.
#
# Canonical location for IntentCall dogfood — any maintainer with this repo + Xcode
# can run: bash tool/contracts/check_apple_runner_compile.sh
#
# Optional env:
#   INTENTCALL_ROOT  — agentkit checkout (default: ../../agentkit sibling)
#   FAIL_ON_SKIP=1   — exit 1 instead of 0 when Flutter/Xcode missing
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
app_dir="${repo_root}/flutter_test_app"
generated="${app_dir}/macos/Runner/Generated/IntentCallGenerated.swift"

skip() {
  if [[ "${FAIL_ON_SKIP:-0}" == "1" ]]; then
    echo "FAIL: $*" >&2
    exit 1
  fi
  echo "SKIP: $*"
  exit 0
}

resolve_agentkit_root() {
  local env_root="${INTENTCALL_ROOT:-}"
  if [[ -n "$env_root" ]]; then
    env_root="$(cd "$env_root" 2>/dev/null && pwd || true)"
    if [[ -n "$env_root" && -f "$env_root/packages/intentcall_cli/pubspec.yaml" ]]; then
      echo "$env_root"
      return 0
    fi
  fi

  local sibling
  sibling="$(cd "$repo_root/../agentkit" 2>/dev/null && pwd || true)"
  if [[ -n "$sibling" && -f "$sibling/packages/intentcall_cli/pubspec.yaml" ]]; then
    echo "$sibling"
    return 0
  fi

  return 1
}

if ! command -v flutter >/dev/null 2>&1; then
  skip "flutter not found in PATH"
fi

if ! command -v xcodebuild >/dev/null 2>&1 || ! xcodebuild -version >/dev/null 2>&1; then
  skip "Xcode toolchain not available"
fi

if [[ ! -f "${generated}" ]]; then
  echo "missing ${generated}; will run platform sync first" >&2
fi

echo "== apple runner compile (macos --config-only) =="
echo "mcp_flutter test app: ${app_dir}"

if AGENTKIT_ROOT="$(resolve_agentkit_root)"; then
  echo "intentcall CLI: ${AGENTKIT_ROOT}/packages/intentcall_cli"
  cd "${AGENTKIT_ROOT}"
  dart run intentcall_cli:intentcall platform sync \
    --project-dir "${app_dir}" \
    --platform ios,macos
else
  echo "WARN: agentkit sibling not found — using committed generated Swift only" >&2
  echo "      set INTENTCALL_ROOT or clone ../agentkit to sync before compile" >&2
fi

if ! grep -q 'import intentcall_platform_apple' "${generated}"; then
  echo "IntentCallGenerated.swift missing import intentcall_platform_apple" >&2
  exit 1
fi

if grep -q 'enum IntentCallNativeBridge {' "${generated}"; then
  echo "IntentCallGenerated.swift must not define IntentCallNativeBridge (use plugin facade)" >&2
  exit 1
fi

cd "${app_dir}"
flutter pub get
flutter build macos --config-only

echo "OK: apple runner compile gate"
