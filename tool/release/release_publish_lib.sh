# shellcheck shell=bash
# Pure helpers for release asset publish / checksum planning (sourced by scripts and contract tests).

release_publish__checksum_line_basename() {
  local file_path="$1"
  local name hash
  name="$(basename "$file_path")"
  hash="$(sha256sum "$file_path" | awk '{print $1}')"
  printf '%s  %s\n' "$hash" "$name"
}

release_publish__checksum_line_from_parts() {
  local hash="$1"
  local basename="$2"
  printf '%s  %s\n' "$hash" "$basename"
}

release_publish__checksum_line_valid() {
  local line="$1"
  [[ "$line" =~ ^[0-9a-f]{64}\ \ [^/[:space:]]+$ ]]
}

release_publish__validate_checksums_manifest() {
  local checksums_file="$1"
  [[ -f "$checksums_file" ]] || return 1
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    release_publish__checksum_line_valid "$line" || return 1
  done <"$checksums_file"
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

release_publish__checksum_tar_names() {
  local is_draft="$1"
  local remote_csv="${2:-}"
  shift 2
  local -a local_names=("$@")
  if [[ "$is_draft" == "true" ]]; then
    release_publish__merge_sorted_tar_names "${local_names[@]}"
    return 0
  fi
  local -a remote_only=()
  if [[ -n "$remote_csv" ]]; then
    local remote
    for remote in ${remote_csv//,/ }; do
      [[ -n "$remote" && "$remote" == *.tar.gz ]] || continue
      local found=false
      for local_name in "${local_names[@]}"; do
        [[ "$remote" == "$local_name" ]] && found=true && break
      done
      [[ "$found" == true ]] || remote_only+=( "$remote" )
    done
  fi
  release_publish__merge_sorted_tar_names "${local_names[@]}" "${remote_only[@]}"
}

release_publish__published_collision_action() {
  local local_hash="$1"
  local remote_hash="$2"
  if [[ "$local_hash" == "$remote_hash" ]]; then
    echo keep
  else
    echo fail_mismatch
  fi
}

release_publish__verify_listed_remote_hash() {
  local checksums_file="$1"
  local basename="$2"
  local actual_hash="$3"
  local expected
  expected="$(release_publish__hash_for_basename_in_checksums "$checksums_file" "$basename" || true)"
  [[ -n "$expected" ]] || return 1
  [[ "$expected" == "$actual_hash" ]]
}

release_publish__checksums_strict_superset() {
  local old_file="$1"
  local new_file="$2"
  [[ -f "$old_file" && -f "$new_file" ]] || return 1
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    grep -qxF "$line" "$new_file" || return 1
  done <"$old_file"
}

release_publish__normalize_manifest_text() {
  local content="$1"
  printf '%s\n' "${content%$'\n'}"
}

release_publish__checksums_manifest_files_equal() {
  local old_file="$1"
  local new_file="$2"
  cmp -s \
    <(grep -v '^[[:space:]]*$' "$old_file" | sort) \
    <(grep -v '^[[:space:]]*$' "$new_file" | sort)
}

RELEASE_PUBLISH_PLAN_GH_TAG="${RELEASE_PUBLISH_PLAN_GH_TAG:-__contract_tag__}"
RELEASE_PUBLISH_PLAN_GH_REPO="${RELEASE_PUBLISH_PLAN_GH_REPO:-__owner/repo__}"

release_publish__argv_to_line() {
  local arg first=true
  for arg in "$@"; do
    if [[ "$first" == true ]]; then
      printf '%q' "$arg"
      first=false
    else
      printf ' %q' "$arg"
    fi
  done
  printf '\n'
}

release_publish__cb_print_argv() {
  # shellcheck disable=SC2034
  local -n _cmd=$1
  release_publish__argv_to_line "${_cmd[@]}"
}

release_publish__cb_run_argv() {
  # shellcheck disable=SC2034
  local -n _cmd=$1
  "${_cmd[@]}"
}

release_publish__invoke_release_download_argv() {
  local gh_tag="$1"
  local gh_repo="$2"
  local verify_dir="$3"
  local pattern="$4"
  local callback="$5"
  local -a argv=(
    gh release download "$gh_tag" --repo "$gh_repo" \
      --dir "$verify_dir" --pattern "$pattern"
  )
  "$callback" argv || return 1
}

release_publish__invoke_each_staging_argv_from_plan() {
  local plan="$1"
  local asset_dir="$2"
  local verify_dir="$3"
  local gh_tag="$4"
  local gh_repo="$5"
  local callback="$6"
  local name
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    [[ -f "$asset_dir/$name" ]] && continue
    release_publish__invoke_release_download_argv \
      "$gh_tag" "$gh_repo" "$verify_dir" "$name" "$callback" || return 1
  done < <(echo "$plan" | jq -r '.checksum_tar_names[]?')
}

release_publish__invoke_each_upload_argv_from_plan() {
  local plan="$1"
  local asset_dir="$2"
  local gh_tag="$3"
  local gh_repo="$4"
  local callback="$5"

  local checksums_path="$asset_dir/checksums.txt"
  local action
  action="$(echo "$plan" | jq -r '.checksums_upload_action')"
  local -a argv=()
  local name

  if [[ "$action" == "clobber_with_draft" ]]; then
    local -a upload_paths=()
    while IFS= read -r name; do
      [[ -n "$name" ]] || continue
      upload_paths+=( "$asset_dir/$name" )
    done < <(echo "$plan" | jq -r '.upload_local_names[]?')
    upload_paths+=( "$checksums_path" )
    argv=(gh release upload "$gh_tag" --repo "$gh_repo" --clobber "${upload_paths[@]}")
    "$callback" argv || return 1
  else
    while IFS= read -r name; do
      [[ -n "$name" ]] || continue
      # shellcheck disable=SC2034 # nameref target for upload callback
      argv=(gh release upload "$gh_tag" --repo "$gh_repo" "$asset_dir/$name")
      "$callback" argv || return 1
    done < <(echo "$plan" | jq -r '.upload_local_names[]?')

    case "$action" in
      upload_new)
        # shellcheck disable=SC2034 # nameref target for upload callback
        argv=(gh release upload "$gh_tag" --repo "$gh_repo" "$checksums_path")
        "$callback" argv || return 1
        ;;
      upload_checksums_superset)
        # shellcheck disable=SC2034 # nameref target for upload callback
        argv=(gh release upload "$gh_tag" --repo "$gh_repo" \
          --clobber "$checksums_path")
        "$callback" argv || return 1
        ;;
      keep_checksums) ;;
      *)
        echo "release_publish: unknown checksums_upload_action: $action" >&2
        return 1
        ;;
    esac
  fi
}

