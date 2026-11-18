#!/usr/bin/env bash
# Publish release tarballs: draft releases use --clobber; published releases fill gaps only.
set -euo pipefail

TAG="${1:-}"
ASSET_DIR="${2:-}"

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
  local tmpdir
  tmpdir="$(mktemp -d)"
  download_remote_asset_to "$asset_name" "$tmpdir"
  file_sha256 "$tmpdir/$asset_name"
  rm -rf "$tmpdir"
}

declare -a upload_paths=()
declare -a all_tar_names=("${local_tar_names[@]}")

if [[ "$is_draft" == "true" ]]; then
  upload_paths=( "${local_tars[@]}" )
else
  for tar_path in "${local_tars[@]}"; do
    base="$(basename "$tar_path")"
    if [[ -n "${remote_names[$base]:-}" ]]; then
      remote_hash="$(remote_asset_sha256 "$base")"
      local_hash="$(file_sha256 "$tar_path")"
      [[ "$remote_hash" == "$local_hash" ]] || \
        fail "refusing to overwrite published asset $base (checksum mismatch)"
      ok "keeping published asset $base (checksum match)"
    else
      upload_paths+=( "$tar_path" )
    fi
  done
  for remote_name in "${!remote_names[@]}"; do
    if [[ "$remote_name" == *.tar.gz ]]; then
      if [[ ! " ${local_tar_names[*]} " =~ " ${remote_name} " ]]; then
        all_tar_names+=( "$remote_name" )
      fi
    fi
  done
  mapfile -t all_tar_names < <(printf '%s\n' "${all_tar_names[@]}" | sort -u)
fi

checksums_path="$ASSET_DIR/checksums.txt"
{
  for name in "${all_tar_names[@]}"; do
    local_path="$ASSET_DIR/$name"
    if [[ -f "$local_path" ]]; then
      sha256sum "$local_path"
    elif [[ -n "${remote_names[$name]:-}" ]]; then
      tmpdir="$(mktemp -d)"
      download_remote_asset_to "$name" "$tmpdir"
      sha256sum "$tmpdir/$name"
      rm -rf "$tmpdir"
    else
      fail "cannot checksum missing asset $name"
    fi
  done
} >"$checksums_path"

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

verify_dir="$(mktemp -d)"
cleanup() { rm -rf "$verify_dir"; }
trap cleanup EXIT

gh release download "$TAG" \
  --repo "$GITHUB_REPOSITORY" \
  --dir "$verify_dir" \
  --pattern '*.tar.gz' \
  --pattern 'checksums.txt'

(
  cd "$verify_dir"
  sha256sum -c checksums.txt
) || fail "post-upload checksum verification failed for $TAG"

ok "published ${#local_tar_names[@]} local tarball(s); draft=$is_draft; new_uploads=${#upload_paths[@]}"
