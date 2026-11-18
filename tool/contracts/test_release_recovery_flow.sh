#!/usr/bin/env bash
# Fixture tests: tooling scripts vs historical release-src layout (no verify script at tag).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFLICT_LIB="$ROOT_DIR/tool/release/release_assets_conflict_lib.sh"
CONFLICT_SCRIPT="$ROOT_DIR/tool/release/check_release_assets_conflict.sh"

fail() { echo "test_release_recovery_flow: $*" >&2; exit 1; }
ok() { echo "test_release_recovery_flow: $*"; }

command -v jq >/dev/null 2>&1 || fail "jq required"
# shellcheck source=../release/release_assets_conflict_lib.sh
source "$CONFLICT_LIB"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

export RELEASE_CONFLICT_CONTRACT_NO_GH=1
export GITHUB_REPOSITORY=example/test

conflict_check_invoker() {
  RELEASE_CONFLICT_CONTRACT_NO_GH=1 \
    GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-example/test}" \
    bash "$1" "$2" "$3"
}

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

# Conflict guard via contract fixture callbacks (no mock gh binary or shell gh).
export RELEASE_CONFLICT_CONTRACT_FIXTURE='{"assets":[{"name":"flutter_mcp_7.0.2_linux-x64.tar.gz"}]}'
if conflict_check_invoker "$tooling/tool/release/check_release_assets_conflict.sh" \
  v7.0.2 7.0.2; then
  ok "partial conflicting assets allow gap-fill recovery"
else
  fail "partial assets should pass for clobber recovery"
fi

export RELEASE_CONFLICT_CONTRACT_FIXTURE='{"assets":[{"name":"flutter_mcp_7.0.2_darwin-arm64.tar.gz"},{"name":"flutter_mcp_7.0.2_linux-x64.tar.gz"},{"name":"checksums.txt"}]}'
if conflict_check_invoker "$tooling/tool/release/check_release_assets_conflict.sh" \
  v7.0.2 7.0.2; then
  fail "must fail when all expected assets already exist"
else
  ok "full duplicate release still rejected"
fi

export RELEASE_CONFLICT_CONTRACT_FIXTURE='{"assets":[]}'
conflict_check_invoker "$tooling/tool/release/check_release_assets_conflict.sh" v7.0.2 7.0.2 \
  || fail "empty assets should pass"
ok "empty release assets pass"

export RELEASE_CONFLICT_CONTRACT_CB_FAIL=1
unset RELEASE_CONFLICT_CONTRACT_FIXTURE
if conflict_check_invoker "$tooling/tool/release/check_release_assets_conflict.sh" \
  v7.0.2 7.0.2 2>/dev/null; then
  fail "gh failure must not fail open"
else
  ok "gh errors propagate"
fi
unset RELEASE_CONFLICT_CONTRACT_CB_FAIL

SAFE_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export RELEASE_CONFLICT_CONTRACT_FIXTURE='{"assets":[]}'
if ! PATH="$SAFE_PATH" conflict_check_invoker \
  "$tooling/tool/release/check_release_assets_conflict.sh" v7.0.2 7.0.2; then
  fail "contract mode must not require gh on PATH"
fi
ok "conflict check works with gh absent from PATH"

plan_line="$(PATH="$SAFE_PATH" RELEASE_CONFLICT_CONTRACT_NO_GH=1 \
  GITHUB_REPOSITORY=example/test \
  bash "$tooling/tool/release/check_release_assets_conflict.sh" \
  --plan v7.0.2 7.0.2)"
grep -qF 'gh release view v7.0.2 --repo example/test --json assets' <<<"$plan_line" || \
  fail "--plan must emit gh release view argv"
ok "plan mode prints release view argv"

RELEASE_ROOT="$release" \
  bash "$tooling/tool/release/assert_release_tag.sh" v7.0.2 \
  || fail "assert_release_tag with RELEASE_ROOT"

# Mutate real execution path (contract cb_fail must propagate).
tooling_lib="$tooling/tool/release/release_assets_conflict_lib.sh"
cp "$tooling_lib" "$tmpdir/lib.bak"
sed -i 's/"$callback" argv || return 1/"$callback" argv # MUT/' "$tooling_lib"
export RELEASE_CONFLICT_CONTRACT_CB_FAIL=1
unset RELEASE_CONFLICT_CONTRACT_FIXTURE
if conflict_check_invoker "$tooling/tool/release/check_release_assets_conflict.sh" \
  v7.0.2 7.0.2 2>/dev/null; then
  cp "$tmpdir/lib.bak" "$tooling_lib"
  fail "mutation: swallowed callback failure must turn test red"
fi
cp "$tmpdir/lib.bak" "$tooling_lib"
unset RELEASE_CONFLICT_CONTRACT_CB_FAIL
export RELEASE_CONFLICT_CONTRACT_FIXTURE='{"assets":[]}'
conflict_check_invoker "$tooling/tool/release/check_release_assets_conflict.sh" \
  v7.0.2 7.0.2 || fail "mutation restore: empty assets must pass"
ok "mutation: invoke callback failure is red then green"

ok "recovery flow fixtures OK"