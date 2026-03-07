#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

run_cli_help() {
  local -a args=("$@")
  (
    cd "$ROOT_DIR/mcp_server_dart"
    HOME=/tmp DART_SUPPRESS_ANALYTICS=true dart run bin/flutter_mcp_cli.dart "${args[@]}"
  )
}

require_output_contains() {
  local output="$1"
  local needle="$2"
  local label="$3"
  if ! grep -Fq -- "$needle" <<<"$output"; then
    echo "Missing '$needle' in $label" >&2
    exit 1
  fi
}

contains_token_in_files() {
  local token="$1"
  shift

  if command -v rg >/dev/null 2>&1; then
    rg -F --quiet -- "$token" "$@"
  else
    grep -Fq -- "$token" "$@"
  fi
}

global_help="$(run_cli_help --help)"
snapshot_create_help="$(run_cli_help snapshot create --help)"
bundle_create_help="$(run_cli_help bundle create --help)"
doctor_help="$(run_cli_help doctor --help)"

require_output_contains "$global_help" "doctor" "global help"
require_output_contains "$global_help" "snapshot create" "global help"
require_output_contains "$snapshot_create_help" "--check" "snapshot create help"
require_output_contains "$snapshot_create_help" "--diff" "snapshot create help"
require_output_contains "$snapshot_create_help" "--backup" "snapshot create help"
require_output_contains "$snapshot_create_help" "--no-overwrite" "snapshot create help"
require_output_contains "$bundle_create_help" "--check" "bundle create help"
require_output_contains "$bundle_create_help" "--no-overwrite" "bundle create help"
require_output_contains "$doctor_help" "--timeout-ms" "doctor help"

require_docs_contains() {
  local token="$1"
  local -a files=(
    "$ROOT_DIR/README.md"
    "$ROOT_DIR/mcp_server_dart/README.md"
    "$ROOT_DIR/docs/start_here/cli_quick_recipes.mdx"
    "$ROOT_DIR/docs/core/mcp_configuration.mdx"
  )

  if ! contains_token_in_files "$token" "${files[@]}"; then
    echo "Documentation drift: '$token' not found in required docs" >&2
    exit 1
  fi
}

require_docs_contains "doctor"
require_docs_contains "--check"
require_docs_contains "--diff"
require_docs_contains "--backup"
require_docs_contains "--no-overwrite"
require_docs_contains "connection_selection_required"

echo "Docs/help drift check passed."
