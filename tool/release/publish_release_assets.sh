#!/usr/bin/env bash
# Publish release tarballs: draft releases use --clobber; published releases fill gaps only.
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

if [[ "${1:-}" == --plan ]]; then
  state_file="${2:-}"
  [[ -f "$state_file" ]] || fail "usage: publish_release_assets.sh --plan <state.json>"
  asset_dir="$(jq -r '.asset_dir' "$state_file")"
  [[ -d "$asset_dir" ]] || fail "asset_dir missing in state"
  plan="$(release_publish__plan_from_state_file "$state_file")"
  echo "$plan"
  plan_ok="$(echo "$plan" | jq -r '.ok')"
  [[ "$plan_ok" == "true" ]] || fail "$(echo "$plan" | jq -r '.error')"
  checksums_body="$(echo "$plan" | jq -r '.checksums_body')"
  verify_dir="$(mktemp -d)"
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    cp "$asset_dir/$name" "$verify_dir/$name" 2>/dev/null || \
      fail "plan verify missing $name in asset_dir"
  done < <(echo "$plan" | jq -r '.checksum_tar_names[]?')
  release_publish__verify_checksums_in_dir "$verify_dir" "$checksums_body" || \
    fail "plan mode sha256sum -c failed"
  release_publish__safe_cleanup "$verify_dir" ""
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

file_sha256() {
  sha256sum "$1" | awk '{print $1}'
}

release_json="$(gh release view "$TAG" --repo "$GITHUB_REPOSITORY" --json isDraft,assets)"
is_draft="$(echo "$release_json" | jq -r '.isDraft')"

mapfile -t local_tar_names < <(
  for f in "${local_tars[@]}"; do basename "$f"; done | sort -u
)

remote_assets_json="$(echo "$release_json" | jq -c '[.assets[] | {name: .name}]')"
published_checksums=""
published_checksums_dir=""
if [[ "$is_draft" != "true" ]] && \
  echo "$release_json" | jq -e '.assets[] | select(.name=="checksums.txt")' >/dev/null; then
  published_checksums_dir="$(mktemp -d)"
  gh release download "$TAG" \
    --repo "$GITHUB_REPOSITORY" \
    --dir "$published_checksums_dir" \
    --pattern checksums.txt
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
  --arg asset_dir "$ASSET_DIR" \
  --arg published_checksums "$published_checksums" \
  --argjson local_tars "$(printf '%s\n' "${local_tar_names[@]}" | jq -R . | jq -s .)" \
  --argjson remote_assets "$remote_assets_json" \
  --argjson local_hashes "$local_hashes_json" \
  --argjson remote_hashes "$remote_hashes_json" \
  '{
    is_draft: $is_draft,
    asset_dir: $asset_dir,
    published_checksums: (if $published_checksums=="" then null else $published_checksums end),
    local_tars: $local_tars,
    remote_assets: $remote_assets,
    local_hashes: $local_hashes,
    remote_hashes: $remote_hashes
  }' >"$state_file"

plan="$(release_publish__plan_from_state_file "$state_file")"
rm -f "$state_file"
plan_ok="$(echo "$plan" | jq -r '.ok')"
[[ "$plan_ok" == "true" ]] || fail "$(echo "$plan" | jq -r '.error')"

checksums_body="$(echo "$plan" | jq -r '.checksums_body')"
checksums_path="$ASSET_DIR/checksums.txt"
printf '%s' "$checksums_body" >"$checksums_path"

verify_dir="$(mktemp -d)"
trap 'release_publish__safe_cleanup "$verify_dir" "$published_checksums_dir"' EXIT

while IFS= read -r name; do
  [[ -n "$name" ]] || continue
  if [[ -f "$ASSET_DIR/$name" ]]; then
    cp "$ASSET_DIR/$name" "$verify_dir/$name"
  else
    gh release download "$TAG" \
      --repo "$GITHUB_REPOSITORY" \
      --dir "$verify_dir" \
      --pattern "$name"
    if [[ -n "$published_checksums" && "$name" == *.tar.gz ]]; then
      release_publish__verify_listed_remote_hash \
        "$published_checksums_dir/checksums.txt" "$name" \
        "$(file_sha256 "$verify_dir/$name")" || \
        fail "pre-upload verify: $name vs published checksums.txt"
    fi
  fi
done < <(echo "$plan" | jq -r '.checksum_tar_names[]?')

release_publish__verify_checksums_in_dir "$verify_dir" "$checksums_body" || \
  fail "pre-upload checksum verification failed for $TAG"
release_publish__safe_cleanup "$verify_dir" "$published_checksums_dir"
trap - EXIT
published_checksums_dir=""

if [[ "$is_draft" == "true" ]]; then
  gh release upload "$TAG" \
    --repo "$GITHUB_REPOSITORY" \
    --clobber \
    "${local_tars[@]}" "$checksums_path"
else
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    gh release upload "$TAG" \
      --repo "$GITHUB_REPOSITORY" \
      "$ASSET_DIR/$name"
  done < <(echo "$plan" | jq -r '.upload_local_names[]?')

  case "$(echo "$plan" | jq -r '.checksums_upload_action')" in
    upload_new|upload_checksums_superset)
      if [[ "$(echo "$plan" | jq -r '.checksums_upload_action')" == upload_checksums_superset ]]; then
        gh release upload "$TAG" \
          --repo "$GITHUB_REPOSITORY" \
          --clobber \
          "$checksums_path"
      else
        gh release upload "$TAG" \
          --repo "$GITHUB_REPOSITORY" \
          "$checksums_path"
      fi
      ;;
    clobber_with_draft)
      gh release upload "$TAG" \
        --repo "$GITHUB_REPOSITORY" \
        --clobber \
        "${local_tars[@]}" "$checksums_path"
      ;;
    keep_checksums)
      ok "keeping published checksums.txt"
      ;;
  esac
fi

upload_count="$(echo "$plan" | jq -r '.upload_local_names | length')"
ok "published ${#local_tar_names[@]} local tarball(s); draft=$is_draft; new_uploads=$upload_count"