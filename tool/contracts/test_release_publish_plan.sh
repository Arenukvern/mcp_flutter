#!/usr/bin/env bash
# Plan-mode contracts for publish_release_assets (no gh).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT_DIR/tool/release/release_publish_lib.sh"
SCRIPT="$ROOT_DIR/tool/release/publish_release_assets.sh"

fail() { echo "test_release_publish_plan: $*" >&2; exit 1; }
ok() { echo "test_release_publish_plan: $*"; }
contract_ok() { echo "test_release_publish_plan: $*"; }

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

plan_cmds_from_output() {
  awk '/^---COMMANDS---$/{p=1;next} /^---CHECKSUMS_PATH---$/{p=0} p' <<<"$1"
}

plan_checksums_b64_from_output() {
  awk '/^---CHECKSUMS_BYTES_B64---$/{getline; print; exit}' <<<"$1"
}

two_line_manifest() {
  printf '%s  %s\n%s  %s\n' "$linux_h" "$linux_name" "$darwin_h" "$darwin_name"
}

linux_only_manifest() {
  printf '%s  %s\n' "$linux_h" "$linux_name"
}

write_state() {
  local draft="$1"
  local pub_checksums="${2:-}"
  local remote_linux_h="${3:-}"
  local remote_fixture="${4:-}"
  local remote_asset_names="${5:-$linux_name}"
  local published_asset="${6:-false}"
  local remote_checksums_h="${7:-}"
  jq -n \
    --argjson draft "$draft" \
    --arg dir "$asset_dir" \
    --arg remote_dir "$remote_fixture" \
    --arg pub "$pub_checksums" \
    --arg linux_h "$linux_h" \
    --arg darwin_h "$darwin_h" \
    --arg remote_linux_h "$remote_linux_h" \
    --arg remote_checksums_h "$remote_checksums_h" \
    --arg linux_name "$linux_name" \
    --arg darwin_name "$darwin_name" \
    --argjson remote_names "$(printf '%s' "$remote_asset_names" | tr ' ' '\n' | sed '/^$/d' | jq -R . | jq -s .)" \
    --argjson published_asset "$published_asset" \
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
        (if $remote_linux_h == "" then {} else {($linux_name): $remote_linux_h} end)
        + (if $remote_checksums_h == "" then {} else {"checksums.txt": $remote_checksums_h} end))
    }'
}

release_publish__checksum_line_valid "notahex  foo" && fail "garbage checksum line must fail"
release_publish__checksum_line_valid "0000000000000000000000000000000000000000000000000000000000000000  $linux_name" || \
  fail "valid checksum line must pass"
strict_a="$(mktemp)"
strict_b="$(mktemp)"
printf '%s  old.tar.gz\n' \
  "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" >"$strict_a"
printf '%s  new.tar.gz\n' \
  "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" >"$strict_b"
release_publish__checksums_strict_superset "$strict_a" "$strict_b" && \
  fail "strict superset must reject removed published line"
rm -f "$strict_a" "$strict_b"
ok "checksum_line_valid garbage guard"

state_draft="$(mktemp)"
write_state true >"$state_draft"
draft_out="$(bash "$SCRIPT" --plan "$state_draft" 2>&1)" || fail "draft plan mode must succeed"
plan_draft="$(echo "$draft_out" | head -1)"
[[ "$(echo "$plan_draft" | jq -r '.upload_local_names | length')" -eq 2 ]] || \
  fail "draft must upload all local tars"
[[ "$(echo "$plan_draft" | jq -r '.checksums_upload_action')" == "clobber_with_draft" ]] || \
  fail "draft must clobber checksums"
draft_cmds="$(plan_cmds_from_output "$draft_out")"
grep -q -- '--clobber' <<<"$draft_cmds" || fail "draft must emit clobber upload command"
ok "draft plan mode and cleanup path"

state_draft_chk="$(mktemp)"
write_state true "" "$linux_h" "" "$linux_name checksums.txt" true >"$state_draft_chk"
plan_draft_chk="$(release_publish__plan_from_state_file "$state_draft_chk")"
[[ "$(echo "$plan_draft_chk" | jq -r '.ok')" == "true" ]] || fail "draft with remote checksums must plan"
[[ "$(echo "$plan_draft_chk" | jq -r '.checksums_upload_action')" == "clobber_with_draft" ]] || \
  fail "draft with checksums.txt must clobber"
bash "$SCRIPT" --plan "$state_draft_chk" >/dev/null || fail "draft+checksums plan mode"
ok "draft with existing checksums.txt"

state_pub="$(mktemp)"
write_state false "" "$linux_h" >"$state_pub"
plan_pub="$(release_publish__plan_from_state_file "$state_pub")"
[[ "$(echo "$plan_pub" | jq -r '.upload_local_names | length')" -eq 1 ]] || \
  fail "published must only upload missing darwin"
