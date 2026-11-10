#!/usr/bin/env bash
# Fail when release tooling scripts use bash 4+ features (macOS CI runs bash 3.2).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() { echo "macos-release-shell: $*" >&2; exit 1; }
ok() { echo "macos-release-shell: $*"; }

# Scripts invoked from release.yml build (macOS + Linux) and publish guard paths.
SCRIPTS=(
  tool/release/verify_release_tarball_architecture.sh
  tool/release/build_release_artifacts.sh
  tool/release/verify_release_source_checkout.sh
  tool/release/assert_release_tag.sh
  tool/release/check_release_assets_conflict.sh
  tool/release/resolve_release_tag.sh
)

# Patterns that bash 3.2 does not support (or macOS /bin/bash rejects).
FORBIDDEN_REGEX='\b(mapfile|readarray)\b|declare -A|\$\{[a-zA-Z_][a-zA-Z0-9_]*(,,|\^\^?|,)\}'

scan_file() {
  local rel="$1"
  local path="$ROOT_DIR/$rel"
  grep -nE "$FORBIDDEN_REGEX" "$path" | grep -vE '^[0-9]+:(#|[[:space:]]+#)' || true
}

errors=0
for rel in "${SCRIPTS[@]}"; do
  [[ -f "$ROOT_DIR/$rel" ]] || fail "missing script: $rel"
  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    echo "macos-release-shell: forbidden bash 4 construct in $rel: $hit" >&2
    errors=$((errors + 1))
  done < <(scan_file "$rel")
done

# Self-test: regex must catch each Bash 4 parameter expansion form.
for sample in '${name,}' '${name,,}' '${name^}' '${name^^}'; do
  if ! printf '%s\n' "$sample" | grep -nE "$FORBIDDEN_REGEX" | grep -q .; then
    echo "macos-release-shell: FORBIDDEN_REGEX missed $sample" >&2
    errors=$((errors + 1))
  fi
done

[[ "$errors" -eq 0 ]] || fail "$errors forbidden construct(s) in release shell scripts"

ok "release shell scripts are bash 3.2 compatible (${#SCRIPTS[@]} files)"
