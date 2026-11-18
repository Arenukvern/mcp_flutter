# shellcheck shell=bash
# Pure helpers for release asset publish / checksum planning (sourced by scripts and contract tests).

release_publish__checksum_line_basename() {
  local file_path="$1"
  local dir name hash
  dir="$(dirname "$file_path")"
  name="$(basename "$file_path")"
  hash="$(sha256sum "$file_path" | awk '{print $1}')"
  printf '%s  %s\n' "$hash" "$name"
}

release_publish__checksum_line_valid() {
  local line="$1"
  [[ "$line" =~ ^[0-9a-f]{64}\ \ [^/[:space:]]+$ ]]
}

release_publish__hash_for_basename_in_checksums() {
  local checksums_file="$1"
  local basename="$2"
  [[ -f "$checksums_file" ]] || return 1
  awk -v asset="$basename" '$2 == asset { print $1; exit }' "$checksums_file"
}

release_publish__merge_sorted_tar_names() {
  local -a names=("$@")
  printf '%s\n' "${names[@]}" | sed '/^$/d' | sort -u
}

# stdout: names that must appear in checksums.txt (local union remote-only).
release_publish__all_tar_names_for_checksums() {
  local is_draft="$1"
  shift
  local -a local_names=("$@")
  if [[ "$is_draft" == "true" ]]; then
    release_publish__merge_sorted_tar_names "${local_names[@]}"
    return 0
  fi
  local remote_csv="${RELEASE_PUBLISH_REMOTE_TAR_CSV:-}"
  local -a remote_only=()
  if [[ -n "$remote_csv" ]]; then
    local remote
    for remote in ${remote_csv//,/ }; do
      [[ -n "$remote" ]] || continue
      local found=false
      for local_name in "${local_names[@]}"; do
        if [[ "$remote" == "$local_name" ]]; then
          found=true
          break
        fi
      done
      if [[ "$found" != true ]]; then
        remote_only+=( "$remote" )
      fi
    done
  fi
  release_publish__merge_sorted_tar_names "${local_names[@]}" "${remote_only[@]}"
}

# Decide action for a tarball already on a published release when local copy exists.
# Emits: keep | upload | fail_mismatch
release_publish__published_collision_action() {
  local local_hash="$1"
  local remote_hash="$2"
  if [[ "$local_hash" == "$remote_hash" ]]; then
    echo keep
  else
    echo fail_mismatch
  fi
}

# Verify a downloaded asset hash against already-published checksums.txt (authenticity).
# When the published manifest has no line, returns 0 (caller may use byte comparison only).
release_publish__verify_against_published_checksums() {
  local checksums_file="$1"
  local basename="$2"
  local actual_hash="$3"
  local expected
  expected="$(release_publish__hash_for_basename_in_checksums "$checksums_file" "$basename" || true)"
  [[ -n "$expected" ]] || return 0
  [[ "$expected" == "$actual_hash" ]]
}