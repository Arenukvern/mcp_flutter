#!/usr/bin/env bash
# Fixture tests: tooling scripts vs historical release-src layout (no verify script at tag).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFLICT_LIB="$ROOT_DIR/tool/release/release_assets_conflict_lib.sh"
CONFLICT_MAIN="$ROOT_DIR/tool/release/check_release_assets_conflict.sh"

test_fail() { echo "test_release_recovery_flow: $*" >&2; exit 1; }
test_ok() { echo "test_release_recovery_flow: $*"; }
fail() { test_fail "$@"; }
ok() { test_ok "$@"; }

command -v jq >/dev/null 2>&1 || fail "jq required"

guard_no_contract_env_in_release_scripts() {
  local hits
  hits="$(grep -rnE 'CONTRACT_NO_GH|CONTRACT_FIXTURE|CONTRACT_UPLOAD|CONTRACT_CB_FAIL|RELEASE_.*_CONTRACT' \
    "$ROOT_DIR/tool/release" 2>/dev/null || true)"
  [[ -z "$hits" ]] || fail "tool/release must not read contract test env: $hits"
}
guard_no_contract_env_in_release_scripts

# shellcheck source=../release/release_assets_conflict_lib.sh
source "$CONFLICT_LIB"

contract_assert_real_conflict_cb_run_argv() {
  local -a argv=(false)
  if release_conflict__cb_run_argv argv 2>/dev/null; then
    fail "real release_conflict__cb_run_argv must propagate false exit"
  fi
  argv=(printf x)
  local out
  out="$(release_conflict__cb_run_argv argv)"
  [[ "$out" == "x" ]] || fail "real release_conflict__cb_run_argv must run printf (got: $out)"
  ok "real release_conflict__cb_run_argv executes argv"
}
contract_assert_real_conflict_cb_run_argv

RECOVERY_CONFLICT_FIXTURE_JSON=''
RECOVERY_CONFLICT_CB_FAIL=0

recovery__gh_fail_cb() {
  echo "simulated gh api failure" >&2
  return 1
}

# shellcheck source=../release/check_release_assets_conflict.sh
source "$CONFLICT_MAIN"

fail() { test_fail "$@"; }
ok() { test_ok "$@"; }

release_conflict__require_gh() { :; }

release_conflict__fetch_release_view_json() {
  local tag="$1"
  local repo="$2"
  if [[ "${RECOVERY_CONFLICT_CB_FAIL:-}" == 1 ]]; then
  release_conflict__invoke_release_view_argv \
    "$tag" "$repo" recovery__gh_fail_cb
    return $?
  fi
  if [[ -z "${RECOVERY_CONFLICT_FIXTURE_JSON:-}" ]]; then
    echo "test_release_recovery_flow: RECOVERY_CONFLICT_FIXTURE_JSON unset" >&2
    return 1
  fi
  printf '%s' "$RECOVERY_CONFLICT_FIXTURE_JSON"
  return 0
}

EXPECTED_V702_ASSETS=(
  "flutter_mcp_7.0.2_darwin-arm64.tar.gz"
  "flutter_mcp_7.0.2_linux-x64.tar.gz"
  "checksums.txt"
)

