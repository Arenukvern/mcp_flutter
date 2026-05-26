#!/usr/bin/env bash
# Fail if MCPCallEntry appears outside the migration skill (before-examples only).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MIGRATION_SKILL="$ROOT/plugin/skills/flutter-mcp-toolkit-agentkit-migration/SKILL.md"

hits="$(rg -l 'MCPCallEntry' "$ROOT/plugin/skills" --glob 'SKILL.md' 2>/dev/null || true)"
if [[ -z "$hits" ]]; then
  exit 0
fi

bad=0
while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  if [[ "$file" != "$MIGRATION_SKILL" ]]; then
    echo "check_agentkit_skills_grep: unexpected MCPCallEntry in $file" >&2
    bad=1
  fi
done <<< "$hits"

if rg -q 'MCPCallEntry' "$ROOT/mcp_server_dart/lib/src/skill_assets.g.dart" 2>/dev/null; then
  # Allow only if solely from migration skill bundle — grep file for other skill ids is heavy;
  # migration skill is the only allowed source in generated assets.
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
