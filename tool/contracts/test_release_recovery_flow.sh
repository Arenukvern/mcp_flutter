#!/usr/bin/env bash
# Fixture tests: tooling scripts vs historical release-src layout (no verify script at tag).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() { echo "test_release_recovery_flow: $*" >&2; exit 1; }
ok() { echo "test_release_recovery_flow: $*"; }

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

tooling="$tmpdir/tooling"
release="$tmpdir/release-src"
mkdir -p "$tooling/tool/release" "$release"

cp -a "$ROOT_DIR/tool/release/"*.sh "$tooling/tool/release/"
chmod +x "$tooling/tool/release/"*.sh
echo '7.0.2' >"$release/VERSION"
printf '%s\n' 'const String kFlutterMcpVersion = '"'"'7.0.2'"'"';' >"$release/runtime.dart"

# Historical tag tree: no verify_release_tarball_architecture.sh at tag root (only in tooling).
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

# Missing tooling script path should fail.
if bash "$release/tool/release/resolve_release_tag.sh" 2>/dev/null; then
  fail "missing script at release-src should fail"
else
  ok "missing release-src helper fails"
fi

# Conflict guard: mock gh failures propagate.
mock_gh="$tmpdir/gh"
cat >"$mock_gh" <<'SH'
#!/usr/bin/env bash
if [[ "${MOCK_GH_FAIL:-}" == "1" ]]; then
  echo "api error" >&2
  exit 1
fi
if [[ "$1" == "release" && "$2" == "view" ]]; then
  echo '{"assets":[]}'
  exit 0
fi
if [[ "$1" == "release" && "$2" == "view" && "${MOCK_GH_CONFLICT:-}" == "1" ]]; then
  echo '{"assets":[{"name":"flutter_mcp_7.0.2_linux-x64.tar.gz"}]}'
  exit 0
fi
exit 1
SH
chmod +x "$mock_gh"

export PATH="$tmpdir:$PATH"
export GITHUB_REPOSITORY=example/test

# Conflict path (override gh output via env fixture file)
export GH_RELEASE_FIXTURE='{"assets":[{"name":"flutter_mcp_7.0.2_linux-x64.tar.gz"}]}'
gh() {
  if [[ "$1" == "release" ]]; then
    echo "$GH_RELEASE_FIXTURE"
    return 0
  fi
  return 1
}
export -f gh

if bash "$tooling/tool/release/check_release_assets_conflict.sh" v7.0.2 7.0.2; then
  fail "must fail on conflicting asset names"
else
  ok "conflicting assets rejected"
fi

unset -f gh
export GH_RELEASE_FIXTURE='{"assets":[]}'
gh() { echo "$GH_RELEASE_FIXTURE"; }
export -f gh
bash "$tooling/tool/release/check_release_assets_conflict.sh" v7.0.2 7.0.2 \
  || fail "empty assets should pass"

unset -f gh 2>/dev/null || true
gh() {
  echo "simulated gh api failure" >&2
  return 1
}
export -f gh
if bash "$tooling/tool/release/check_release_assets_conflict.sh" v7.0.2 7.0.2 2>/dev/null; then
  fail "gh failure must not fail open"
else
  ok "gh errors propagate"
fi
unset -f gh 2>/dev/null || true

RELEASE_ROOT="$release" \
  bash "$tooling/tool/release/assert_release_tag.sh" v7.0.2 \
  || fail "assert_release_tag with RELEASE_ROOT"

ok "recovery flow fixtures OK"