release_publish__emit_plan_dry_run_trailer() {
  local plan="$1"
  local asset_dir="$2"
  local verify_dir="$3"
  local gh_tag="$4"
  local gh_repo="$5"
  local checksums_path="$asset_dir/checksums.txt"
  echo '---COMMANDS---'
  release_publish__invoke_each_staging_argv_from_plan \
    "$plan" "$asset_dir" "$verify_dir" "$gh_tag" "$gh_repo" \
    release_publish__cb_print_argv
  release_publish__invoke_each_upload_argv_from_plan \
    "$plan" "$asset_dir" "$gh_tag" "$gh_repo" release_publish__cb_print_argv
  echo '---CHECKSUMS_PATH---'
  echo "$checksums_path"
  echo '---CHECKSUMS_BYTES_B64---'
  base64 -w0 <"$checksums_path"
  echo
}

release_publish__plan_emit_error() {
  local msg="$1"
  jq -cn --arg e "$msg" '{ok: false, error: $e}'
}

# Build publish plan JSON from state file (schema documented in test_release_publish_plan.sh).
release_publish__plan_from_state_file() {
  local state_file="$1"
  [[ -f "$state_file" ]] || {
    release_publish__plan_emit_error "missing state file"
    return 0
  }

  local is_draft
  is_draft="$(jq -r '.is_draft' "$state_file")"
  mapfile -t local_tars < <(jq -r '.local_tars[]?' "$state_file")
  [[ ${#local_tars[@]} -gt 0 ]] || {
    release_publish__plan_emit_error "no local tarballs"
    return 0
  }

  local published_checksums
  published_checksums="$(jq -r '.published_checksums // empty' "$state_file")"
  if [[ "$is_draft" != "true" ]] && \
    [[ "$(jq -r '.published_checksums_asset_present // false' "$state_file")" == "true" ]] && \
    [[ -z "${published_checksums//[[:space:]]/}" ]]; then
    release_publish__plan_emit_error "published checksums.txt is empty (invalid)"
    return 0
  fi
  if [[ -n "$published_checksums" ]]; then
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    release_publish__checksum_line_valid "$line" || {
      release_publish__plan_emit_error "unparseable published checksums line"
      return 0
    }
  done <<<"$published_checksums"
  fi

  local -a upload_locals=()
  local -a collision_actions=()

  if [[ "$is_draft" == "true" ]]; then
    upload_locals=( "${local_tars[@]}" )
  else
    local name local_h remote_h action
    for name in "${local_tars[@]}"; do
      remote_h="$(jq -r --arg n "$name" '.remote_hashes[$n] // empty' "$state_file")"
      if [[ -z "$remote_h" ]]; then
        upload_locals+=( "$name" )
        continue
      fi
      local_h="$(jq -r --arg n "$name" '.local_hashes[$n]' "$state_file")"
      action="$(release_publish__published_collision_action "$local_h" "$remote_h")"
      case "$action" in
        keep) collision_actions+=( "keep:$name" ) ;;
        fail_mismatch)
          release_publish__plan_emit_error "checksum mismatch for $name"
          return 0
          ;;
      esac
    done
  fi

  local remote_csv=""
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    [[ -n "$remote_csv" ]] && remote_csv+=","
    remote_csv+="$name"
  done < <(jq -r '.remote_assets[]?.name // empty | select(length>0)' "$state_file")
  mapfile -t checksum_names < <(release_publish__checksum_tar_names \
    "$is_draft" "$remote_csv" "${local_tars[@]}")

  if [[ -n "$published_checksums" && "$is_draft" != "true" ]]; then
    local tmp_manifest
    tmp_manifest="$(mktemp)"
    printf '%s' "$published_checksums" >"$tmp_manifest"
    local remote_name remote_hash
    while IFS= read -r remote_name; do
      [[ -n "$remote_name" && "$remote_name" == *.tar.gz ]] || continue
      remote_hash="$(jq -r --arg n "$remote_name" '.remote_hashes[$n] // empty' "$state_file")"
      [[ -n "$remote_hash" ]] || continue
      if ! release_publish__verify_listed_remote_hash \
        "$tmp_manifest" "$remote_name" "$remote_hash"; then
        local listed
        listed="$(release_publish__hash_for_basename_in_checksums \
          "$tmp_manifest" "$remote_name" || true)"
        if [[ -z "$listed" ]]; then
          release_publish__plan_emit_error \
            "unlisted remote tarball $remote_name in published checksums.txt"
        else
          release_publish__plan_emit_error \
            "remote hash disagrees with published checksums for $remote_name"
        fi
        rm -f "$tmp_manifest"
        return 0
      fi
    done < <(jq -r '.remote_assets[]?.name // empty' "$state_file")
    rm -f "$tmp_manifest"
  fi

  local checksums_body=""
  local n hash
  for n in "${checksum_names[@]}"; do
    hash="$(jq -r --arg n "$n" '.local_hashes[$n] // .remote_hashes[$n] // empty' "$state_file")"
    [[ -n "$hash" ]] || {
      release_publish__plan_emit_error "missing hash for $n"
      return 0
    }
    checksums_body+="$(release_publish__checksum_line_from_parts "$hash" "$n")"$'\n'
  done

  local checksums_action="upload_new"
  local has_remote_checksums
  has_remote_checksums="$(jq -r \
    '[(.remote_assets[]?.name // "")] | index("checksums.txt") != null' "$state_file")"
  if [[ "$is_draft" == "true" ]]; then
    checksums_action="clobber_with_draft"
  elif [[ "$has_remote_checksums" == "true" ]]; then
    if [[ -n "$published_checksums" ]]; then
      local tmp_new tmp_old
      tmp_new="$(mktemp)"
      tmp_old="$(mktemp)"
      printf '%s' "$checksums_body" >"$tmp_new"
      printf '%s' "$published_checksums" >"$tmp_old"
      if release_publish__checksums_strict_superset "$tmp_old" "$tmp_new"; then
        if release_publish__checksums_manifest_files_equal "$tmp_old" "$tmp_new"; then
          checksums_action="keep_checksums"
        else
          checksums_action="upload_checksums_superset"
        fi
      else
        release_publish__plan_emit_error \
          "checksums.txt must be strict superset of published manifest (unchanged lines)"
        rm -f "$tmp_new" "$tmp_old"
        return 0
      fi
      rm -f "$tmp_new" "$tmp_old"
    else
      local remote_ch local_ch
      remote_ch="$(jq -r '.remote_hashes["checksums.txt"] // empty' "$state_file")"
      local_ch="$(printf '%s' "$checksums_body" | sha256sum | awk '{print $1}')"
      if [[ -n "$remote_ch" && "$remote_ch" == "$local_ch" ]]; then
        checksums_action="keep_checksums"
      else
        checksums_action="upload_checksums_superset"
      fi
    fi
  fi

  jq -cn \
    --argjson draft "$is_draft" \
    --arg checksums "$checksums_body" \
    --arg checksums_action "$checksums_action" \
    --argjson upload_locals "$(printf '%s\n' "${upload_locals[@]}" | jq -R . | jq -s .)" \
    --argjson checksum_names "$(printf '%s\n' "${checksum_names[@]}" | jq -R . | jq -s .)" \
    --argjson collisions "$(printf '%s\n' "${collision_actions[@]-}" | sed '/^$/d' | jq -R . | jq -s .)" \
    '{
      ok: true,
      is_draft: $draft,
      draft_upload_clobber: $draft,
      upload_local_names: $upload_locals,
      checksum_tar_names: $checksum_names,
      checksums_body: $checksums,
      checksums_upload_action: $checksums_action,
      collision_actions: $collisions
    }'
}

