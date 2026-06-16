---
name: repository-governance-lifecycle-adr-reference
description: Writes and maintains ADRs (MADR, Nygard, Y-Statement) and runs decision checkpoints before/during work—trigger matrix, option briefs, proposed ADRs. Use when creating or updating ADRs, facing a design fork, trade-off, boundary change, or when the user asks for key design decisions before implementing.
license: MIT
type: governance
metadata:
  author: skill-steward
  version: "1.1.0"
  category: documentation
paths:
  - "docs/**"
  - "doc/**"
  - "**/adr/**"
  - "**/decisions/**"
  - "**/architecture/**"
---

# Architecture Decision Records (adr.github.io)

Maintain a **decision log** of architecturally significant choices using formats from [adr.github.io](https://adr.github.io/).

## When to use

- User asks for an ADR, architecture decision record, or decision log
- **Before or during implementation** — design fork, trade-off, or “which approach?” ([decision checkpoints](#decision-checkpoints-layer-0))
- User asks for **key design decisions** when doing work (checkpoint brief, not silent defaults)
- Recording a significant design choice (stack, integration, security, data model, deployment)
- Updating ADR status (`accepted`, `deprecated`, `superseded`)
- Aligning an existing repo with MADR / Nygard conventions

## Decision checkpoints (layer 0)

**Layer 0 = checkpoint** (brief or `proposed` ADR). **Layer 1 = accepted ADR** after agreement.

When triggers fire, **stop and ask**—do not implement the most convenient option.

| Trigger | Stop when… |
|---------|------------|
| **T1 Fork** | 2+ viable architectures or tools |
| **T2 Boundary** | Scope crosses North Star / repo archetype |
| **T3 Irreversible** | Public API, schema, auth, hard-to-revert migration |
| **T4 Dependency** | New sibling repo, CI, or registry coupling |
| **T5 Contradiction** | Conflicts with accepted ADR or charter |
| **T6 Security** | Auth, PII, secrets, production exposure |
| **T7 Cost** | Expensive to revert after merge |
| **T8 Uncertainty** | Would need unstated assumptions |

**Output:** a short decision brief in chat/PR, or an ADR with `status: proposed`. A useful brief names the trigger, options, recommendation, known risk, validation route, and what would make the decision reversible.

Combine the ADR checkpoint with this skill's North Star rules and `repo-quality-system-lifecycle` before large edits; add `mcp-harness-repo-maintainer` only for action-contract or harness changes.

## Locate or bootstrap the decision log

Search (in order) for an existing log:

| Path | Notes |
|------|--------|
| `docs/decisions/` | MADR default |
| `doc/adr/` | Common alternative |
| `docs/adr/` | Common alternative |
| `architecture/decisions/` | Monorepos |

If none exists, **ask the user** unless they said to create one. Default new log:

```
docs/decisions/
├── README.md          # Index with table of all ADRs
└── NNNN-title-with-dashes.md
```

Add a one-line pointer in the root `README.md` or `CONTRIBUTING.md` if the project documents contributions.

## Numbering and filenames

- **Format**: `NNNN-kebab-case-title.md` (4-digit zero-padded: `0001`, `0002`, …)
- **Title in file**: problem/solution style — e.g. `Use PostgreSQL for persistence` (MADR guidance)
- **Next number**: highest existing `NNNN` + 1; never reuse numbers

Inspect existing filenames under the decision log and choose the next highest unused number. Do not depend on helper scripts being present in consumer repositories.

## Default format: MADR (bare)

Use the repo's existing ADR shape when present; otherwise use the minimal MADR-style sections below unless the repo already uses Nygard or Y-Statements.

Required sections:

1. YAML frontmatter: `status`, `date`, `decision-makers` (and `consulted` / `informed` when known)
2. Context and Problem Statement
3. Considered Options (list all real alternatives)
4. Decision Outcome — `Chosen option: "…", because …`
5. Consequences — Good / Bad / Neutral
6. Pros and Cons of the Options (per option)
7. More Information (links, follow-ups)

### Status lifecycle

| Status | Meaning |
|--------|---------|
| `proposed` | Under discussion; not yet binding |
| `accepted` | Team agrees; implement accordingly |
| `deprecated` | No longer recommended; may still be in production |
| `superseded` | Replaced — **link** to the new ADR (`Superseded by [NNNN](NNNN-title.md)`) |
| `rejected` | Considered and not adopted (optional) |

When superseding: set old ADR to `superseded` and reference the new number; new ADR should mention what it replaces.

## Alternate formats

| Format | When | Reference |
|--------|------|-----------|
| **Nygard** | Minimal log, small teams | Context, Decision, Status, Consequences |
| **Y-Statement** | One-line decision in an index or changelog | "In the context of..., facing..., we decided..., to achieve..., accepting..." |

Match the format already used in the repo. Do not mix formats within one decision log without user approval.

## Authoring workflow

0. **Checkpoint** — if a trigger fired, brief or `proposed` ADR first; get explicit choice.
1. **Confirm scope** — one decision per ADR; split if multiple unrelated choices.
2. **Gather** — context, drivers, options considered, who decided, date (ISO `YYYY-MM-DD`).
3. **Draft** — fill template; write options you actually evaluated, not only the winner.
4. **Index** — add a row to `docs/decisions/README.mdx` when the repo keeps a decision index.
5. **Cross-link** — issues, PRs, diagrams, superseded ADRs.
6. **Review** — consequences must include downsides (trade-offs, not marketing).

## Decision log index (`README.md`)

Keep a table sorted by number (newest at bottom or top — match existing log):

```markdown
# Architecture Decision Records

| ADR | Status | Title | Date |
|-----|--------|-------|------|
| [0001](0001-use-postgresql.md) | accepted | Use PostgreSQL for persistence | 2026-05-29 |
```

## Quality bar

- **Specific**: names technologies and boundaries; links to code/modules when relevant
- **Honest**: lists rejected options and why they lost
- **Traceable**: status, date, supersede links
- **Concise**: prefer short sections; move long analysis to `More Information` or linked docs
- **No secrets**: no credentials, tokens, or private URLs in ADRs

## Output when creating an ADR

Tell the user:

1. File path created or updated
2. ADR number and title
3. Status
4. Whether index/README was updated
5. Suggested follow-up (implementation task, PR link placeholder)

## Install

```bash
npx skills add arenukvern/skill_steward --skill repository-governance-lifecycle
```

## References

- [adr.github.io](https://adr.github.io/) — ADR format background
- [MADR](https://adr.github.io/madr/) — MADR format background

## Sources

See [references/sources.md](references/sources.md). When researching, follow `skill-source-citations`.
