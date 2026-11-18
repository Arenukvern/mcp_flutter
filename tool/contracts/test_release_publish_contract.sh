#!/usr/bin/env bash
# Fixture-driven contract tests for release publish logic (no mock gh).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT_DIR/tool/release/release_publish_lib.sh"
fail() { echo "test_release_publish_contract: $*" >&2; exit 1; }
ok() { echo "test_release_publish_contract: $*"; }

command -v jq >/dev/null 2>&1 || fail "jq required"
# shellcheck source=../release/release_publish_lib.sh
source "$LIB"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

linux="$tmpdir/flutter_mcp_7.2.1_linux-x64.tar.gz"
darwin="$tmpdir/flutter_mcp_7.2.1_darwin-arm64.tar.gz"
echo payload-linux >"$linux"
echo payload-darwin >"$darwin"

line="$(release_publish__checksum_line_basename "$linux")"
release_publish__checksum_line_valid "$line" || fail "basename checksum line invalid"
[[ "$line" == *"  flutter_mcp_7.2.1_linux-x64.tar.gz" ]] || fail "basename must be bare filename"
grep -q " flutter_mcp_7.2.1_linux-x64.tar.gz\$" <<<"$line" || \
  fail "install.sh-style anchor must match basename line"
ok "checksum lines use basename (install.sh grep)"

export RELEASE_PUBLISH_REMOTE_TAR_CSV="flutter_mcp_7.2.1_linux-x64.tar.gz"
mapfile -t union < <(release_publish__all_tar_names_for_checksums false \
  flutter_mcp_7.2.1_darwin-arm64.tar.gz)
[[ " ${union[*]} " == *" flutter_mcp_7.2.1_linux-x64.tar.gz "* ]] || \
  fail "remote-only tarball must join checksum set"
[[ " ${union[*]} " == *" flutter_mcp_7.2.1_darwin-arm64.tar.gz "* ]] || \
  fail "local tarball must stay in checksum set"
ok "asset set unions local and remote-only tarballs"

action="$(release_publish__published_collision_action \
  "$(sha256sum "$linux" | awk '{print $1}')" \
  "$(sha256sum "$linux" | awk '{print $1}')")"
[[ "$action" == keep ]] || fail "matching hashes must keep remote"
action="$(release_publish__published_collision_action aa bb)"
[[ "$action" == fail_mismatch ]] || fail "mismatch must fail"
ok "published collision: match keeps, mismatch fails"

published="$tmpdir/published_checksums.txt"
remote_hash="$(sha256sum "$linux" | awk '{print $1}')"
printf '%s  %s\n' "$remote_hash" "flutter_mcp_7.2.1_linux-x64.tar.gz" >"$published"
release_publish__verify_against_published_checksums \
  "$published" "flutter_mcp_7.2.1_linux-x64.tar.gz" "$remote_hash" || \
  fail "authentic hash must pass published manifest"
if release_publish__verify_against_published_checksums \
  "$published" "flutter_mcp_7.2.1_linux-x64.tar.gz" \
  "0000000000000000000000000000000000000000000000000000000000000000" 2>/dev/null; then
  fail "tampered hash must fail published manifest"
else
  ok "recovery verifies remote bytes against published checksums.txt"
fi

{
  release_publish__checksum_line_basename "$linux"
  release_publish__checksum_line_basename "$darwin"
} >"$tmpdir/checksums.txt"
(
  cd "$tmpdir"
  sha256sum -c checksums.txt
) || fail "generated checksums must self-verify"
ok "checksums.txt verifies with sha256sum -c"

mapfile -t draft_names < <(release_publish__all_tar_names_for_checksums true \
  flutter_mcp_7.2.1_linux-x64.tar.gz flutter_mcp_7.2.1_darwin-arm64.tar.gz)
[[ "${#draft_names[@]}" -eq 2 ]] || fail "draft uses local tar names only"
ok "draft path does not union remote-only names"

if [[ -x "$ROOT_DIR/tool/release/publish_release_assets.sh" ]]; then
  grep -q 'release_publish__verify_against_published_checksums' \
    "$ROOT_DIR/tool/release/publish_release_assets.sh" || \
    fail "publish script must verify against published checksums.txt"
  grep -q -- '--clobber' "$ROOT_DIR/tool/release/publish_release_assets.sh" || \
    fail "publish script must support draft clobber via gh"
  ok "publish shell keeps thin gh edge with lib-backed checks"
fi

ok "release publish contract OK"