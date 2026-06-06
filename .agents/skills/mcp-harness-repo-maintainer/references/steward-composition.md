# Composing Skill Steward skills for harness work

## Typical sequence

1. **north-star-governance** — charter, AGENTS map, plan hygiene (extract & remove)
2. **mcp-harness-repo-maintainer** — frame CLI/MCP/docs approach
3. **release-changelog-harness** — when versioning/publish legibility matters (Changesets, etc.)
4. **adr-records** — decision checkpoint on forks, then ADR for harness boundary (e.g. CLI-only gate vs MCP exposure)
5. **north-star-governance** — router, NORTH_STAR, doc lattice in product repo
6. **faq-driven-docs** — DESIGN_FAQ (why doctor exists) + DX_FAQ (how to run CLI)
7. **skill-authoring-lifecycle** — skill for agents using your harness (customized toolkits, etc.)
8. **skill-authoring-lifecycle** — before publishing skill to skills.sh
9. **multi-agent-handoff** — implementer/closer for large harness programs

## Repo type

| Repo | Skill Steward focus |
|------|-------------|
| **skill_steward** | Meta-skills only; this skill + doc skills |
| **Product** (your app / server) | Apply harness skill *from install*; local ADRs + CLI/MCP |
| **Platform SDK / Lib** | Schema/core library; consumers integrate |

## Install bundle (consumer)

```bash
npx skills add arenukvern/skill_steward -a cursor -a claude-code -y
# Prioritize for harness builds:
#   north-star-governance, mcp-harness-repo-maintainer, faq-driven-docs, adr-records
```

When building or refreshing a harness CLI, also consult the tooling choices documented in [preferred-tooling.md](preferred-tooling.md) (Dart + Justfile defaults, rationale for avoiding unnecessary new mjs/TS harnesses, and guidance reusable across sibling repos).

Hooks/plugins: install separately per [ADR 0004](../../../docs/decisions/0004-plugin-packaging-and-install-path.mdx).
