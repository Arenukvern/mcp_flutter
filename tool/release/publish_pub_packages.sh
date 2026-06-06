#!/usr/bin/env bash
# Publish Flutter MCP Toolkit pub.dev packages in dependency order.
#
# Default is a release preflight that avoids mutating pub.dev. Pass --execute to
# publish. The execute path performs a full dry-run immediately before each
# package publish, publishes, then waits for pub.dev to expose that version
# before moving to dependents.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
WAIT_SECONDS="${PUB_PUBLISH_WAIT_SECONDS:-300}"
DRY_RUN=1
SKIP_EXISTING=0

usage() {
  cat <<USAGE
Usage: tool/release/publish_pub_packages.sh [--execute] [--skip-existing]

Publishes packages in dependency order:
  1. flutter_mcp_toolkit_core
  2. flutter_mcp_toolkit_capability_kernel
  3. flutter_mcp_toolkit_capability_core
  4. mcp_toolkit

Default: preflight only. Preflight uses --skip-validation for packages whose
same-train dependencies are not yet visible on pub.dev; full validation happens
during --execute after each upstream package has been published and observed.
USAGE
}

fail() {
  echo "publish_pub_packages: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute)
      DRY_RUN=0
      shift
      ;;
    --skip-existing)
      SKIP_EXISTING=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

packages=(
  "flutter_mcp_toolkit_core|packages/core|dart"
  "flutter_mcp_toolkit_capability_kernel|packages/server_capability_kernel|dart"
  "flutter_mcp_toolkit_capability_core|packages/server_capability_core|dart"
  "mcp_toolkit|mcp_toolkit|flutter"
)

package_has_version() {
  local package="$1"
  curl -fsS "https://pub.dev/api/packages/$package" |
    ruby -rjson -e "j=JSON.parse(STDIN.read); exit(j.fetch('versions').any? { |v| v['version'] == '$VERSION' } ? 0 : 1)"
}

wait_for_pub_version() {
  local package="$1"
  local deadline=$((SECONDS + WAIT_SECONDS))
  while (( SECONDS < deadline )); do
    if package_has_version "$package"; then
      echo "publish_pub_packages: pub.dev exposes $package $VERSION"
      return 0
    fi
    sleep 10
  done
  fail "timed out waiting for $package $VERSION on pub.dev"
}

run_pub() {
  local runner="$1"
  local args=("${@:2}")
  if [[ "$runner" == "flutter" ]]; then
    flutter pub publish "${args[@]}"
  else
    dart pub publish "${args[@]}"
  fi
}

check_package_static() {
  local package="$1"
  local dir="$2"
  local pubspec="$ROOT_DIR/$dir/pubspec.yaml"
  local changelog="$ROOT_DIR/$dir/CHANGELOG.md"

  [[ -f "$pubspec" ]] || fail "missing $dir/pubspec.yaml"
  if grep -qE '^publish_to:[[:space:]]*none\\b' "$pubspec"; then
    fail "$dir is marked publish_to: none"
  fi
  if ! grep -qE "^version:[[:space:]]*$VERSION([[:space:]#]|\$)" "$pubspec"; then
    fail "$dir version does not match VERSION $VERSION"
  fi
  if grep -Eq '^[[:space:]]*(path|git):[[:space:]]' "$pubspec"; then
    fail "$dir/pubspec.yaml contains path/git dependency"
  fi
  [[ -f "$changelog" ]] || fail "missing $dir/CHANGELOG.md"
  if ! grep -Eq "(^#\\s+$VERSION\\b|^##\\s+\\[$VERSION\\]|^##\\s+$VERSION\\b)" "$changelog"; then
    fail "$dir/CHANGELOG.md has no entry for $VERSION"
  fi
  echo "publish_pub_packages: static checks OK for $package"
}

"$ROOT_DIR/tool/release/assert_release_tag.sh" "v$VERSION" >/dev/null
"$ROOT_DIR/tool/contracts/check_version_sync.sh"

for entry in "${packages[@]}"; do
  IFS='|' read -r package dir runner <<<"$entry"
  check_package_static "$package" "$dir"
done

for entry in "${packages[@]}"; do
  IFS='|' read -r package dir runner <<<"$entry"
  echo "== $package $VERSION ($dir) =="

  if [[ "$SKIP_EXISTING" -eq 1 ]] && package_has_version "$package"; then
    echo "publish_pub_packages: skip existing $package $VERSION"
    continue
  fi

  (
    cd "$ROOT_DIR/$dir"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      run_pub "$runner" --dry-run --skip-validation
    else
      run_pub "$runner" --dry-run
      run_pub "$runner" --force
    fi
  )

  if [[ "$DRY_RUN" -eq 0 ]]; then
    wait_for_pub_version "$package"
  fi
done

echo "publish_pub_packages: complete (execute=$((1 - DRY_RUN)), version=$VERSION)"
