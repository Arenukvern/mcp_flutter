#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MINT_SCRIPT="$ROOT_DIR/tool/release/mint_pub_dev_oidc_token.sh"
PUBLISH_SCRIPT="$ROOT_DIR/tool/release/publish_pub_packages.sh"

fail() { echo "test_publish_pub_packages_oidc: $*" >&2; exit 1; }
ok() { echo "test_publish_pub_packages_oidc: $*"; }

[[ -f "$MINT_SCRIPT" ]] || fail "missing mint_pub_dev_oidc_token.sh"
[[ -f "$PUBLISH_SCRIPT" ]] || fail "missing publish_pub_packages.sh"

grep -q 'mint_pub_dev_oidc_token' "$PUBLISH_SCRIPT" ||
  fail "publish_pub_packages.sh must call mint_pub_dev_oidc_token"
grep -q 'audience=https://pub.dev' "$MINT_SCRIPT" ||
  fail "mint script must request pub.dev OIDC audience"

set +e
out="$(env -u ACTIONS_ID_TOKEN_REQUEST_URL -u ACTIONS_ID_TOKEN_REQUEST_TOKEN \
  bash -c '
    set -euo pipefail
    fail() { echo "publish_pub_packages: $*" >&2; exit 1; }
    # shellcheck source=/dev/null
    source "'"$MINT_SCRIPT"'"
    mint_pub_dev_oidc_token
  ' 2>&1)"
code=$?
set -e

if [[ "$code" -eq 0 ]]; then
  fail "mint must fail when OIDC env vars are unset"
fi
if ! printf '%s' "$out" | grep -q 'ACTIONS_ID_TOKEN_REQUEST_URL'; then
  fail "expected clear error for missing ACTIONS_ID_TOKEN_REQUEST_URL: $out"
fi
ok "rejects missing OIDC env"

ok "publish pub OIDC contract OK"
