#!/usr/bin/env bash
# Plan-mode contracts for publish_release_assets (no gh).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT_DIR/tool/release/release_publish_lib.sh"
SCRIPT="$ROOT_DIR/tool/release/publish_release_assets.sh"

fail() { echo "test_release_publish_plan: $*" >&2; exit 1; }
ok() { echo "test_release_publish_plan: $*"; }

command -v jq >/dev/null 2>&1 || fail "jq required"
# shellcheck source=../release/release_publish_lib.sh
source "$LIB"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

asset_dir="$tmpdir/dist"
remote_dir="$tmpdir/remote"
mkdir -p "$asset_dir" "$remote_dir"
linux_name="flutter_mcp_7.2.1_linux-x64.tar.gz"
darwin_name="flutter_mcp_7.2.1_darwin-arm64.tar.gz"
linux="$asset_dir/$linux_name"
darwin="$asset_dir/$darwin_name"
linux_remote="$remote_dir/$linux_name"
printf linux >"$linux"
printf darwin >"$darwin"
printf linux-remote >"$linux_remote"
linux_h="$(sha256sum "$linux" | awk '{print $1}')"
darwin_h="$(sha256sum "$darwin" | awk '{print $1}')"
linux_remote_h="$(sha256sum "$linux_remote" | awk '{print $1}')"

write_state() {
  local draft="$1"
  local pub_checksums="${2:-}"
  local remote_linux_h="${3:-}"
  local remote_fixture="${4:-}"
  local remote_asset_names="${5:-$linux_name}"
  jq -n \
    --argjson draft "$draft" \
    --arg dir "$asset_dir" \
    --arg remote_dir "$remote_fixture" \
    --arg pub "$pub_checksums" \
    --arg linux_h "$linux_h" \
    --arg darwin_h "$darwin_h" \
    --arg remote_linux_h "$remote_linux_h" \
    --arg linux_name "$linux_name" \
    --arg darwin_name "$darwin_name" \
    --argjson remote_names "$(printf '%s\n' $remote_asset_names | jq -R . | jq -s .)" \
    --argjson published_asset false \
    '{
      is_draft: $draft,
      published_checksums_asset_present: $published_asset,
      asset_dir: $dir,
      remote_fixture_dir: (if $remote_dir == "" then null else $remote_dir end),
      published_checksums: (if $pub == "" then null else $pub end),
      local_tars: [$linux_name, $darwin_name],
      remote_assets: [$remote_names[] | {name: .}],
      local_hashes: {
        ($linux_name): $linux_h,
        ($darwin_name): $darwin_h
      },
      remote_hashes: (
        if $remote_linux_h == "" then {}
        else {($linux_name): $remote_linux_h}
        end)
    }'
}

state_draft="$(mktemp)"
write_state true >"$state_draft"
bash "$SCRIPT" --plan "$state_draft" >/dev/null || fail "draft plan mode must succeed"
plan_draft="$(release_publish__plan_from_state_file "$state_draft")"
[[ "$(echo "$plan_draft" | jq -r '.upload_local_names | length')" -eq 2 ]] || \
  fail "draft must upload all local tars"
ok "draft plan mode and cleanup path"

state_pub="$(mktemp)"
write_state false "" "$linux_h" >"$state_pub"
plan_pub="$(release_publish__plan_from_state_file "$state_pub")"
[[ "$(echo "$plan_pub" | jq -r '.upload_local_names | length')" -eq 1 ]] || \
  fail "published must only upload missing darwin"
bash "$SCRIPT" --plan "$state_pub" >/dev/null || fail "published partial plan mode"
ok "published gap-fill plan"

state_bad="$(mktemp)"
write_state false "" "0000000000000000000000000000000000000000000000000000000000000000" >"$state_bad"
if release_publish__plan_from_state_file "$state_bad" | jq -e '.ok == false' >/dev/null; then
  ok "checksum mismatch fails closed"
else
  fail "must reject remote hash mismatch"
fi
bash "$SCRIPT" --plan "$state_bad" >/dev/null 2>&1 && fail "script must refuse ok:false plan"
ok "script refuses ok:false plan"

pub_manifest="$linux_h  $linux_name"
state_manifest="$(mktemp)"
write_state false "$pub_manifest" "$linux_h" >"$state_manifest"
if release_publish__plan_from_state_file "$state_manifest" | jq -e '.ok == true' >/dev/null; then
  ok "listed remote hash matches manifest"
else
  fail "manifest consistency check failed"
fi

