#!/usr/bin/env bash
# Writes workspace-root pubspec_overrides.yaml for the pinned oka consumer graph.
# Workspace members (packages/*, showcase/native_layer_capture_fixture) must not
# carry their own pubspec_overrides — pub applies overrides from the repo root only.
#
# Root pubspec_overrides.yaml is a maintainer-local slot (gitignored). This script
# must never clobber a non-GENERATED file; overwrite only with CI=true,
# GITHUB_ACTIONS=true, or OKA_CONSUMER_OVERWRITE_OVERRIDES=1.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
pin="$(tr -d '[:space:]' < "$repo_root/tool/ci/oka_consumer_pin.txt")"
oka="$repo_root/oka"
GENERATED_RE='^# GENERATED: oka consumer'

oka_consumer_overwrite_allowed() {
  [[ "${CI:-}" == "true" ]] \
    || [[ "${GITHUB_ACTIONS:-}" == "true" ]] \
    || [[ "${OKA_CONSUMER_OVERWRITE_OVERRIDES:-}" == "1" ]]
}

is_oka_generated_override() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  head -n 1 "$f" | grep -Eq "$GENERATED_RE"
}

fail_personal_override() {
  local f="$1"
  echo "apply_oka_consumer_overrides: refusing to touch $f" >&2
  echo "  Root pubspec_overrides.yaml is for maintainer-local sibling overrides (gitignored)." >&2
  echo "  Move or rename your file, or use a previous oka GENERATED file only when" >&2
  echo "  CI=true / GITHUB_ACTIONS=true / OKA_CONSUMER_OVERWRITE_OVERRIDES=1 is set." >&2
  exit 1
}

remove_oka_generated_override_if_present() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  if is_oka_generated_override "$f"; then
    rm -f "$f"
    return 0
  fi
  echo "apply_oka_consumer_overrides: leaving $f (not oka GENERATED)" >&2
}

assert_may_write_root_override() {
  local out="$1"
  if [[ -f "$out" ]] && ! is_oka_generated_override "$out"; then
    fail_personal_override "$out"
  fi
  if [[ -f "$out" ]] && is_oka_generated_override "$out"; then
    if ! oka_consumer_overwrite_allowed; then
      echo "apply_oka_consumer_overrides: $out exists (oka GENERATED) but overwrite not allowed" >&2
      echo "  Set CI=true, GITHUB_ACTIONS=true, or OKA_CONSUMER_OVERWRITE_OVERRIDES=1 for CI provision." >&2
      exit 1
    fi
  fi
  if [[ ! -f "$out" ]] && ! oka_consumer_overwrite_allowed; then
    echo "apply_oka_consumer_overrides: refusing to create $out without overwrite opt-in" >&2
    echo "  Set CI=true, GITHUB_ACTIONS=true, or OKA_CONSUMER_OVERWRITE_OVERRIDES=1." >&2
    exit 1
  fi
}

if [[ ! -d "$oka/packages/oka_android" ]]; then
  echo "missing $oka — run tool/ci/checkout_oka_consumer.sh first" >&2
  exit 1
fi

out="$repo_root/pubspec_overrides.yaml"
assert_may_write_root_override "$out"

{
  echo "# GENERATED: oka consumer test pin $pin (unmerged PR — not a release claim)"
  echo "dependency_overrides:"
  echo "  universal_automation_interface: 0.4.0"
  for pkg_dir in "$oka"/packages/*/; do
    [[ -f "$pkg_dir/pubspec.yaml" ]] || continue
    name="$(basename "$pkg_dir")"
    echo "  $name:"
    echo "    path: oka/packages/$name"
  done
} >"$out"

remove_oka_generated_override_if_present "$repo_root/packages/harness/pubspec_overrides.yaml"
remove_oka_generated_override_if_present \
  "$repo_root/showcase/native_layer_capture_fixture/pubspec_overrides.yaml"

echo "pubspec_overrides.yaml applied at workspace root (full oka graph, pin $pin)"
