#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PUBLISH_SCRIPT="$ROOT_DIR/tool/release/publish_pub_packages.sh"
PUB_WORKFLOW="$ROOT_DIR/.github/workflows/dart_changesets_publish.yml"
RELEASE_WORKFLOW="$ROOT_DIR/.github/workflows/release.yml"

fail() { echo "test_publish_pub_packages_skip_existing: $*" >&2; exit 1; }
ok() { echo "test_publish_pub_packages_skip_existing: $*"; }

[[ -f "$PUBLISH_SCRIPT" ]] || fail "missing publish_pub_packages.sh"
[[ -f "$PUB_WORKFLOW" ]] || fail "missing dart_changesets_publish.yml"
[[ -f "$RELEASE_WORKFLOW" ]] || fail "missing release.yml"

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

grep -q 'Arenukvern/dart_changesets/.github/workflows/publish.yml' "$PUB_WORKFLOW" ||
  fail "dart_changesets publish must call reusable engine publish workflow"
grep -q 'workflow_dispatch:' "$PUB_WORKFLOW" ||
  fail "dart_changesets publish must support workflow_dispatch recovery"
grep -q 'execute:' "$PUB_WORKFLOW" ||
  fail "dart_changesets publish workflow_dispatch must define execute input"
grep -q 'publish_mcp_registry.yml' "$RELEASE_WORKFLOW" ||
  fail "release.yml must trigger publish_mcp_registry.yml after root v* release"
grep -q '\-\-ref main' "$RELEASE_WORKFLOW" ||
  fail "registry trigger must dispatch publish_mcp_registry on main (fixed tooling)"
grep -q 'release_tag=' "$RELEASE_WORKFLOW" ||
  fail "registry trigger must pass release_tag to publish_mcp_registry"

grep -q "v\['version'\] == '\$VERSION'" "$PUBLISH_SCRIPT" ||
  fail "package_has_version must match exact VERSION on pub.dev"

ok "skip-existing and workflow recovery contracts OK"