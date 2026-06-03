---
name: repository-governance-lifecycle
description: Master orchestration for repository governance. Guides an agent through the complete lifecycle of making architectural decisions, documenting them, writing FAQs, and cleaning up stale plans while adhering strictly to repo ethics and brand tone. Use whenever you need to make a structural change, write an ADR, update the doc lattice, or govern repository architecture.
license: MIT
type: governance
metadata:
  author: skill-steward
  version: "1.1.0"
  category: governance
---

# Repository Governance Lifecycle

This is the central nervous system for governing the repository. It unifies ethics, branding, architectural decision logs (ADRs), and living documentation (FAQs) into a single, cohesive loop: **Decide → Document → Cleanup**.

Whenever an agent proposes or executes a structural shift, they must walk this loop.

## The Governance Loop

### 1. Check Ethics & Boundaries (NORTH_STAR)
Before making any decision, check the repository's foundational charter and ethical baseline.
- Read [Charter and Ethics](references/charter-and-ethics.md) to ensure your proposed changes do not violate the repository's moral boundaries (e.g. no hype, no domain tutorials).
- Read [North Star Rules](references/north-star-rules.md) to understand the extension model.

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

## Install

```bash
npx skills add arenukvern/skill_steward --skill repository-governance-lifecycle
```

## Sources

See [references/sources.md](references/sources.md).