pub_out="$(bash "$SCRIPT" --plan "$state_pub" 2>&1)" || fail "published partial plan mode"
grep -q '/' "$asset_dir/checksums.txt" && fail "checksums.txt must list basename paths only"
upload_n="$(echo "$pub_out" | head -1 | jq '[.upload_local_names[]?] | length')"
pub_cmds="$(plan_cmds_from_output "$pub_out")"
upload_cmd_n="$(grep -c 'gh release upload' <<<"$pub_cmds" || true)"
[[ "$upload_cmd_n" -eq "$((upload_n + 1))" ]] || \
  fail "upload commands must match plan locals plus checksums"
grep -q -- "gh release upload" <<<"$pub_cmds" || fail "published plan must emit upload commands"
grep -q -- "$darwin_name" <<<"$pub_cmds" || fail "published must upload darwin"
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  [[ "$line" == *--clobber* && "$line" == *.tar.gz* ]] && \
    fail "published tarball uploads must not use --clobber"
done <<<"$pub_cmds"
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
if sed -n '/release_publish__execute_upload_from_plan/,/^}/p' "$LIB" | \
  grep -q '\$is_draft'; then
  fail "upload executor must not branch on is_draft"
fi

printf linux >"$linux"
printf darwin >"$darwin"
linux_h="$(sha256sum "$linux" | awk '{print $1}')"
darwin_h="$(sha256sum "$darwin" | awk '{print $1}')"
manifest_keep="$(two_line_manifest)"
manifest_keep_ch="$(printf '%s' "${manifest_keep%$'\n'}" | sha256sum | awk '{print $1}')"
state_keep="$(mktemp)"
write_state false "$manifest_keep" "$linux_h" "" \
  "$linux_name checksums.txt" true "$manifest_keep_ch" >"$state_keep"
plan_keep="$(release_publish__plan_from_state_file "$state_keep")"
[[ "$(echo "$plan_keep" | jq -r '.checksums_upload_action')" == "keep_checksums" ]] || \
  fail "identical manifest must keep_checksums"
keep_out="$(bash "$SCRIPT" --plan "$state_keep" 2>&1)" || fail "keep fixture plan mode"
keep_cmds="$(plan_cmds_from_output "$keep_out")"
grep -q 'checksums.txt' <<<"$keep_cmds" && fail "keep_checksums must not upload checksums.txt"
expected_keep="$(mktemp)"
release_publish__write_checksums_file "$expected_keep" \
  "$(echo "$plan_keep" | jq -r '.checksums_body')"
cmp -s "$expected_keep" "$asset_dir/checksums.txt" || fail "checksums.txt must match plan body"
b64_expected="$(base64 -w0 <"$expected_keep")"
b64_actual="$(plan_checksums_b64_from_output "$keep_out")"
[[ "$b64_expected" == "$b64_actual" ]] || fail "checksums b64 trailer must match file"
ok "keep_checksums with trailing-newline manifest"

state_superset="$(mktemp)"
write_state false "$(linux_only_manifest)" "$linux_h" "" \
  "$linux_name checksums.txt" true >"$state_superset"
plan_sup="$(release_publish__plan_from_state_file "$state_superset")"
[[ "$(echo "$plan_sup" | jq -r '.checksums_upload_action')" == "upload_checksums_superset" ]] || \
  fail "strict superset must upload_checksums_superset"
sup_out="$(bash "$SCRIPT" --plan "$state_superset" 2>&1)" || fail "superset plan mode"
sup_cmds="$(plan_cmds_from_output "$sup_out")"
grep -Eq -- '--clobber .*checksums\.txt' <<<"$sup_cmds" || \
  fail "superset must clobber checksums only"
ok "checksums strict superset fixture"

mystery_name2="flutter_mcp_7.2.1_extra.tar.gz"
extra_h="1111111111111111111111111111111111111111111111111111111111111111"
not_super_manifest="$(linux_only_manifest)${extra_h}  ${mystery_name2}
"
state_not_super="$(mktemp)"
jq -n \
  --arg dir "$asset_dir" \
  --arg pub "$not_super_manifest" \
  --arg linux_h "$linux_h" \
  --arg darwin_h "$darwin_h" \
  --arg linux_name "$linux_name" \
  --arg darwin_name "$darwin_name" \
  '{
    is_draft: false,
    published_checksums_asset_present: true,
    asset_dir: $dir,
    published_checksums: $pub,
    local_tars: [$linux_name, $darwin_name],
    remote_assets: [{name: $linux_name}, {name: "checksums.txt"}],
    local_hashes: {($linux_name): $linux_h, ($darwin_name): $darwin_h},
    remote_hashes: {($linux_name): $linux_h}
  }' >"$state_not_super"
not_super_plan="$(release_publish__plan_from_state_file "$state_not_super")"
[[ "$(echo "$not_super_plan" | jq -r '.ok')" == "false" ]] || \
  fail "non-superset manifest must fail"
[[ "$(echo "$not_super_plan" | jq -r '.checksums_upload_action // empty')" != \
  "upload_checksums_superset" ]] || fail "non-superset must not plan superset upload"