release_publish__verify_checksums_in_dir() {
  local asset_dir="$1"
  local checksums_body="$2"
  local n
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    n="${line##* }"
    [[ "$n" == */* ]] && return 1
    [[ -f "$asset_dir/$n" ]] || return 1
  done <<<"$checksums_body"
  printf '%s' "$checksums_body" >"$asset_dir/checksums.txt"
  (
    cd "$asset_dir" || return 1
    sha256sum -c checksums.txt >&2
  )
}

release_publish__plan_assert_ok() {
  local plan="$1"
  local err_msg
  [[ "$(echo "$plan" | jq -r '.ok')" == "true" ]] || {
    err_msg="$(echo "$plan" | jq -r '.error // "plan rejected"')"
    echo "release_publish: $err_msg" >&2
    return 1
  }
}

release_publish__write_checksums_file() {
  local checksums_path="$1"
  local checksums_body="$2"
  printf '%s\n' "${checksums_body%$'\n'}" >"$checksums_path"
}

release_publish__stage_verify_assets() {
  local plan="$1"
  local asset_dir="$2"
  local verify_dir="$3"
  local remote_fixture_dir="${4:-}"
  local published_checksums_file="${5:-}"
  local gh_tag="${6:-}"
  local gh_repo="${7:-}"

  local name
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    if [[ -f "$asset_dir/$name" ]]; then
      cp "$asset_dir/$name" "$verify_dir/$name"
    elif [[ -n "$remote_fixture_dir" && -f "$remote_fixture_dir/$name" ]]; then
      cp "$remote_fixture_dir/$name" "$verify_dir/$name"
    elif [[ -n "$gh_tag" && -n "$gh_repo" ]]; then
      release_publish__invoke_release_download_argv \
        "$gh_tag" "$gh_repo" "$verify_dir" "$name" release_publish__cb_run_argv \
        || return 1
    else
      echo "release_publish: missing staged asset $name" >&2
      return 1
    fi
    if [[ -n "$published_checksums_file" && -f "$published_checksums_file" ]] && \
      [[ "$name" == *.tar.gz ]]; then
      local listed_hash
      listed_hash="$(release_publish__hash_for_basename_in_checksums \
        "$published_checksums_file" "$name" || true)"
      if [[ -n "$listed_hash" ]]; then
        release_publish__verify_listed_remote_hash \
          "$published_checksums_file" "$name" \
          "$(sha256sum "$verify_dir/$name" | awk '{print $1}')" || return 1
      fi
    fi
  done < <(echo "$plan" | jq -r '.checksum_tar_names[]?')
}

release_publish__upload_spec_from_plan() {
  local plan="$1"
  echo "$plan" | jq -c \
    '{upload_local_names: [.upload_local_names[]? | select(length>0)],
      checksums_upload_action: .checksums_upload_action}'
}

release_publish__execute_upload_from_plan() {
  local plan="$1"
  local asset_dir="$2"
  local gh_tag="${3:-}"
  local gh_repo="${4:-}"

  release_publish__plan_assert_ok "$plan" || return 1

  [[ -n "$gh_tag" && -n "$gh_repo" ]] || {
    echo "release_publish: gh tag and repo required for upload" >&2
    return 1
  }

  release_publish__invoke_each_upload_argv_from_plan \
    "$plan" "$asset_dir" "$gh_tag" "$gh_repo" release_publish__cb_run_argv \
    || return 1
}