mystery_name="flutter_mcp_7.2.1_mystery.tar.gz"
mystery="$remote_dir/$mystery_name"
printf mystery >"$mystery"
mystery_h="$(sha256sum "$mystery" | awk '{print $1}')"
state_unlisted="$(mktemp)"
jq -n \
  --arg dir "$asset_dir" \
  --arg remote_dir "$remote_dir" \
  --arg pub "$pub_manifest" \
  --arg linux_h "$linux_h" \
  --arg darwin_h "$darwin_h" \
  --arg linux_name "$linux_name" \
  --arg darwin_name "$darwin_name" \
  --arg mystery_name "$mystery_name" \
  --arg mystery_h "$mystery_h" \
  '{
    is_draft: false,
    published_checksums_asset_present: true,
    asset_dir: $dir,
    remote_fixture_dir: $remote_dir,
    published_checksums: $pub,
    local_tars: [$linux_name, $darwin_name],
    remote_assets: [
      {name: $linux_name},
      {name: $mystery_name}
    ],
    local_hashes: {($linux_name): $linux_h, ($darwin_name): $darwin_h},
    remote_hashes: {($linux_name): $linux_h, ($mystery_name): $mystery_h}
  }' >"$state_unlisted"
if release_publish__plan_from_state_file "$state_unlisted" | jq -e '.ok == false' >/dev/null; then
  ok "unlisted remote tarball fails closed"
else
  fail "must reject unlisted remote asset"
fi
bash "$SCRIPT" --plan "$state_unlisted" >/dev/null 2>&1 && fail "script must refuse unlisted remote"
ok "script refuses unlisted remote"

rm -f "$linux"
state_remote_only="$(mktemp)"
jq -n \
  --arg dir "$asset_dir" \
  --arg remote_dir "$remote_dir" \
  --arg pub "$linux_remote_h  $linux_name" \
  --arg linux_name "$linux_name" \
  --arg darwin_name "$darwin_name" \
  --arg linux_remote_h "$linux_remote_h" \
  --arg darwin_h "$darwin_h" \
  '{
    is_draft: false,
    published_checksums_asset_present: true,
    asset_dir: $dir,
    remote_fixture_dir: $remote_dir,
    published_checksums: $pub,
    local_tars: [$darwin_name],
    remote_assets: [{name: $linux_name}],
    local_hashes: {($darwin_name): $darwin_h},
    remote_hashes: {($linux_name): $linux_remote_h}
  }' >"$state_remote_only"
plan_remote="$(release_publish__plan_from_state_file "$state_remote_only")"
[[ "$(echo "$plan_remote" | jq -r --arg n "$linux_name" '.checksum_tar_names | index($n)')" != "null" ]] || \
  fail "checksum manifest must union remote-only tarball"
[[ "$(echo "$plan_remote" | jq -r '.checksums_upload_action')" != "clobber_with_draft" ]] || \
  fail "published partial must not clobber tarballs"
bash "$SCRIPT" --plan "$state_remote_only" >/dev/null || \
  fail "remote-only fixture verify must succeed via remote_fixture_dir"
ok "plan mode remote download branch"

state_bad_line="$(mktemp)"
jq -n \
  --arg dir "$asset_dir" \
  --arg bad_line "/tmp/foo  $linux_name" \
  --arg linux_h "$linux_h" \
  --arg darwin_h "$darwin_h" \
  --arg linux_name "$linux_name" \
  --arg darwin_name "$darwin_name" \
  '{
    is_draft: false,
    published_checksums_asset_present: true,
    asset_dir: $dir,
    published_checksums: $bad_line,
    local_tars: [$linux_name, $darwin_name],
    remote_assets: [{name: $linux_name}],
    local_hashes: {($linux_name): $linux_h, ($darwin_name): $darwin_h},
    remote_hashes: {($linux_name): $linux_h}
  }' >"$state_bad_line"
bash "$SCRIPT" --plan "$state_bad_line" >/dev/null 2>&1 && fail "invalid checksum line must fail"
ok "invalid checksum manifest line"

grep -q 'release_publish__plan_from_state_file' "$SCRIPT" || \
  fail "production script must call shared plan function"
grep -q 'release_publish__run_verify_and_upload' "$SCRIPT" || \
  fail "production script must call shared verify/upload runner"
grep -q 'release_publish__execute_upload_from_plan' "$SCRIPT" || \
  fail "production script must call plan-driven upload"
if grep -q 'if \[\[ "\$is_draft" == "true" \]\]' "$SCRIPT" 2>/dev/null; then
  fail "script must not branch uploads on is_draft"
fi

ok "release publish plan contracts OK"