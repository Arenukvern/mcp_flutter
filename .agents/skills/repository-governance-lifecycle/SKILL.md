---
name: repository-governance-lifecycle
description: Master orchestration for repository governance, North Star impact, sub-Star boundaries, and repair-first or evidence-first drift checks. Guides an agent through the complete lifecycle of making architectural decisions, documenting them, writing FAQs, and cleaning up stale plans while adhering strictly to repo ethics and brand tone. Use whenever you need to make a structural change, write an ADR, update the doc lattice, or govern repository architecture.
license: MIT
type: governance
metadata:
  author: skill-steward
  version: "1.1.0"
  category: governance
---

# Repository Governance Lifecycle

This is the central nervous system for governing an agent-operated repository. It applies to apps, libraries, tools, plugins, harnesses, and meta repos; Skill Steward itself remains a structural stewardship repo, not a domain tutorial catalog. It unifies ethics, branding, architectural decision logs (ADRs), and living documentation (FAQs) into a single, cohesive loop: **Decide → Document → Cleanup**.

Whenever an agent proposes or executes a structural shift, claim change, durable policy change, or docs-lattice change, they must walk this loop. Routine repo repairs should keep the original goal and native gate first; use this governance loop only when the repair changes durable ownership, policy, evidence, ADR/FAQ truth, or plan hygiene.

## The Governance Loop

### 1. Check Ethics & Boundaries (NORTH_STAR)
Before making any decision, check the repository's foundational charter and ethical baseline.
- Read [Charter and Ethics](references/charter-and-ethics.md) to ensure your proposed changes do not violate the repository's moral boundaries (e.g. no hype; no domain tutorials inside Skill Steward; domain docs belong in the governed product repo when they are that repo's product).
- Read [North Star Rules](references/north-star-rules.md) to understand the extension model.
- Classify `north_star_impact` for durable structural changes: `none`, `applies`, `clarifies`, `sub_star`, `amends`, or `conflicts`. Use the protocol only when ownership, policy, evidence truth, ADR/FAQ truth, or the repo's center may change.
- Ask the gate questions before editing durable governance surfaces: what pain triggered this; which North Star value path it serves; whether it is a mechanism or a new center; whether it changes what the repo owns or refuses; where the ADR is if it does; and what check prevents the mechanism becoming the mission if it does not.
- Route `none` and `applies` through the native workflow, `clarifies` through FAQ/skill/map/check updates, `sub_star` through an explicit parent/child boundary, and `amends` or `conflicts` through an ADR plus a North Star diff before implementation.

### 2. Log the Decision (ADRs)
If you have made an architecturally significant decision (or triggered a T1-T8 threshold), you must write it down. Decisions are not valid if they only live in an agent's context window.
- Follow the formatting rules in [ADR Format](references/adr-format.md) to write a formal Decision Record.

### 3. Update Living Docs (FAQs)
Decisions change how the repository operates day-to-day. You must update the living system of record.
- Update `docs/DESIGN_FAQ.mdx` (the *Why*) or `docs/DX_FAQ.mdx` (the *How*).
- Follow the exact structuring rules in [FAQ Format](references/faq-format.md) to ensure questions are searchable and direct.

### 4. Apply Brand & Tone Identity
When writing ADRs, FAQs, or any user-facing documentation, you must adhere strictly to the repository's tone.
- Do not use corporate marketing jargon.
- Review the banned word list in [Brand Guidelines](references/brand-guidelines.md) (e.g. do not use "unlock", "supercharge", "ultimate").

### 5. Plan Hygiene (Cleanup)
Never leave stale planning artifacts (`task.md`, `implementation_plan.md`) as permanent documentation.
- Once the ADR and FAQs are updated, your knowledge is durable.
- Extract any remaining useful context and delete or ignore the scratch files.
- For stale or overlapping non-plan docs, choose one disposition before editing: keep, merge, move to ADR, move to FAQ, move to skill, move to check, move to evidence, move to consumer proof, or delete.
- Ask what existing doc can shrink or disappear because of this change.
- Keep canonical architecture in the owning repo; consumer repos should carry adoption proof, local deltas, blocked state, and links to the owner.
- For broader surface-shape decisions such as split, compress, promote, demote, delete, or stay native, route through [repo-quality-system-lifecycle](../repo-quality-system-lifecycle/SKILL.md) and [Evolutionary simplicity](../../docs/core/evolutionary-simplicity.mdx) instead of inventing a governance-only doctrine.
- Before upgrading steward, adoption, harness-ready, or maturity language in an ADR/evidence note, run `steward claim check --claim <claim> --evidence <path> --json`. Treat `not_rejected` as a negative-gate result, not acceptance.

### 6. Route Evidence Deliberately
Do not turn every run, plan, or discussion into evidence. Use [Evidence artifacts](../../docs/core/evidence-artifacts.mdx) as the routing rule:

- ADR: durable decision, trade-off, status, or consequence.
- FAQ: standing why/how that humans and agents will ask again.
- Skill: repeatable agent procedure or interpretation loop.
- Check/tool/schema/test: deterministic drift, freshness, shape, or blocked-state detection.
- Current ledger: weakest true current status and rerun route.
- Evidence artifact: real run proof, blocked state, pattern review, PDSA loop, postmortem, unknown case, or reference that protects a claim or changes future behavior.
- Delete/remove: completed checklist, stale plan, or template once useful truth has been extracted.

When you create or materially update an evidence artifact, use the canonical envelope in [Evidence artifacts](../../docs/core/evidence-artifacts.mdx). ADR 0023 explains why that envelope exists.

## Install

```bash
npx skills add arenukvern/skill_steward --skill repository-governance-lifecycle
```

## Sources

See [references/sources.md](references/sources.md).
