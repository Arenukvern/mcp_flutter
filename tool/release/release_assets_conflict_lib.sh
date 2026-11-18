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

release_conflict__invoke_release_view_argv() {
  local tag="$1"
  local repo="$2"
  local callback="$3"
  # shellcheck disable=SC2034
  local -a argv=(gh release view "$tag" --repo "$repo" --json assets)
  "$callback" argv || return 1
}

release_conflict__contract_view_cb() {
  if [[ "${RELEASE_CONFLICT_CONTRACT_NO_GH:-}" != 1 ]]; then
    echo "release_conflict: contract cb without RELEASE_CONFLICT_CONTRACT_NO_GH" >&2
    return 1
  fi
  if [[ "${RELEASE_CONFLICT_CONTRACT_CB_FAIL:-}" == 1 ]]; then
    echo "simulated gh api failure" >&2
    return 1
  fi
  if [[ -z "${RELEASE_CONFLICT_CONTRACT_FIXTURE:-}" ]]; then
    echo "release_conflict: RELEASE_CONFLICT_CONTRACT_FIXTURE required in contract mode" >&2
    return 1
  fi
  printf '%s' "$RELEASE_CONFLICT_CONTRACT_FIXTURE"
  return 0
}

release_conflict__fetch_release_view_json() {
  local tag="$1"
  local repo="$2"
  local json
  if [[ "${RELEASE_CONFLICT_CONTRACT_NO_GH:-}" == 1 ]]; then
    json="$(release_conflict__invoke_release_view_argv \
      "$tag" "$repo" release_conflict__contract_view_cb)" || return 1
  else
    json="$(release_conflict__invoke_release_view_argv \
      "$tag" "$repo" release_conflict__cb_run_argv)" || return 1
  fi
  printf '%s' "$json"
}

release_conflict__expected_asset_names() {
  local version="$1"
  printf '%s\n' \
    "flutter_mcp_${version}_darwin-arm64.tar.gz" \
    "flutter_mcp_${version}_linux-x64.tar.gz" \
    "checksums.txt"
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

  local expected=(
    "flutter_mcp_${version}_darwin-arm64.tar.gz"
    "flutter_mcp_${version}_linux-x64.tar.gz"
    "checksums.txt"
  )

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
  local expected=(
    "flutter_mcp_${version}_darwin-arm64.tar.gz"
    "flutter_mcp_${version}_linux-x64.tar.gz"
    "checksums.txt"
  )
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