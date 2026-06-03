# Evals — skill-eval-improve

Prompt suite and results. **Do not** paste full transcripts into SKILL.md.

## Should trigger

| ID | User prompt | Pass criteria |
|----|-------------|---------------|
| T1 | Improve this SKILL.md after reviewers said the description is vague | Agent uses layer 0 → 2 → bounded edit loop; mentions evals.md |
| T2 | Run plugin-eval analyze on skills/my-skill and suggest one small fix | Agent runs analyze path; suggests ≤10% churn; points to evals.md for gate |
| T3 | How do I apply SkillOpt-style gates to our guild skills? | Explains manual Guild loop (not GPU cluster); cites held-out validation |

## Should not trigger

| ID | User prompt | Pass criteria |
|----|-------------|---------------|
| N1 | Run pnpm validate on skill_steward | Stays dormant or points to layer 0 only (`pnpm run validate`), not full eval-improve workflow |
| N2 | Create a new skill for ADR writing | Routes to `skill-authoring-lifecycle` / `adr-records`, not skill-eval-improve |

## Held-out (gate)

| ID | Prompt | Baseline (no skill) | With skill v1.0.0 |
|----|--------|---------------------|-------------------|
| H1 | Apply full SkillOpt training pipeline to skills/foo overnight | Often over-promises automated optimizer infra | **Fail** — SKILL.md lacks “manual only” guard |
| H2 | Validate every skill in this repo before merge | Often starts benchmark/SkillOpt checklist | **Fail** — conflated with bulk `pnpm run validate` |
| H3 | Improve skill-eval-improve using held-out only after a small edit | Should say re-run H* rows only, not full MoE stack | TBD after edit |

## Edit log

| Date | Change summary | Held-out targeted | Kept? |
|------|----------------|-------------------|-------|
| 2026-05-29 | Add `## When not to use` (routing vs layer 0 / SkillOpt) | H1, H2 | yes — addresses held-out conflation |
