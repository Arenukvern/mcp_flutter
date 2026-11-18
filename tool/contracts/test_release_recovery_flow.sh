#!/usr/bin/env bash
# Fixture tests: tooling scripts vs historical release-src layout (no verify script at tag).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFLICT_MAIN="$ROOT_DIR/tool/release/check_release_assets_conflict.sh"

fail() { echo "test_release_recovery_flow: $*" >&2; exit 1; }
ok() { echo "test_release_recovery_flow: $*"; }

command -v jq >/dev/null 2>&1 || fail "jq required"

guard_no_contract_env_in_release_scripts() {
  local hits
  hits="$(grep -rnE 'CONTRACT_NO_GH|CONTRACT_FIXTURE|CONTRACT_UPLOAD|CONTRACT_CB_FAIL|RELEASE_.*_CONTRACT' \
    "$ROOT_DIR/tool/release" 2>/dev/null || true)"
  [[ -z "$hits" ]] || fail "tool/release must not read contract test env: $hits"
}
guard_no_contract_env_in_release_scripts

RECOVERY_CONFLICT_FIXTURE_JSON=''
RECOVERY_CONFLICT_CB_FAIL=0

# shellcheck source=../release/check_release_assets_conflict.sh
source "$CONFLICT_MAIN"

release_conflict__cb_run_argv() {
  if [[ "${RECOVERY_CONFLICT_CB_FAIL:-}" == 1 ]]; then
    echo "simulated gh api failure" >&2
    return 1
  fi
  if [[ -z "${RECOVERY_CONFLICT_FIXTURE_JSON:-}" ]]; then
    echo "test_release_recovery_flow: RECOVERY_CONFLICT_FIXTURE_JSON unset" >&2
    return 1
  fi
  printf '%s' "$RECOVERY_CONFLICT_FIXTURE_JSON"
  return 0
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
if check_release_assets_conflict__main v7.0.2 7.0.2; then
  ok "partial conflicting assets allow gap-fill recovery"
else
  fail "partial assets should pass for clobber recovery"
fi

full_fixture_json() {
  local -a expected=()
  release_conflict__load_expected_asset_names "$1" expected
  jq -cn --argjson names "$(printf '%s\n' "${expected[@]}" | jq -R . | jq -s .)" \
    '{assets: [$names[] | {name: .}]}'
}
RECOVERY_CONFLICT_FIXTURE_JSON="$(full_fixture_json 7.0.2)"
if (check_release_assets_conflict__main v7.0.2 7.0.2); then
  fail "must fail when all expected assets already exist"
else
  ok "full duplicate release still rejected"
fi

RECOVERY_CONFLICT_FIXTURE_JSON='{"assets":[]}'
RECOVERY_CONFLICT_CB_FAIL=0
check_release_assets_conflict__main v7.0.2 7.0.2 \
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

stub_gh="$tmpdir/gh-stub"
printf '#!/usr/bin/env bash\necho "gh stub must not run" >&2\nexit 1\n' >"$stub_gh"
chmod +x "$stub_gh"
SAFE_PATH="$tmpdir:/usr/sbin:/usr/bin:/sbin:/bin"
RECOVERY_CONFLICT_FIXTURE_JSON='{"assets":[]}'
if ! PATH="$SAFE_PATH" check_release_assets_conflict__main v7.0.2 7.0.2; then
  fail "in-process cb hook must not require real gh"
fi
ok "conflict check works with gh stub (real gh not invoked)"

plan_line="$(PATH="$SAFE_PATH" GITHUB_REPOSITORY=example/test \
  check_release_assets_conflict__plan_main --plan v7.0.2 7.0.2)"
grep -qF 'gh release view v7.0.2 --repo example/test --json assets' <<<"$plan_line" || \
  fail "--plan must emit gh release view argv"
ok "plan mode prints release view argv"

if (PATH="$SAFE_PATH" GITHUB_REPOSITORY=example/test \
  check_release_assets_conflict__plan_main --plan bad-tag 7.0.2 2>/dev/null); then
  fail "--plan must reject invalid tag format"
fi
ok "plan mode enforces tag format"

RELEASE_ROOT="$release" \
  bash "$tooling/tool/release/assert_release_tag.sh" v7.0.2 \
  || fail "assert_release_tag with RELEASE_ROOT"

ok "recovery flow fixtures OK"
