# shellcheck shell=bash
# gh argv builders + conflict classification for check_release_assets_conflict.sh

release_conflict__argv_to_line() {
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

release_conflict__cb_print_argv() {
  # shellcheck disable=SC2034
  local -n _cmd=$1
  release_conflict__argv_to_line "${_cmd[@]}"
}

release_conflict__cb_run_argv() {
  # shellcheck disable=SC2034
  local -n _cmd=$1
  "${_cmd[@]}"
}

release_conflict__require_gh() {
  command -v gh >/dev/null 2>&1
}

release_conflict__invoke_release_view_argv() {
  local tag="$1"
  local repo="$2"
  local callback="$3"
  # shellcheck disable=SC2034
  local -a argv=(gh release view "$tag" --repo "$repo" --json assets)
  "$callback" argv || return 1
}

release_conflict__fetch_release_view_json() {
  local tag="$1"
  local repo="$2"
  release_conflict__invoke_release_view_argv \
    "$tag" "$repo" release_conflict__cb_run_argv
}

release_conflict__expected_asset_names() {
  local version="$1"
  printf '%s\n' \
    "flutter_mcp_${version}_darwin-arm64.tar.gz" \
    "flutter_mcp_${version}_linux-x64.tar.gz" \
    "flutter-mcp-toolkit.mcpb" \
    "checksums.txt"
}

release_conflict__load_expected_asset_names() {
  local version="$1"
  local -n _names_ref=$2
  _names_ref=()
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] && _names_ref+=("$line")
  done < <(release_conflict__expected_asset_names "$version")
}

# stdout: conflict class — none | partial | full
# return 1 on invalid JSON
release_conflict__conflict_class_from_json() {
  local json="$1"
  local version="$2"
  if ! echo "$json" | jq -e '.assets | type == "array"' >/dev/null 2>&1; then
    return 1
  fi

  local -a existing=()
  local name
  while IFS= read -r name; do
    [[ -n "$name" ]] && existing+=("$name")
  done < <(echo "$json" | jq -r '.assets[].name')

  if [[ ${#existing[@]} -eq 0 ]]; then
    echo none
    return 0
  fi

  local -a expected=()
  release_conflict__load_expected_asset_names "$version" expected

  local -a conflicts=()
  local asset
  for name in "${expected[@]}"; do
    for asset in "${existing[@]}"; do
      if [[ "$asset" == "$name" ]]; then
        conflicts+=("$name")
      fi
    done
  done

  if [[ ${#conflicts[@]} -eq 0 ]]; then
    echo none
    return 0
  fi
  if [[ ${#conflicts[@]} -lt ${#expected[@]} ]]; then
    echo partial
    return 0
  fi
  echo full
  return 0
}

release_conflict__conflict_names_from_json() {
  local json="$1"
  local version="$2"
  local -a expected=()
  release_conflict__load_expected_asset_names "$version" expected
  local -a existing=()
  local -a conflicts=()
  local name asset n
  while IFS= read -r name; do
    [[ -n "$name" ]] && existing+=("$name")
  done < <(echo "$json" | jq -r '.assets[].name')
  for n in "${expected[@]}"; do
    for asset in "${existing[@]}"; do
      if [[ "$asset" == "$n" ]]; then
        conflicts+=("$n")
      fi
    done
  done
  local c
  for c in "${conflicts[@]}"; do
    printf '%s\n' "$c"
  done
}
