#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

has_contract_surface() {
  local candidate="$1"
  "$candidate" doctor --json >/dev/null 2>&1
}

run_source_steward() {
  local package_dir="${SKILL_STEWARD_ROOT}/packages/steward_cli"
  if [[ ! -f "${package_dir}/pubspec.yaml" ]]; then
    echo "Error: SKILL_STEWARD_ROOT must point to a Skill Steward checkout." >&2
    echo "Expected: ${package_dir}/pubspec.yaml" >&2
    exit 1
  fi

  (
    cd "$package_dir"
    dart pub get >/dev/null 2>&1
  )
  dart --packages="${package_dir}/.dart_tool/package_config.json" \
    "${package_dir}/bin/steward.dart" "$@"
}

has_source_surface() {
  run_source_steward doctor --json >/dev/null 2>&1
}

run_path_steward() {
  if command -v steward >/dev/null 2>&1 && has_contract_surface steward; then
    steward "$@"
    return
  fi

  if [[ -n "${SKILL_STEWARD_ROOT:-}" ]]; then
    if has_source_surface; then
      run_source_steward "$@"
      return
    fi
  fi

  cat >&2 <<'MSG'
Error: compatible Skill Steward CLI not found.

Install Skill Steward CLI:
  curl -fsSL https://raw.githubusercontent.com/Arenukvern/skill_steward/main/install.sh | bash

Or run against a local Skill Steward checkout:
  SKILL_STEWARD_ROOT=<skill-steward-checkout> tool/steward/run.sh <command>

The selected `steward` command must support doctor/actions/probe/benchmark.
MSG
  exit 1
}

cd "$ROOT"
run_path_steward "$@"
