#!/usr/bin/env bash
# Publish release tarballs using a shared upload plan (draft clobber vs published gap-fill).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=release_publish_lib.sh
source "$ROOT_DIR/tool/release/release_publish_lib.sh"

fail() { echo "publish_release_assets: $*" >&2; exit 1; }
ok() { echo "publish_release_assets: $*"; }

release_publish__safe_cleanup() {
  local verify_dir="${1:-}"
  local published_dir="${2:-}"
  if [[ -n "$verify_dir" ]]; then
    rm -rf "$verify_dir"
  fi
  if [[ -n "$published_dir" ]]; then
    rm -rf "$published_dir"
  fi
  return 0
}

file_sha256() {
  sha256sum "$1" | awk '{print $1}'
}

release_publish__run_verify_and_upload() {
  local plan="$1"
  local asset_dir="$2"
  local remote_fixture_dir="${3:-}"
  local published_checksums_file="${4:-}"
  local gh_tag="${5:-}"
  local gh_repo="${6:-}"
  local dry_run="${7:-false}"

  release_publish__plan_assert_ok "$plan" || return 1

  local checksums_body
  checksums_body="$(echo "$plan" | jq -r '.checksums_body')"
  local verify_dir
  verify_dir="$(mktemp -d)"

  release_publish__stage_verify_assets \
    "$plan" "$asset_dir" "$verify_dir" \
    "$remote_fixture_dir" "$published_checksums_file" \
    "$gh_tag" "$gh_repo" || {
      release_publish__safe_cleanup "$verify_dir" ""
      return 1
    }

  release_publish__verify_checksums_in_dir "$verify_dir" "$checksums_body" || {
    release_publish__safe_cleanup "$verify_dir" ""
    return 1
  }

  local tag_placeholder="${gh_tag:-$RELEASE_PUBLISH_PLAN_GH_TAG}"
  local repo_placeholder="${gh_repo:-$RELEASE_PUBLISH_PLAN_GH_REPO}"

  local checksums_path="$asset_dir/checksums.txt"
  release_publish__write_checksums_file "$checksums_path" "$checksums_body" || return 1

  if [[ "$dry_run" == "true" ]]; then
    release_publish__emit_plan_dry_run_trailer \
      "$plan" "$asset_dir" "$verify_dir" \
      "$tag_placeholder" "$repo_placeholder"
    release_publish__safe_cleanup "$verify_dir" ""
    return 0
  fi

  release_publish__safe_cleanup "$verify_dir" ""

  release_publish__execute_upload_from_plan \
    "$plan" "$asset_dir" "$gh_tag" "$gh_repo" || return 1
}

publish_release_assets__main() {
if [[ "${1:-}" == --plan ]]; then
  state_file="${2:-}"
  [[ -f "$state_file" ]] || fail "usage: publish_release_assets.sh --plan <state.json>"
  asset_dir="$(jq -r '.asset_dir' "$state_file")"
  [[ -d "$asset_dir" ]] || fail "asset_dir missing in state"
  remote_fixture_dir="$(jq -r '.remote_fixture_dir // empty' "$state_file")"

  plan="$(release_publish__plan_from_state_file "$state_file")"
  echo "$plan"
  release_publish__plan_assert_ok "$plan" || fail "$(echo "$plan" | jq -r '.error')"

  published_manifest=""
  pub_manifest_tmp=""
  if [[ -n "$(jq -r '.published_checksums // empty' "$state_file")" ]]; then
    pub_manifest_tmp="$(mktemp)"
    jq -r '.published_checksums' "$state_file" >"$pub_manifest_tmp"
    published_manifest="$pub_manifest_tmp"
  fi

  release_publish__run_verify_and_upload \
    "$plan" "$asset_dir" "$remote_fixture_dir" "$published_manifest" \
    "" "" "true" || fail "plan mode verify failed"
  [[ -n "$pub_manifest_tmp" ]] && rm -f "$pub_manifest_tmp"
  ok "plan mode OK"
  exit 0
fi

TAG="${1:-}"
ASSET_DIR="${2:-}"
[[ -n "$TAG" && -d "$ASSET_DIR" ]] || fail "usage: publish_release_assets.sh <tag> <asset-dir>"

command -v gh >/dev/null 2>&1 || fail "gh CLI required"
command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -n "${GITHUB_REPOSITORY:-}" ]] || fail "GITHUB_REPOSITORY required"

