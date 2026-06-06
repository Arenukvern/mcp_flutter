---
name: skill-source-citations
description: Requires durable citations when authoring or researching Agent Skills—maintain references/sources.md per skill, link external research, and record provenance in PRs. Use when creating skills, updating SKILL.md, doing web research for skills, or auditing missing sources.
license: MIT
type: governance
metadata:
  author: skill-steward
  version: "1.0.0"
  category: marketplace
---

# Skill source citations

**Rule:** Knowledge borrowed from docs, papers, other repos, or chat research must be **saved as links** in the skill tree—not only in conversation.

## When to use

- Creating or editing any `skills/{name}/SKILL.md`
- Researching harness/MCP/marketplace patterns before writing a skill
- Reviewing a PR that adds procedural claims without sources

## Per-skill file (required in skill_steward)

Maintain **`skills/{name}/references/sources.md`**:

```markdown
# Sources

| Topic | URL | Used for |
|-------|-----|----------|
| Agent Skills spec | https://agentskills.io/ | Frontmatter rules |
| … | … | … |

## Changelog

- 2026-05-29: initial citations
```

Template: [citation-template.md](references/citation-template.md).

## Workflow (create or update skill)

1. **Before writing** — list URLs you will rely on in `references/sources.md` (can start sparse).
2. **In SKILL.md** — link to spec/docs inline where non-obvious; prefer `references/` for long material.
3. **After research** — append new rows + changelog entry; never leave “we read X” only in chat.
4. **In PR** — one line in description: “Sources updated in `references/sources.md`.”
5. **Validate** — `pnpm run validate` warns if `sources.md` is missing.

## What to cite

| Cite | Example |
|------|---------|
| Official specs | agentskills.io, Cursor/Claude/Codex docs |
| Papers / research | SkillOpt, SkillsBench arXiv |
| Reference implementations | product MCPs, Codex plugin-eval |
| Blog/guides | Only if procedure is non-obvious; prefer primary docs |

Do **not** cite ephemeral chat URLs or private tokens.

## Cross-skill index

Guild-wide references: [docs/STANDARDS.mdx](../../docs/STANDARDS.mdx), [DESIGN_FAQ.mdx](../../docs/DESIGN_FAQ.mdx).

## Related skills

| Task | Skill |
|------|-------|
| Scaffold skill | `skill-authoring-lifecycle` |
| Evaluate / improve | `skill-eval-improve` |
| Spec audit | `skill-authoring-lifecycle` |

## Sources discipline (this skill)

See [references/sources.md](references/sources.md).

## Install

```bash
npx skills add arenukvern/skill_steward --skill skill-source-citations
```
