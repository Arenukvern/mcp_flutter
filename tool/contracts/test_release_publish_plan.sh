#!/usr/bin/env bash
# Plan-mode contracts + mutation checks for publish_release_assets (no gh).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT_DIR/tool/release/release_publish_lib.sh"
SCRIPT="$ROOT_DIR/tool/release/publish_release_assets.sh"
FIXTURES="$ROOT_DIR/tool/contracts/fixtures/release_publish"

fail() { echo "test_release_publish_plan: $*" >&2; exit 1; }
ok() { echo "test_release_publish_plan: $*"; }

command -v jq >/dev/null 2>&1 || fail "jq required"
# shellcheck source=../release/release_publish_lib.sh
source "$LIB"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

asset_dir="$tmpdir/dist"
mkdir -p "$asset_dir"
linux="$asset_dir/flutter_mcp_7.2.1_linux-x64.tar.gz"
darwin="$asset_dir/flutter_mcp_7.2.1_darwin-arm64.tar.gz"
printf linux >"$linux"
printf darwin >"$darwin"
linux_h="$(sha256sum "$linux" | awk '{print $1}')"
darwin_h="$(sha256sum "$darwin" | awk '{print $1}')"

write_state() {
  local draft="$1"
  local pub_checksums="${2:-}"
  local remote_linux_h="${3:-}"
  jq -n \
    --argjson draft "$draft" \
    --arg dir "$asset_dir" \
    --arg pub "$pub_checksums" \
    --arg linux_h "$linux_h" \
    --arg darwin_h "$darwin_h" \
    --arg remote_linux_h "$remote_linux_h" \
    '{
      is_draft: $draft,
      asset_dir: $dir,
      published_checksums: (if $pub == "" then null else $pub end),
      local_tars: ["flutter_mcp_7.2.1_linux-x64.tar.gz", "flutter_mcp_7.2.1_darwin-arm64.tar.gz"],
      remote_assets: (
        if $remote_linux_h == "" then []
        else [{name: "flutter_mcp_7.2.1_linux-x64.tar.gz"}]
        end),
      local_hashes: {
        "flutter_mcp_7.2.1_linux-x64.tar.gz": $linux_h,
        "flutter_mcp_7.2.1_darwin-arm64.tar.gz": $darwin_h
      },
      remote_hashes: (
        if $remote_linux_h == "" then {}
        else {"flutter_mcp_7.2.1_linux-x64.tar.gz": $remote_linux_h}
        end)
    }'
}

state_draft="$(mktemp)"
write_state true >"$state_draft"
bash "$SCRIPT" --plan "$state_draft" >/dev/null || fail "draft plan mode must succeed"
plan_draft="$(release_publish__plan_from_state_file "$state_draft")"
[[ "$(echo "$plan_draft" | jq -r '.draft_upload_clobber')" == "true" ]] || \
  fail "draft plan must request clobber upload"
[[ "$(echo "$plan_draft" | jq -r '.upload_local_names | length')" -eq 2 ]] || \
  fail "draft must upload all local tars"
ok "draft plan mode and cleanup path"

state_pub="$(mktemp)"
write_state false "" "$linux_h" >"$state_pub"
plan_pub="$(release_publish__plan_from_state_file "$state_pub")"
[[ "$(echo "$plan_pub" | jq -r '.draft_upload_clobber')" == "false" ]] || \
  fail "published must not clobber"
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

pub_manifest="$linux_h  flutter_mcp_7.2.1_linux-x64.tar.gz"
state_manifest="$(mktemp)"
write_state false "$pub_manifest" "$linux_h" >"$state_manifest"
if release_publish__plan_from_state_file "$state_manifest" | jq -e '.ok == true' >/dev/null; then
  ok "listed remote hash matches manifest"
else
  fail "manifest consistency check failed"
fi

state_unlisted="$(mktemp)"
write_state false "$pub_manifest" "1111111111111111111111111111111111111111111111111111111111111111" >"$state_unlisted"
if release_publish__plan_from_state_file "$state_unlisted" | jq -e '.ok == false' >/dev/null; then
  ok "unlisted / wrong remote fails closed"