shopt -s nullglob
local_tars=( "$ASSET_DIR"/*.tar.gz )
[[ ${#local_tars[@]} -gt 0 ]] || fail "no local *.tar.gz in $ASSET_DIR"

release_json="$(gh release view "$TAG" --repo "$GITHUB_REPOSITORY" --json isDraft,assets)"
is_draft="$(echo "$release_json" | jq -r '.isDraft')"

mapfile -t local_tar_names < <(
  for f in "${local_tars[@]}"; do basename "$f"; done | sort -u
)

remote_assets_json="$(echo "$release_json" | jq -c '[.assets[] | {name: .name}]')"
checksums_asset_present="$(echo "$release_json" | jq \
  '[(.assets[]?.name // "")] | index("checksums.txt") != null')"

published_checksums=""
published_checksums_dir=""
if [[ "$is_draft" != "true" && "$checksums_asset_present" == "true" ]]; then
  published_checksums_dir="$(mktemp -d)"
  gh release download "$TAG" \
    --repo "$GITHUB_REPOSITORY" \
    --dir "$published_checksums_dir" \
    --pattern checksums.txt
  if [[ ! -s "$published_checksums_dir/checksums.txt" ]]; then
    fail "published checksums.txt is empty (invalid)"
  fi
  published_checksums="$(cat "$published_checksums_dir/checksums.txt")"
  release_publish__validate_checksums_manifest "$published_checksums_dir/checksums.txt" || \
    fail "published checksums.txt has invalid lines"
fi

declare -A remote_hashes=()
while IFS= read -r remote_name; do
  [[ -n "$remote_name" ]] || continue
  tmpd="$(mktemp -d)"
  gh release download "$TAG" \
    --repo "$GITHUB_REPOSITORY" \
    --dir "$tmpd" \
    --pattern "$remote_name"
  remote_hashes["$remote_name"]="$(file_sha256 "$tmpd/$remote_name")"
  rm -rf "$tmpd"
done < <(echo "$release_json" | jq -r '.assets[].name')

declare -A local_hashes=()
for f in "${local_tars[@]}"; do
  local_hashes["$(basename "$f")"]="$(file_sha256 "$f")"
done

local_hashes_json='{}'
for n in "${!local_hashes[@]}"; do
  local_hashes_json="$(jq -c --arg k "$n" --arg v "${local_hashes[$n]}" \
    '. + {($k): $v}' <<<"$local_hashes_json")"
done
remote_hashes_json='{}'
for n in "${!remote_hashes[@]}"; do
  remote_hashes_json="$(jq -c --arg k "$n" --arg v "${remote_hashes[$n]}" \
    '. + {($k): $v}' <<<"$remote_hashes_json")"
done

state_file="$(mktemp)"
jq -n \
  --argjson is_draft "$(echo "$release_json" | jq '.isDraft')" \
  --argjson published_checksums_asset_present \
    "$(if [[ "$is_draft" == "true" ]]; then echo false; else echo "$checksums_asset_present"; fi)" \
  --arg asset_dir "$ASSET_DIR" \
  --arg published_checksums "$published_checksums" \
  --argjson local_tars "$(printf '%s\n' "${local_tar_names[@]}" | jq -R . | jq -s .)" \
  --argjson remote_assets "$remote_assets_json" \
  --argjson local_hashes "$local_hashes_json" \
  --argjson remote_hashes "$remote_hashes_json" \
  '{
    is_draft: $is_draft,
    published_checksums_asset_present: $published_checksums_asset_present,
    asset_dir: $asset_dir,
    published_checksums: (if $published_checksums=="" then null else $published_checksums end),
    local_tars: $local_tars,
    remote_assets: $remote_assets,
    local_hashes: $local_hashes,
    remote_hashes: $remote_hashes
  }' >"$state_file"

plan="$(release_publish__plan_from_state_file "$state_file")"
rm -f "$state_file"
release_publish__plan_assert_ok "$plan" || fail "$(echo "$plan" | jq -r '.error')"

pub_manifest_file=""
if [[ -n "$published_checksums_dir" && -f "$published_checksums_dir/checksums.txt" ]]; then
  pub_manifest_file="$published_checksums_dir/checksums.txt"
fi

trap 'release_publish__safe_cleanup "" "$published_checksums_dir"' EXIT
release_publish__run_verify_and_upload \
  "$plan" "$ASSET_DIR" "" "$pub_manifest_file" \
  "$TAG" "$GITHUB_REPOSITORY" "false" || fail "publish verify/upload failed"
release_publish__safe_cleanup "" "$published_checksums_dir"
trap - EXIT
published_checksums_dir=""

upload_count="$(echo "$plan" | jq '[.upload_local_names[]? | select(. != "")] | length')"
ok "published ${#local_tar_names[@]} local tarball(s); draft=$is_draft; new_uploads=$upload_count"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  publish_release_assets__main "$@"
fi