bash "$SCRIPT" --plan "$state_not_super" >/dev/null 2>&1 && fail "script must refuse non-superset"
ok "checksums not strict superset"

TEST_UPLOAD_CB_CALLS=()
release_publish__test_cb_fail_on_darwin() {
  # shellcheck disable=SC2034
  local -n _cmd=$1
  TEST_UPLOAD_CB_CALLS+=( "$(release_publish__argv_to_line "${_cmd[@]}")" )
  if [[ "${_cmd[*]}" == *"$darwin_name"* && "${_cmd[*]}" != *checksums.txt* ]]; then
    return 1
  fi
  return 0
}

state_pub_upload="$(mktemp)"
write_state false "" "$linux_h" "" "$linux_name $darwin_name" false >"$state_pub_upload"
plan_pub_upload="$(release_publish__plan_from_state_file "$state_pub_upload")"
release_publish__write_checksums_file "$asset_dir/checksums.txt" \
  "$(echo "$plan_pub_upload" | jq -r '.checksums_body')"
release_publish__invoke_each_upload_argv_from_plan \
  "$plan_pub_upload" "$asset_dir" "v7.2.1" "o/r" \
  release_publish__test_cb_fail_on_darwin 2>/dev/null && \
  fail "published upload must fail when darwin tarball upload fails"
checksum_uploaded=false
for line in "${TEST_UPLOAD_CB_CALLS[@]}"; do
  [[ "$line" == *checksums.txt* ]] && checksum_uploaded=true
done
[[ "$checksum_uploaded" == false ]] || \
  fail "checksums.txt must not upload after tarball failure"
ok "published upload fails closed on tarball callback error"

TEST_UPLOAD_CB_CALLS=()
release_publish__test_cb_fail_draft_clobber() {
  # shellcheck disable=SC2034
  local -n _cmd=$1
  TEST_UPLOAD_CB_CALLS+=( "$(release_publish__argv_to_line "${_cmd[@]}")" )
  return 1
}
state_draft_upload="$(mktemp)"
write_state true "" "$linux_h" "" "$linux_name $darwin_name" false >"$state_draft_upload"
plan_draft_upload="$(release_publish__plan_from_state_file "$state_draft_upload")"
[[ "$(echo "$plan_draft_upload" | jq -r '.checksums_upload_action')" == \
  "clobber_with_draft" ]] || fail "draft must plan clobber_with_draft"
release_publish__write_checksums_file "$asset_dir/checksums.txt" \
  "$(echo "$plan_draft_upload" | jq -r '.checksums_body')"
release_publish__invoke_each_upload_argv_from_plan \
  "$plan_draft_upload" "$asset_dir" "v7.2.1" "o/r" \
  release_publish__test_cb_fail_draft_clobber 2>/dev/null && \
  fail "draft clobber upload must fail when callback fails"
ok "draft upload fails closed on callback error"

write_plan_checksums_fixture() {
  local plan="$1"
  release_publish__write_checksums_file "$asset_dir/checksums.txt" \
    "$(echo "$plan" | jq -r '.checksums_body')"
}

rm -rf "$asset_dir/checksums.txt"
mkdir -p "$asset_dir/checksums.txt"
release_publish__write_checksums_file "$asset_dir/checksums.txt" \
  "$(echo "$plan_pub_upload" | jq -r '.checksums_body')" 2>/dev/null && \
  fail "write_checksums_file must fail when path is a directory"
rm -rf "$asset_dir/checksums.txt"
contract_ok "write_checksums_file fails closed on bad path"

# shellcheck source=../release/publish_release_assets.sh
source "$SCRIPT"
release_publish__cb_run_argv_contract() {
  # shellcheck disable=SC2034
  local -n _cmd=$1
  if [[ "${_cmd[*]}" == *"$darwin_name"* && "${_cmd[*]}" != *checksums.txt* ]]; then
    return 1
  fi
  return 0
}
release_publish__cb_run_argv() { release_publish__cb_run_argv_contract "$@"; }
rm -f "$asset_dir/checksums.txt"
mkdir -p "$asset_dir/checksums.txt"
release_publish__run_verify_and_upload \
  "$plan_pub_upload" "$asset_dir" "" "" "v7.2.1" "o/r" "false" \
  >/dev/null 2>&1 && fail "run_verify_and_upload must fail when checksums write fails"
rm -rf "$asset_dir/checksums.txt"
write_plan_checksums_fixture "$plan_pub_upload"
contract_ok "run_verify_and_upload fails closed when checksums write fails"
publish_snippet_out=""
if release_publish__run_verify_and_upload \
  "$plan_pub_upload" "$asset_dir" "" "" "v7.2.1" "o/r" "false" \
  >/dev/null 2>&1; then
  publish_snippet_out="publish_release_assets: published stub"
fi
[[ -z "$publish_snippet_out" ]] || \
  fail "must not reach published success path after upload failure"

contract_ok "release publish plan contracts OK"
