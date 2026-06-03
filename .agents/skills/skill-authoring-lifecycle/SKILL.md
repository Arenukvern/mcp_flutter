---
name: skill-authoring-lifecycle
description: Scaffold and formally review a new Agent Skill in this marketplace repo. Covers valid SKILL.md generation, directory layout, registry entries, and spec auditing. Use when adding a skill, validating frontmatter, or checking marketplace readiness before a PR.
license: MIT
type: governance
metadata:
  author: skill-steward
  version: "1.1.0"
  category: marketplace
paths:
  - "skills/**/SKILL.md"
  - "**/SKILL.md"
---

# Skill authoring lifecycle

Add, review, and validate an installable skill package under `skills/` in the Skill Steward marketplace.

## When to use

- User wants a new skill in this repo
- "Review this skill" or "Is this SKILL.md valid?"
- Bootstrapping `SKILL.md` for `npx skills` compatibility
- PR touches `skills/*/SKILL.md`

## Phase 1: Creation Workflow

1. **Verify intent** — Does the intent overlap with an existing skill? Merge into an existing skill if they serve the same high-level goal or are two halves of the same lifecycle ([ADR 0016](../../docs/decisions/0016-skill-cohesion-and-lifecycle-boundaries.mdx)).
2. **Choose a name** — `kebab-case`, 1–64 chars, matches Agent Skills rules (see `docs/STANDARDS.mdx`).
3. **Create directory** — `skills/{name}/` (directory name must equal `name` in frontmatter).
4. **Copy template** — from `templates/skill/SKILL.md`; replace placeholders.
5. **Write description** — one block covering *what* and *when* (trigger phrases users say).
6. **Cite sources** — create `references/sources.md` from `templates/skill/references/sources.md`; add rows for every spec/repo/paper used.
7. **Write body** — numbered steps, examples, output format; keep under 500 lines.
8. **Evals** — Tier 1 skills (see [STANDARDS](../../docs/STANDARDS.mdx)): `references/evals.md` + ≥2 `evals/cases/*.yaml`. Others: optional `evals.md`.
9. **Optional** — `scripts/`, `assets/`.
10. **Register skill**:
   - Add skill id to `skills.sh.json` under the right grouping.
   - Add row to root `README.md` skill table.

## Frontmatter template

```yaml
---
name: {same-as-directory}
description: {capability + trigger phrases, 20-1024 chars}
license: MIT
type: governance
metadata:
  author: skill-steward
  version: "1.0.0"
  category: {marketplace|multi-agent|...}
---
```

## Phase 2: Review & Audit Checklist

Review a skill package before merge or publish to skills.sh.

### Skill Cohesion
- [ ] **Complete lifecycle**: The skill covers a complete journey (e.g., creating + validating) rather than forcing an agent to switch tools mid-task.
- [ ] **Mechanics included**: Abstract rules or culture guidelines are bundled alongside the mechanical tools that enforce them.

### Structure
- [ ] Directory name is `kebab-case` and matches `name` in frontmatter
- [ ] File is exactly `SKILL.md` (case-sensitive)
- [ ] No `README.md` inside the skill folder (use `references/`)

### Frontmatter
- [ ] `name`: 1–64 chars, `[a-z0-9-]`, no leading/trailing `-`, no `--`
- [ ] `description`: 1–1024 chars, states capability **and** when to activate
- [ ] `license` set if not repo MIT
- [ ] `metadata.version` and `metadata.author`
- [ ] `compatibility` if skill needs git, network, docker, or a specific product

### Body
- [ ] Clear numbered workflow
- [ ] Under ~500 lines (or split to `references/`)
- [ ] Relative file links one level deep
- [ ] `references/sources.md` with URLs for external claims
- [ ] Install command documented: `npx skills add arenukvern/skill_steward --skill <name>`

### Scripts (if present)
- [ ] Shebang present (`bash` or `node`)
- [ ] `set -euo pipefail` for bash
- [ ] stderr for logs, stdout for machine-readable output

### Registry (this repo)
- [ ] Skill id in `skills.sh.json`
- [ ] Row in root `README.md` table
- [ ] `pnpm run validate` passes (no `sources.md` warning)
- [ ] **Tier 1**: `evals/cases/*.yaml` + `pnpm run eval`

## Phase 3: Deprecation & Renaming (Changesets)

We do not keep permanent "tombstone" skills, as they clutter the repository. Instead, we treat skill renames and merges as breaking API changes and communicate them using standard ecosystem tooling (Changesets).

When renaming or merging a skill:
1. Safely `rm -rf` the old skill directory.
2. Remove the old skill from `skills.sh.json` and `README.md`.
3. Generate a changeset (`pnpm changeset`) documenting the deletion, or manually create a `.changeset/skill-consolidation.md` file. Explain clearly *why* it was removed and *which* skill replaces it.
4. Agents and users reading the changelog will automatically see the redirection.

## Output format for Reviews

Report as:
```
## Summary
{pass | needs changes}

## Errors (blocking)
...
## Warnings
...
```

## Install

```bash
npx skills add arenukvern/skill_steward --skill skill-authoring-lifecycle
```

## Sources

See [references/sources.md](references/sources.md). When researching, follow `skill-source-citations`.
