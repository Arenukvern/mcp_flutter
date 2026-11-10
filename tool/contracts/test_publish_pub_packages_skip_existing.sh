#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PUBLISH_SCRIPT="$ROOT_DIR/tool/release/publish_pub_packages.sh"
WORKFLOW="$ROOT_DIR/.github/workflows/pub_publish.yml"

fail() { echo "test_publish_pub_packages_skip_existing: $*" >&2; exit 1; }
ok() { echo "test_publish_pub_packages_skip_existing: $*"; }

[[ -f "$PUBLISH_SCRIPT" ]] || fail "missing publish_pub_packages.sh"
[[ -f "$WORKFLOW" ]] || fail "missing pub_publish.yml"

grep -q 'package_has_version' "$PUBLISH_SCRIPT" ||
  fail "publish script must implement package_has_version"
grep -q 'skip existing' "$PUBLISH_SCRIPT" ||
  fail "publish script must log skip-existing"
grep -q 'SKIP_EXISTING=1' "$PUBLISH_SCRIPT" ||
  fail "execute path must enable skip-existing (default on --execute)"

if ! awk '
  /\$DRY_RUN" -eq 0/ { in_block=1; next }
  in_block && /SKIP_EXISTING=1/ { found=1; exit 0 }
  in_block && /^fi$/ { in_block=0 }
  END { exit found ? 0 : 1 }
' "$PUBLISH_SCRIPT"; then
  fail "--execute must set SKIP_EXISTING=1"
fi

grep -q 'curl -fsS "https://pub.dev/api/packages/' "$PUBLISH_SCRIPT" ||
  fail "package_has_version must query pub.dev API"

grep -q '\-\-skip-existing' "$WORKFLOW" ||
  fail "pub_publish workflow must pass --skip-existing"
grep -q 'workflow_dispatch:' "$WORKFLOW" ||
  fail "pub_publish must support workflow_dispatch recovery"
grep -q 'execute_publish' "$WORKFLOW" ||
  fail "pub_publish workflow_dispatch must define execute_publish input"
grep -q 'trigger_mcp_registry' "$WORKFLOW" ||
  fail "pub_publish workflow_dispatch must define trigger_mcp_registry input"
grep -q 'publish_mcp_registry.yml' "$WORKFLOW" ||
  fail "pub_publish must be able to trigger publish_mcp_registry.yml"
grep -q '\-\-ref main' "$WORKFLOW" ||
  fail "registry trigger must dispatch publish_mcp_registry on main (fixed tooling)"
grep -q 'release_tag=' "$WORKFLOW" ||
  fail "registry trigger must pass release_tag to publish_mcp_registry"

# package_has_version: exact VERSION match, not just latest.
grep -q "v\['version'\] == '\$VERSION'" "$PUBLISH_SCRIPT" ||
  fail "package_has_version must match exact VERSION on pub.dev"

ok "skip-existing and workflow recovery contracts OK"