else
  fail "must fail on manifest disagreement"
fi

grep -q 'release_publish__plan_from_state_file' "$SCRIPT" || \
  fail "production script must call shared plan function"

mutate_lib() {
  local sed_script="$1"
  local lib_copy="$tmpdir/mutated_lib.sh"
  cp "$LIB" "$lib_copy"
  # shellcheck disable=SC2016
  sed -i "$sed_script" "$lib_copy"
  # shellcheck source=/dev/null
  source "$lib_copy"
}

expect_plan_fail() {
  local label="$1"
  shift
  if release_publish__plan_from_state_file "$state_pub" | jq -e '.ok == true' >/dev/null 2>&1; then
    fail "mutation should break plan: $label"
  else
    ok "mutation blocked: $label"
  fi
}

# Restore canonical lib before each mutation source.
# shellcheck source=../release/release_publish_lib.sh
source "$LIB"

mutate_lib '/^release_publish__published_collision_action()/,/^}$/c\
release_publish__published_collision_action() {\
  echo keep\
}\
'
if release_publish__plan_from_state_file "$state_bad" | jq -e '.ok == true' >/dev/null 2>&1; then
  ok "mutation blocked: ignore sha256 mismatch"
else
  fail "collision-action mutation must not mask mismatch"
fi

# shellcheck source=../release/release_publish_lib.sh
source "$LIB"
mutate_lib 's/remote_only+=( "$remote" )/:/'
mapfile -t names < <(RELEASE_PUBLISH_REMOTE_TAR_CSV="flutter_mcp_7.2.1_linux-x64.tar.gz" \
  release_publish__checksum_tar_names false flutter_mcp_7.2.1_darwin-arm64.tar.gz)
[[ " ${names[*]} " == *"linux-x64"* ]] && fail "mutation should break remote-only union"
ok "mutation blocked: remote-only union"

# shellcheck source=../release/release_publish_lib.sh
source "$LIB"
[[ "$(release_publish__plan_from_state_file "$state_pub" | jq -r '.draft_upload_clobber')" == "false" ]] || \
  fail "canonical published must not clobber"
mutate_lib 's/draft_upload_clobber: \$draft/draft_upload_clobber: true/'
[[ "$(release_publish__plan_from_state_file "$state_pub" | jq -r '.draft_upload_clobber')" == "true" ]] && \
  ok "mutation blocked: clobber published" || fail "clobber mutation undetected"

# shellcheck source=../release/release_publish_lib.sh
source "$LIB"
[[ "$(release_publish__plan_from_state_file "$state_pub" | jq -r '.upload_local_names | length')" -eq 1 ]] || \
  fail "canonical published gap-fill"
mutate_lib 's/upload_locals+=( "$name" )/upload_locals+=( "$name" ); upload_locals=( "${local_tars[@]}" )/'
[[ "$(release_publish__plan_from_state_file "$state_pub" | jq -r '.upload_local_names | length')" -eq 2 ]] && \
  ok "mutation blocked: upload all locals" || fail "upload-all mutation undetected"

# shellcheck source=../release/release_publish_lib.sh
source "$LIB"
line="$(release_publish__checksum_line_from_parts "$linux_h" "flutter_mcp_7.2.1_linux-x64.tar.gz")"
[[ "$line" == *"  flutter_mcp_7.2.1_linux-x64.tar.gz" ]] || fail "basename lines"
line_mut="$(release_publish__checksum_line_from_parts "$linux_h" "/tmp/flutter_mcp_7.2.1_linux-x64.tar.gz")"
release_publish__checksum_line_valid "$line_mut" && fail "canonical must reject full paths"
mutate_lib '/^release_publish__checksum_line_valid/,/^}$/c\
release_publish__checksum_line_valid() { return 0; }\
'
release_publish__checksum_line_valid "$line_mut" || fail "mutation must accept path lines for detection"
ok "mutation blocked: full paths in checksums.txt"

ok "release publish plan contracts OK"