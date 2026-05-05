#!/usr/bin/env bash
# Verify the v3.0.0 MCP tool-name prefix is consistent across the
# canonical surface file and all shipped docs.
#
# The canonical surface is tool/contracts/expected_tool_surface.txt. It
# lists every prefixed tool name the kernel publishes (e.g. fmt_tap_widget).
# This script enforces two invariants:
#
#   1. Every entry in the canonical surface uses the same prefix
#      (the prefix is taken from the first line). Mixed prefixes fail.
#
#   2. No shipped doc may reference a bare tool name under the WRONG prefix.
#      Concretely: for each canonical entry "<prefix>_<tool>", we forbid
#      any token "<other_prefix>_<tool>" in the shipped docs listed below,
#      where <other_prefix> is any short lowercase id we have ever used.
#
# Wired into `make check-contracts`.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SURFACE_FILE="$ROOT_DIR/tool/contracts/expected_tool_surface.txt"

fail() { echo "tool-prefix: $*" >&2; exit 1; }
ok()   { echo "tool-prefix: $*"; }

[[ -f "$SURFACE_FILE" ]] || fail "missing $SURFACE_FILE"

# Collect non-comment, non-blank entries (bash 3.2 compatible — no mapfile).
ENTRIES=()
while IFS= read -r line; do
  ENTRIES+=("$line")
done < <(grep -E '^[a-z][a-z0-9_]*$' "$SURFACE_FILE")
[[ "${#ENTRIES[@]}" -gt 0 ]] || fail "no entries found in expected_tool_surface.txt"

# 1. Single-prefix invariant.
PREFIX="${ENTRIES[0]%%_*}"
[[ -n "$PREFIX" ]] || fail "first entry has no underscore: ${ENTRIES[0]}"
for entry in "${ENTRIES[@]}"; do
  case "$entry" in
    "${PREFIX}_"*) : ;;
    *) fail "mixed prefixes in expected_tool_surface.txt: '$entry' is not '${PREFIX}_*'" ;;
  esac
done
ok "expected_tool_surface.txt uses single prefix '${PREFIX}_' (${#ENTRIES[@]} tools)"

# 2. Forbidden-prefix invariant in shipped docs.
#
# Historic prefixes that must NOT appear in front of canonical tool bare-names
# in any shipped doc. Add new entries here if the prefix changes again.
HISTORIC_PREFIXES=("core")

# Bare tool names = entries with the canonical prefix stripped.
BARE_NAMES=()
for entry in "${ENTRIES[@]}"; do
  BARE_NAMES+=("${entry#${PREFIX}_}")
done

# Shipped docs whose readers depend on getting the right prefix.
SHIPPED_DOCS=(
  "$ROOT_DIR/CHANGELOG.md"
  "$ROOT_DIR/README.md"
  "$ROOT_DIR/ARCHITECTURE.md"
  "$ROOT_DIR/docs/start_here/migration_v2_to_v3.mdx"
  "$ROOT_DIR/docs/decisions/0001_capability_kernel_and_tool_prefix.mdx"
  "$ROOT_DIR/docs/decisions/0002_v3_scope_and_consolidation_deferrals.mdx"
)

# Use ripgrep when available, fall back to grep -E.
search_token() {
  local token="$1"
  shift
  if command -v rg >/dev/null 2>&1; then
    rg --no-heading --line-number -F -- "$token" "$@" 2>/dev/null || true
  else
    grep -nF -- "$token" "$@" 2>/dev/null || true
  fi
}

errors=0
for doc in "${SHIPPED_DOCS[@]}"; do
  [[ -f "$doc" ]] || fail "missing required doc: ${doc#$ROOT_DIR/}"
done

for old in "${HISTORIC_PREFIXES[@]}"; do
  [[ "$old" == "$PREFIX" ]] && continue
  for bare in "${BARE_NAMES[@]}"; do
    token="${old}_${bare}"
    matches="$(search_token "$token" "${SHIPPED_DOCS[@]}")"
    if [[ -n "$matches" ]]; then
      echo "tool-prefix: forbidden token '$token' found in shipped docs:" >&2
      printf '%s\n' "$matches" >&2
      errors=$((errors + 1))
    fi
  done
done

[[ "$errors" -eq 0 ]] || fail "$errors forbidden-prefix occurrence(s) in shipped docs"

# 3. Migration table coverage: CHANGELOG migration table must list every
# canonical tool. (One row per tool; presence of the prefixed name is enough.)
missing=()
for entry in "${ENTRIES[@]}"; do
  if ! grep -Fq -- "$entry" "$ROOT_DIR/CHANGELOG.md"; then
    missing+=("$entry")
  fi
done
if [[ "${#missing[@]}" -gt 0 ]]; then
  echo "tool-prefix: CHANGELOG.md missing canonical tool names:" >&2
  printf '  %s\n' "${missing[@]}" >&2
  exit 1
fi
ok "CHANGELOG.md lists all ${#ENTRIES[@]} canonical tools"

ok "all checks passed"
