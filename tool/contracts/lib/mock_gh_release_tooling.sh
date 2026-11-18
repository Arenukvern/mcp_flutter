#!/usr/bin/env bash
# Mock gh for release publish/recovery contract tests (sourced or copied to $PATH/gh).
set -euo pipefail

STATE="${GH_MOCK_STATE:?}"
REPO="${GITHUB_REPOSITORY:?}"

release_assets_dir() {
  local tag="$1"
  echo "$STATE/assets/$tag"
}

release_is_draft() {
  local tag="$1"
  [[ -f "$STATE/draft_$tag" ]]
}

release_view() {
  local tag="$1"
  local asset_dir
  asset_dir="$(release_assets_dir "$tag")"
  local names=()
  if [[ -f "$asset_dir/names.txt" ]]; then
    mapfile -t names <"$asset_dir/names.txt"
  fi
  local assets_json
  assets_json="$(printf '%s\n' "${names[@]}" | jq -R . | jq -s 'map(select(length>0) | {name: .})')"
  if release_is_draft "$tag"; then
    jq -n --argjson assets "$assets_json" '{isDraft: true, assets: $assets}'
  else
    jq -n --argjson assets "$assets_json" '{isDraft: false, assets: $assets}'
  fi
}

release_upload() {
  local tag="$1"
  shift
  local clobber=0
  local files=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) shift 2 ;;
      --clobber) clobber=1; shift ;;
      --*) shift ;;
      *)
        if [[ -f "$1" ]]; then
          files+=("$1")
        fi
        shift
        ;;
    esac
  done
  local asset_dir
  asset_dir="$(release_assets_dir "$tag")"
  mkdir -p "$asset_dir"
  touch "$asset_dir/names.txt"
  if [[ "$clobber" -eq 1 ]]; then
  : >"$asset_dir/names.txt"
  fi
  for f in "${files[@]}"; do
    local base
    base="$(basename "$f")"
    cp "$f" "$asset_dir/$base"
    if ! grep -qxF "$base" "$asset_dir/names.txt"; then
      echo "$base" >>"$asset_dir/names.txt"
    fi
  done
}

release_download() {
  local tag="$1"
  shift
  local dest=""
  local patterns=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) shift 2 ;;
      --dir) dest="$2"; shift 2 ;;
      --pattern) patterns+=("$2"); shift 2 ;;
      --*) shift ;;
      *) shift ;;
    esac
  done
  [[ -n "$dest" ]] || { echo "mock gh: download needs --dir" >&2; return 1; }
  mkdir -p "$dest"
  local asset_dir
  asset_dir="$(release_assets_dir "$tag")"
  for pat in "${patterns[@]}"; do
    shopt -s nullglob
    for f in "$asset_dir"/*; do
      [[ -f "$f" ]] || continue
      local base
      base="$(basename "$f")"
      case "$pat" in
        '*.tar.gz')
          [[ "$base" == *.tar.gz ]] || continue
          ;;
        *)
          [[ "$base" == "$pat" ]] || continue
          ;;
      esac
      cp "$f" "$dest/$base"
    done
  done
}

parse_release_subcommand() {
  local sub="$1"
  shift
  local tag=""
  local -a rest=()
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == --repo ]]; then
      shift 2
    elif [[ "$1" == --* ]]; then
      rest+=("$1")
      shift
      if [[ "$1" != --* && -n "${1:-}" ]]; then
        rest+=("$1")
        shift
      fi
    elif [[ -z "$tag" ]]; then
      tag="$1"
      shift
    else
      rest+=("$1")
      shift
    fi
  done
  printf '%s\n' "$tag"
  printf '%s\0' "${rest[@]}"
}

case "${1:-}" in
  release)
    sub="${2:-}"
    shift 2
    case "$sub" in
      view)
        tag=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --repo) shift 2 ;;
            --json)
              shift
              [[ $# -gt 0 && "$1" != --* ]] && shift
              ;;
            *)
              tag="$1"
              shift
              ;;
          esac
        done
        [[ -n "$tag" ]] || { echo "mock gh: release view needs tag" >&2; exit 1; }
        release_view "$tag"
        ;;
      upload)
        args=()
        tag=""
        while [[ $# -gt 0 ]]; do
          if [[ "$1" == --repo ]]; then
            shift 2
          elif [[ -z "$tag" && "$1" != --* ]]; then
            tag="$1"
            shift
          else
            args+=("$1")
            shift
          fi
        done
        release_upload "$tag" "${args[@]}"
        ;;
      download)
        tag=""
        rest=()
        while [[ $# -gt 0 ]]; do
          if [[ "$1" == --repo ]]; then
            shift 2
          elif [[ -z "$tag" && "$1" != --* ]]; then
            tag="$1"
            shift
          else
            rest+=("$1")
            shift
          fi
        done
        release_download "$tag" "${rest[@]}"
        ;;
      *)
        echo "mock gh: unknown release $sub" >&2
        exit 1
        ;;
    esac
    ;;
  api)
    path="${2:-}"
    mock_emit_json() {
      local fallback="${1:-{}}"
      if [[ -n "${2:-}" ]]; then
        printf '%s\n' "$2"
      else
        printf '%s\n' "$fallback"
      fi
    }
    if [[ "$path" == *"/annotations"* ]]; then
      mock_emit_json '[]' "${GH_MOCK_ANNOTATIONS_JSON:-}"
      exit 0
    fi
    if [[ "$path" == */actions/runs/*"/jobs"* ]]; then
      mock_emit_json '{"jobs":[]}' "${GH_MOCK_JOBS_JSON:-}"
      exit 0
    fi
    if [[ "$path" =~ ^repos/[^/]+/[^/]+/actions/runs/[0-9]+$ ]]; then
      mock_emit_json '{}' "${GH_MOCK_RUN_JSON:-}"
      exit 0
    fi
    if [[ "$path" == */actions/workflows ]] || [[ "$path" == */actions/workflows/* ]]; then
      if [[ "$path" == */runs* ]]; then
        mock_emit_json '{"workflow_runs":[]}' "${GH_MOCK_WORKFLOW_RUNS_JSON:-}"
      else
        echo '{"workflows":[{"id":99,"path":".github/workflows/release.yml"}]}'
      fi
      exit 0
    fi
    echo "mock gh api unhandled: $path" >&2
    exit 1
    ;;
  run)
    if [[ "${2:-}" == "rerun" ]]; then
      echo "mock gh run rerun ok" >>"$STATE/rerun.log"
      exit 0
    fi
    ;;
  *)
    echo "mock gh: unknown $1" >&2
    exit 1
    ;;
esac
