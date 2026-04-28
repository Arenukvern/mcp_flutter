#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ERROR_CODES_FILE="$ROOT_DIR/mcp_server_dart/lib/src/shared_core/types/error_codes.dart"
PLAYBOOK_FILE="$ROOT_DIR/docs/core/error_code_playbook.mdx"

if [[ ! -f "$PLAYBOOK_FILE" ]]; then
  echo "Missing playbook file: $PLAYBOOK_FILE" >&2
  exit 1
fi

error_codes=()
while IFS= read -r code; do
  error_codes+=("$code")
done < <(
  awk '
    /abstract final class CoreErrorCode/ {in_block=1; next}
    in_block && /^}/ {in_block=0}
    in_block && /static const/ {
      n = split($0, parts, "'\''")
      if (n >= 2 && parts[2] ~ /^[a-z0-9_]+$/) {
        print parts[2]
      }
    }
  ' "$ERROR_CODES_FILE" | sort -u
)

if [[ ${#error_codes[@]} -eq 0 ]]; then
  echo "Failed to extract error codes from $ERROR_CODES_FILE" >&2
  exit 1
fi

missing=()
for code in "${error_codes[@]}"; do
  if ! grep -Fq -- "\`$code\`" "$PLAYBOOK_FILE"; then
    missing+=("$code")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Error code playbook is missing entries:" >&2
  printf '  - %s\n' "${missing[@]}" >&2
  exit 1
fi

echo "Error code playbook coverage check passed."
