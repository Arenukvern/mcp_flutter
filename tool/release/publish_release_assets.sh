#!/usr/bin/env bash
# Publish release tarballs: draft releases use --clobber; published releases fill gaps only.
set -euo pipefail

TAG="${1:-}"
ASSET_DIR="${2:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=release_publish_lib.sh
source "$ROOT_DIR/tool/release/release_publish_lib.sh"

fail() { echo "publish_release_assets: $*" >&2; exit 1; }
ok() { echo "publish_release_assets: $*"; }

[[ -n "$TAG" && -d "$ASSET_DIR" ]] || fail "usage: publish_release_assets.sh <tag> <asset-dir>"

command -v gh >/dev/null 2>&1 || fail "gh CLI required"
command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -n "${GITHUB_REPOSITORY:-}" ]] || fail "GITHUB_REPOSITORY required"

shopt -s nullglob
local_tars=( "$ASSET_DIR"/*.tar.gz )
[[ ${#local_tars[@]} -gt 0 ]] || fail "no local *.tar.gz in $ASSET_DIR"

mapfile -t local_tar_names < <(
  for f in "${local_tars[@]}"; do basename "$f"; done | sort -u
)

release_json="$(gh release view "$TAG" --repo "$GITHUB_REPOSITORY" --json isDraft,assets)"
is_draft="$(echo "$release_json" | jq -r '.isDraft')"

declare -A remote_names=()
while IFS= read -r name; do
  [[ -n "$name" ]] || continue
  remote_names["$name"]=1
done < <(echo "$release_json" | jq -r '.assets[].name')

published_checksums_path=""
published_checksums_dir=""
if [[ "$is_draft" != "true" && -n "${remote_names[checksums.txt]:-}" ]]; then
  published_checksums_dir="$(mktemp -d)"
  gh release download "$TAG" \
    --repo "$GITHUB_REPOSITORY" \
    --dir "$published_checksums_dir" \
    --pattern checksums.txt
  published_checksums_path="$published_checksums_dir/checksums.txt"
  [[ -f "$published_checksums_path" ]] || \
    fail "release lists checksums.txt but download failed"
fi

file_sha256() {
  sha256sum "$1" | awk '{print $1}'
}

download_remote_asset_to() {
  local asset_name="$1"
  local dest_dir="$2"
  gh release download "$TAG" \
    --repo "$GITHUB_REPOSITORY" \
    --dir "$dest_dir" \
    --pattern "$asset_name"
}

remote_asset_sha256() {
  local asset_name="$1"
  local tmpdir hash
  tmpdir="$(mktemp -d)"
  download_remote_asset_to "$asset_name" "$tmpdir"
  hash="$(file_sha256 "$tmpdir/$asset_name")"
  rm -rf "$tmpdir"
  if [[ -n "$published_checksums_path" ]]; then
    release_publish__verify_against_published_checksums \
      "$published_checksums_path" "$asset_name" "$hash" || \
      fail "remote asset $asset_name fails published checksums.txt authenticity"
  fi
  printf '%s' "$hash"
}

declare -a upload_paths=()

if [[ "$is_draft" == "true" ]]; then
  upload_paths=( "${local_tars[@]}" )
else
  for tar_path in "${local_tars[@]}"; do
    base="$(basename "$tar_path")"
    if [[ -n "${remote_names[$base]:-}" ]]; then
      remote_hash="$(remote_asset_sha256 "$base")"
      local_hash="$(file_sha256 "$tar_path")"
      action="$(release_publish__published_collision_action "$local_hash" "$remote_hash")"
      case "$action" in
        keep) ok "keeping published asset $base (checksum match)" ;;
        fail_mismatch)
          fail "refusing to overwrite published asset $base (checksum mismatch)"
          ;;
      esac
    else
      upload_paths+=( "$tar_path" )
    fi
  done
fi

remote_tar_csv=""
for remote_name in "${!remote_names[@]}"; do
  [[ "$remote_name" == *.tar.gz ]] || continue
  if [[ -n "$remote_tar_csv" ]]; then
    remote_tar_csv+=","
  fi
  remote_tar_csv+="$remote_name"
done
export RELEASE_PUBLISH_REMOTE_TAR_CSV="$remote_tar_csv"
mapfile -t all_tar_names < <(release_publish__all_tar_names_for_checksums \
  "$is_draft" "${local_tar_names[@]}")

checksums_path="$ASSET_DIR/checksums.txt"
write_checksum_line() {
  local name="$1"
  local local_path="$ASSET_DIR/$name"
  local line hash
  if [[ -f "$local_path" ]]; then
    line="$(release_publish__checksum_line_basename "$local_path")"
  elif [[ -n "${remote_names[$name]:-}" ]]; then
    local tmpdir tmpfile
    tmpdir="$(mktemp -d)"
    download_remote_asset_to "$name" "$tmpdir"
    tmpfile="$tmpdir/$name"
    hash="$(file_sha256 "$tmpfile")"
    if [[ -n "$published_checksums_path" ]]; then
      release_publish__verify_against_published_checksums \
        "$published_checksums_path" "$name" "$hash" || \
        fail "remote asset $name fails published checksums.txt authenticity"
    fi
    line="$(release_publish__checksum_line_basename "$tmpfile")"
    rm -rf "$tmpdir"
  else
    fail "cannot checksum missing asset $name"
  fi
  release_publish__checksum_line_valid "$line" || \
    fail "internal checksum line format error for $name"
  printf '%s\n' "$line"
}

{
  for name in "${all_tar_names[@]}"; do
    write_checksum_line "$name"
  done
} >"$checksums_path"

verify_dir="$(mktemp -d)"
preverify_cleanup() {
  rm -rf "$verify_dir"
  [[ -n "$published_checksums_dir" ]] && rm -rf "$published_checksums_dir"
}
trap preverify_cleanup EXIT

for name in "${all_tar_names[@]}"; do
  local_path="$ASSET_DIR/$name"
  if [[ -f "$local_path" ]]; then
    cp "$local_path" "$verify_dir/$name"
  elif [[ -n "${remote_names[$name]:-}" ]]; then
    download_remote_asset_to "$name" "$verify_dir"
    if [[ -n "$published_checksums_path" ]]; then
      release_publish__verify_against_published_checksums \
        "$published_checksums_path" "$name" "$(file_sha256 "$verify_dir/$name")" || \
        fail "pre-upload verify: $name vs published checksums.txt"
    fi
  else
    fail "pre-upload verify missing tarball $name"
  fi
done
cp "$checksums_path" "$verify_dir/checksums.txt"
(
  cd "$verify_dir"
  sha256sum -c checksums.txt
) || fail "pre-upload checksum verification failed for $TAG"
preverify_cleanup
trap - EXIT

if [[ "$is_draft" == "true" ]]; then
  gh release upload "$TAG" \
    --repo "$GITHUB_REPOSITORY" \
    --clobber \
    "${local_tars[@]}" "$checksums_path"
else
  if [[ ${#upload_paths[@]} -gt 0 ]]; then
    gh release upload "$TAG" \
      --repo "$GITHUB_REPOSITORY" \
      "${upload_paths[@]}"
  fi
  if [[ -z "${remote_names[checksums.txt]:-}" ]]; then
    gh release upload "$TAG" \
      --repo "$GITHUB_REPOSITORY" \
      "$checksums_path"
  else
    remote_sum="$(remote_asset_sha256 checksums.txt)"
    local_sum="$(file_sha256 "$checksums_path")"
    if [[ "$remote_sum" != "$local_sum" ]]; then
      gh release upload "$TAG" \
        --repo "$GITHUB_REPOSITORY" \
        --clobber \
        "$checksums_path"
    fi
  fi
fi

ok "published ${#local_tar_names[@]} local tarball(s); draft=$is_draft; new_uploads=${#upload_paths[@]}"