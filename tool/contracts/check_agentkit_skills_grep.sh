#!/usr/bin/env bash
# Fail if MCPCallEntry appears outside allowed migration/historical paths.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MIGRATION_SKILL="$ROOT/plugin/skills/flutter-mcp-toolkit-agentkit-migration/SKILL.md"

bad=0

check_paths() {
  local label="$1"
  shift
  local hits
  hits="$(rg -l 'MCPCallEntry' "$@" 2>/dev/null || true)"
  [[ -z "$hits" ]] && return 0
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if [[ "$file" == "$MIGRATION_SKILL" ]]; then
      continue
    fi
    echo "check_agentkit_skills_grep ($label): unexpected MCPCallEntry in $file" >&2
    bad=1
  done <<< "$hits"
}

# Plugin skills (migration skill only)
check_paths "plugin/skills" "$ROOT/plugin/skills" --glob 'SKILL.md'

# User-facing docs (exclude superpowers specs/plans/closure)
check_paths "docs/core" "$ROOT/docs/core"
check_paths "docs/ai_agents" "$ROOT/docs/ai_agents"
check_paths "docs/guides" "$ROOT/docs/guides"
check_paths "docs/contributing" "$ROOT/docs/contributing"

# Plugin surfaces
for f in \
  "$ROOT/plugin/README.md" \
  "$ROOT/plugin/agents/flutter-mcp-toolkit-runtime.md" \
  "$ROOT/plugin/.codex-plugin/plugin.json" \
  "$ROOT/ARCHITECTURE.md"; do
  if [[ -f "$f" ]] && rg -q 'MCPCallEntry' "$f" 2>/dev/null; then
    echo "check_agentkit_skills_grep (plugin): unexpected MCPCallEntry in $f" >&2
    bad=1
  fi
done

# Generated skill bundle — migration skill only
if rg -q 'MCPCallEntry' "$ROOT/mcp_server_dart/lib/src/skill_assets.g.dart" 2>/dev/null; then
  if ! rg 'flutter-mcp-toolkit-agentkit-migration' "$ROOT/mcp_server_dart/lib/src/skill_assets.g.dart" >/dev/null; then
    echo "check_agentkit_skills_grep: MCPCallEntry in skill_assets.g.dart without migration skill" >&2
    bad=1
  fi
  count="$(rg -c 'MCPCallEntry' "$ROOT/mcp_server_dart/lib/src/skill_assets.g.dart" || echo 0)"
  if [[ "$count" -gt 20 ]]; then
    echo "check_agentkit_skills_grep: too many MCPCallEntry hits ($count) in skill_assets.g.dart" >&2
    bad=1
  fi
fi

exit "$bad"
