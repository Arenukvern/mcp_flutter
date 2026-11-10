#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MINT_SCRIPT="$ROOT_DIR/tool/release/mint_pub_dev_oidc_token.sh"
PUBLISH_SCRIPT="$ROOT_DIR/tool/release/publish_pub_packages.sh"
WORKFLOW="$ROOT_DIR/.github/workflows/pub_publish.yml"

fail() { echo "test_publish_pub_packages_oidc: $*" >&2; exit 1; }
ok() { echo "test_publish_pub_packages_oidc: $*"; }

[[ -f "$MINT_SCRIPT" ]] || fail "missing mint_pub_dev_oidc_token.sh"
[[ -f "$PUBLISH_SCRIPT" ]] || fail "missing publish_pub_packages.sh"
[[ -f "$WORKFLOW" ]] || fail "missing pub_publish.yml"

grep -q 'mint_pub_dev_oidc_token' "$PUBLISH_SCRIPT" ||
  fail "publish_pub_packages.sh must call mint_pub_dev_oidc_token"

# Execute path: mint immediately before --force inside the per-package subshell.
execute_tail="$(
  awk '
    /\[\[ "\$DRY_RUN" -eq 1 \]\]; then/ { mode="dry"; next }
    mode=="dry" && /^[[:space:]]*else$/ { mode="exec"; next }
    mode=="exec" {
      print
      if (/^[[:space:]]*fi$/) exit
    }
  ' "$PUBLISH_SCRIPT"
)"
printf '%s\n' "$execute_tail" | grep -q 'run_pub.*--dry-run' ||
  fail "execute path must run --dry-run before mint"
mint_line="$(printf '%s\n' "$execute_tail" | grep -n 'mint_pub_dev_oidc_token' | head -1 | cut -d: -f1)"
dry_line="$(printf '%s\n' "$execute_tail" | grep -n 'run_pub.*--dry-run' | head -1 | cut -d: -f1)"
force_line="$(printf '%s\n' "$execute_tail" | grep -n 'run_pub.*--force' | head -1 | cut -d: -f1)"
[[ -n "$mint_line" && -n "$dry_line" && -n "$force_line" ]] ||
  fail "execute path must include --dry-run, mint, and --force"
if [[ "$dry_line" -ge "$mint_line" || "$mint_line" -ge "$force_line" ]]; then
  fail "mint_pub_dev_oidc_token must run after --dry-run and immediately before --force"
fi
ok "mint order before --force in execute path"

grep -q 'audience=https://pub.dev' "$MINT_SCRIPT" ||
  fail "mint script must request pub.dev OIDC audience"
grep -qE 'Authorization:[[:space:]]*bearer' "$MINT_SCRIPT" ||
  fail "mint script must send Authorization: bearer header"
grep -qE 'requesting OIDC token.*audience=https://pub.dev.*Authorization:[[:space:]]*bearer' "$MINT_SCRIPT" ||
  fail "mint script must log OIDC audience and bearer header (without printing secrets)"
ok "mint script OIDC audience and bearer contract"

grep -q 'jq -er' "$MINT_SCRIPT" ||
  fail "mint script must parse .value with jq"
grep -q '::add-mask::' "$MINT_SCRIPT" ||
  fail "mint script must mask PUB_TOKEN in GitHub Actions"
ok "mint script jq and add-mask contract"

if grep -qE 'env\.ACTIONS_ID_TOKEN_REQUEST|ACTIONS_ID_TOKEN_REQUEST.*\$\{\{[[:space:]]*env\.' "$WORKFLOW"; then
  fail "pub_publish.yml must not re-declare ACTIONS_ID_TOKEN_REQUEST_* via env.\${{ env.* }}"
fi
ok "pub_publish workflow does not override OIDC env"

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
