---
name: repository-governance-lifecycle-faq-reference
description: Creates and maintains DESIGN_FAQ (why) and DX_FAQ (how) documentation in FAQ-driven development style. Use when writing docs, rules, prompts, updating FAQs after code changes, or bootstrapping faq_usage rules and Cursor commands.
license: MIT
type: governance
metadata:
  author: skill-steward
  version: "1.0.0"
  category: documentation
paths:
  - "**/DESIGN_FAQ.md"
  - "**/DESIGN_FAQ.mdx"
  - "**/DX_FAQ.md"
  - "**/DX_FAQ.mdx"
  - "**/.cursor/rules/faq_usage.mdc"
  - "**/.cursor/commands/update-faq.md"
---

# FAQ-driven documentation

Compress knowledge into **Q&A** so humans and agents can find answers without bloated specs. Pattern proven in production monorepos (e.g. ecsly) and described in [FAQ-driven development](https://dev.to/arenukvern/faq-driven-development-or-new-old-way-to-write-docs-rules-prompts-25jl).

## Two files — no duplication

| File | Question type | Audience | Update when |
|------|---------------|----------|-------------|
| **DESIGN_FAQ.md / .mdx** | **Why** — rationale, trade-offs | Maintainers, agents changing architecture | Internals, performance choices, boundaries |
| **DX_FAQ.md / .mdx** | **How** — API usage, patterns | Application developers, agents writing client code | Public API, examples, workflows |

Use **both** when needed; they complement each other. Never copy the same fact into both—link instead.

## DESIGN_FAQ rules

- Format: `**Q: …**` / `**A: …**` (2–3 sentences per answer)
- Include: decision, trade-off, performance or maintenance context
- Exclude: long tutorials, copy-paste-heavy how-tos (those belong in DX_FAQ)
- Sections: group by theme (Storage, Events, Plugins, …)

Example:

```markdown
**Q: Why can't we use Entity.index directly to access components?**
A: Entities migrate between archetypes when components change. Location lookup (ArchetypeId + Row) stays O(1) after migration. Direct index would point at the wrong archetype.
```

See [references/design-faq-format.md](references/design-faq-format.md).

## DX_FAQ rules

- Focus: practical **how** with minimal prose
- **Memory Palace** (recommended for large APIs): spatial “locations” (emoji + name) with embedded code blocks
- One pattern per location; agents “walk” the doc to recall APIs

Example locations: 🏠 World Hub, 🏭 Entity Factory, 🔍 Query Station.

See [references/dx-faq-memory-palace.md](references/dx-faq-memory-palace.md).

## Repository layout

To align with modern documentation rendering platforms (such as [docs.page](https://docs.page)) and standard doc lattices:
1. **Canonical Location:** FAQs should live under the `docs/` subdirectory as `.mdx` files by default (e.g., `docs/DESIGN_FAQ.mdx`, `docs/DX_FAQ.mdx`).
2. **Root Compatibility:** For backwards-compatibility with local editors or legacy integrations, create symbolic links in the repository root pointing to the `.mdx` files:
   ```bash
   ln -s docs/DESIGN_FAQ.mdx DESIGN_FAQ.md
   ln -s docs/DX_FAQ.mdx DX_FAQ.md
   ```

Standard structure:
```
{package-or-repo-root}/
├── docs/
│   ├── DESIGN_FAQ.mdx             # canonical location (MDX)
│   └── DX_FAQ.mdx                 # canonical location (MDX)
├── DESIGN_FAQ.md -> docs/DESIGN_FAQ.mdx (symlink for local compatibility)
├── DX_FAQ.md -> docs/DX_FAQ.mdx   # (symlink for local compatibility)
├── .cursor/rules/faq_usage.mdc    # When to read which FAQ
└── .cursor/commands/
    ├── update-faq.md              # Sync FAQs after a change (why + how goals)
    ├── use-faq-diagram.md         # Cross-check FAQs vs architecture diagram
    └── update-faq-packages.md     # Propagate FAQs to child packages
```

Monorepos: **one pair per package** that owns distinct design; **parent FAQs** only route (“see `plugins/foo/docs/DESIGN_FAQ.mdx`”)—no duplicate answers.

## Cursor integration

### Rule: `faq_usage.mdc`

`alwaysApply: true` router—when to open DESIGN vs DX. Copy from [references/faq-usage-rule-template.md](references/faq-usage-rule-template.md).

### Commands (user-invoked)

| Command | Purpose |
|---------|---------|
| `update-faq` | After code change: update DESIGN and/or DX; stay **short & smart**; verify against codebase |
| `use-faq-diagram` | Align FAQs with architecture diagram / reusable modules |
| `update-faq-packages` | Create or refresh child package FAQs; add brief pointers in parent FAQs |

Command bodies should state: *concise docs, why in DESIGN, how in DX, Memory Palace for DX, no duplication.*

## Workflow: bootstrap new package

1. Add `DESIGN_FAQ.mdx` (or `.md`) — why the package exists + key decisions (5–15 Q&As to start).
2. Add `DX_FAQ.mdx` (or `.md`) — how to use it (Memory Palace if API surface is large).
3. Add `.cursor/rules/faq_usage.mdc`.
4. Add `.cursor/commands/update-faq.md` (copy intent from references).
5. Link from parent `README` or `AGENTS.md` (router table: why → DESIGN, how → DX).

Checklist: [references/bootstrap-checklist.md](references/bootstrap-checklist.md).

## Workflow: update after code change

```
Change type?
├─ Architectural / internal trade-off → DESIGN_FAQ (new or edit Q&A)
├─ Public API / usage pattern → DX_FAQ (location + code block)
├─ New sub-package → child DESIGN_FAQ + DX_FAQ + parent router lines
└─ Both → update both; still no duplicated paragraphs
```

1. Read relevant code paths; do not document wishful APIs.
2. Prefer **edit existing Q&A** over adding redundant entries.
3. Remove or supersede Q&As that no longer apply.
4. Keep answers short; move long examples to `references/` or official docs site.

## FAQ in other surfaces

| Surface | Use |
|---------|-----|
| `.cursor/rules/*.mdc` | Q&A for agent routing (like `faq_usage`) |
| `AGENTS.md` | Table linking DESIGN_FAQ / DX_FAQ paths |
| ADRs | Strategic why; link to DESIGN_FAQ for operational detail |
| Code comments | `// Q: …` / `// A: …` for non-obvious local choices |

## Quality bar

- [ ] Every Q is specific and searchable
- [ ] Every A is actionable or decision-complete in ≤3 sentences (DESIGN)
- [ ] DX blocks are copy-paste valid against current API
- [ ] Parent FAQ does not repeat child answers
- [ ] `faq_usage` rule exists where Cursor is used

## Install

```bash
npx skills add arenukvern/skill_steward --skill repository-governance-lifecycle
```

## Related Guild skill

Repo-wide navigation and SSOT rules live in [repository-governance-lifecycle](../SKILL.md). Use the same skill for lattice, ADRs, and FAQs.

## Further reading

- Article: [FAQ-driven development](https://dev.to/arenukvern/faq-driven-development-or-new-old-way-to-write-docs-rules-prompts-25jl)
- Skill Steward: [ADR 0002](../../docs/decisions/0002-adopt-faq-driven-documentation.mdx)
- Reference implementation: ecsly (`DESIGN_FAQ.md` / `DX_FAQ.md` per package)

## Sources

See [references/sources.md](references/sources.md). When researching, follow `skill-source-citations`.
