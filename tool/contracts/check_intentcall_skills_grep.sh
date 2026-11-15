#!/usr/bin/env bash
# Fail if MCPCallEntry appears outside allowed migration/historical paths.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MIGRATION_SKILL="$ROOT/plugin/skills/flutter-mcp-toolkit-intentcall-migration/SKILL.md"

command -v rg >/dev/null 2>&1 || {
  echo "check_intentcall_skills_grep: rg required" >&2
  exit 1
}

bad=0

rg_list() {
  local hits rg_status
  set +e
  hits="$(rg -l 'MCPCallEntry' "$@" 2>/dev/null)"
  rg_status=$?
  set -e
  if ((rg_status > 1)); then
    echo "check_intentcall_skills_grep: rg failed (exit $rg_status)" >&2
    exit 2
  fi
  printf '%s' "$hits"
}

check_paths() {
  local label="$1"
  shift
  if [[ $# -eq 0 ]]; then
    return 0
  fi
  for root in "$@"; do
    [[ -e "$root" ]] || {
      echo "check_intentcall_skills_grep: missing scan root: $root" >&2
      exit 2
    }
  done
  local hits
  hits="$(rg_list "$@")"
  [[ -z "$hits" ]] && return 0
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if [[ "$file" == "$MIGRATION_SKILL" ]]; then
      continue
    fi
    echo "check_intentcall_skills_grep ($label): unexpected MCPCallEntry in $file" >&2
    bad=1
  done <<< "$hits"
}

if [[ -d "$ROOT/plugin/skills" ]]; then
  hits="$(rg_list "$ROOT/plugin/skills" --glob 'SKILL.md')"
  if [[ -n "$hits" ]]; then
    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      if [[ "$file" == "$MIGRATION_SKILL" ]]; then
        continue
      fi
      echo "check_intentcall_skills_grep (plugin/skills): unexpected MCPCallEntry in $file" >&2
      bad=1
    done <<< "$hits"
  fi
fi

for docs_area in concepts install use-cases; do
  check_paths "docs/$docs_area" "$ROOT/docs/$docs_area"
done
for doc_file in quickstart.mdx troubleshooting.mdx; do
  check_paths "docs" "$ROOT/docs/$doc_file"
done
check_paths "docs/contributing" "$ROOT/docs/contributing"

check_paths "readme" "$ROOT/README.md" "$ROOT/llms.txt"

for f in \
  "$ROOT/plugin/README.md" \
  "$ROOT/plugin/agents/flutter-mcp-toolkit-runtime.md" \
  "$ROOT/plugin/.codex-plugin/plugin.json" \
  "$ROOT/docs/concepts/how-it-works.mdx"; do
  if [[ -f "$f" ]] && rg -q 'MCPCallEntry' "$f"; then
    echo "check_intentcall_skills_grep (plugin): unexpected MCPCallEntry in $f" >&2
    bad=1
  fi
done

if rg -q 'MCPCallEntry' "$ROOT/mcp_server_dart/lib/src/skill_assets.g.dart"; then
  if ! rg -q 'flutter-mcp-toolkit-intentcall-migration' "$ROOT/mcp_server_dart/lib/src/skill_assets.g.dart"; then
    echo "check_intentcall_skills_grep: MCPCallEntry in skill_assets.g.dart without migration skill" >&2
    bad=1
  fi
  count="$(rg -c 'MCPCallEntry' "$ROOT/mcp_server_dart/lib/src/skill_assets.g.dart" || true)"
  if [[ "$count" -gt 20 ]]; then
    echo "check_intentcall_skills_grep: too many MCPCallEntry hits ($count) in skill_assets.g.dart" >&2
    bad=1
  fi
fi

exit "$bad"