contract_assert_expected_assets_include_checksums() {
  local -a names=()
  release_conflict__load_expected_asset_names 7.0.2 names
  [[ ${#names[@]} -eq 3 ]] || fail "expected asset list must have 3 entries (got ${#names[@]})"
  local n found=false
  for n in "${names[@]}"; do
    [[ "$n" == "checksums.txt" ]] && found=true
  done
  [[ "$found" == true ]] || fail "expected asset list must include checksums.txt"
  ok "expected asset names include checksums.txt"
}
contract_assert_expected_assets_include_checksums

full_duplicate_fixture_json() {
  jq -cn --argjson names "$(printf '%s\n' "${EXPECTED_V702_ASSETS[@]}" | jq -R . | jq -s .)" \
    '{assets: [$names[] | {name: .}]}'
}

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

export GITHUB_REPOSITORY=example/test

tooling="$tmpdir/tooling"
release="$tmpdir/release-src"
mkdir -p "$tooling/tool/release" "$release"

cp -a "$ROOT_DIR/tool/release/"*.sh "$tooling/tool/release/"
chmod +x "$tooling/tool/release/"*.sh
echo '7.0.2' >"$release/VERSION"
printf '%s\n' 'const String kFlutterMcpVersion = '"'"'7.0.2'"'"';' >"$release/runtime.dart"

if [[ -f "$release/tool/release/verify_release_tarball_architecture.sh" ]]; then
  fail "fixture release-src should not bundle new verify helper"
fi
[[ -x "$tooling/tool/release/verify_release_tarball_architecture.sh" ]] || \
  fail "tooling must carry verify helper"

git -C "$release" init -q
git -C "$release" add VERSION runtime.dart
git -C "$release" -c user.email=t -c user.name=t commit -q -m "v7.0.2 source"
git -C "$release" tag v7.0.2
sha="$(git -C "$release" rev-parse HEAD^{commit})"

bash "$tooling/tool/release/verify_release_source_checkout.sh" "$release" v7.0.2 "$sha" \
  || fail "verify_release_source_checkout"

if bash "$release/tool/release/resolve_release_tag.sh" 2>/dev/null; then
  fail "missing script at release-src should fail"
else
  ok "missing release-src helper fails"
fi

RECOVERY_CONFLICT_FIXTURE_JSON='{"assets":[{"name":"flutter_mcp_7.0.2_linux-x64.tar.gz"}]}'
RECOVERY_CONFLICT_CB_FAIL=0
if (check_release_assets_conflict__main v7.0.2 7.0.2); then
  ok "partial conflicting assets allow gap-fill recovery"
else
  fail "partial assets should pass for clobber recovery"
fi

RECOVERY_CONFLICT_FIXTURE_JSON="$(full_duplicate_fixture_json)"
if (check_release_assets_conflict__main v7.0.2 7.0.2); then
  fail "must fail when all expected assets already exist"
else
  ok "full duplicate release still rejected"
fi

RECOVERY_CONFLICT_FIXTURE_JSON='{"assets":[]}'
RECOVERY_CONFLICT_CB_FAIL=0
(check_release_assets_conflict__main v7.0.2 7.0.2) \
  || fail "empty assets should pass"
ok "empty release assets pass"

RECOVERY_CONFLICT_CB_FAIL=1
gh_fail_out=""
gh_fail_out="$( (check_release_assets_conflict__main v7.0.2 7.0.2) 2>&1 || true )"
if grep -q 'no conflicting assets' <<<"$gh_fail_out"; then
  fail "gh failure must not fail open"
fi
grep -q 'gh release view failed' <<<"$gh_fail_out" || \
  fail "gh failure must abort with gh release view failed (got: $gh_fail_out)"
ok "gh errors propagate"
RECOVERY_CONFLICT_CB_FAIL=0

NO_GH_PATH="/usr/sbin:/sbin:/bin"
RECOVERY_CONFLICT_FIXTURE_JSON='{"assets":[]}'
if ! (PATH="$NO_GH_PATH" check_release_assets_conflict__main v7.0.2 7.0.2); then
  fail "require_gh override must let main run with gh absent from PATH"
fi
ok "conflict check passes with gh absent from PATH"

plan_line="$( (PATH="$NO_GH_PATH" GITHUB_REPOSITORY=example/test \
  check_release_assets_conflict__plan_main --plan v7.0.2 7.0.2) )"
grep -qF 'gh release view v7.0.2 --repo example/test --json assets' <<<"$plan_line" || \
  fail "--plan must emit gh release view argv"
ok "plan mode prints release view argv"

if (PATH="$NO_GH_PATH" GITHUB_REPOSITORY=example/test \
  check_release_assets_conflict__plan_main --plan bad-tag 7.0.2 2>/dev/null); then
  fail "--plan must reject invalid tag format"
fi
ok "plan mode enforces tag format"

RELEASE_ROOT="$release" \
  bash "$tooling/tool/release/assert_release_tag.sh" v7.0.2 \
  || fail "assert_release_tag with RELEASE_ROOT"

ok "recovery flow fixtures OK"