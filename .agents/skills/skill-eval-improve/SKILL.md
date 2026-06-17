---
name: skill-eval-improve
description: Improves Agent Skills via validate → rule-based eval cases → plugin-eval → prompt evals → bounded edits with held-out gates. Use when tuning skill quality, routing, or adopting Chrome/Microsoft T-named quality gates—not for bulk validate-only or SkillOpt automation.
license: MIT
type: governance
metadata:
  author: skill-steward
  version: "1.1.0"
  category: marketplace
paths:
  - "skills/**/evals/**"
  - "scripts/eval-skill.mjs"
  - "scripts/eval-tiers.mjs"
---

# Skill eval & improve

Improve skills **measurably**: baseline → measure → bounded edit → re-validate. Combine **local tooling**, **Codex plugin-eval** (when installed), and **research-backed** loops ([SkillOpt](https://microsoft.github.io/SkillOpt/)).

## When to use

- Skill triggers wrong or never loads (description routing)
- Bloated `SKILL.md`, high token cost, weak outcomes
- After adding a new procedure—need regression checks
- Porting patterns from product MCP / plugin-eval research into Skill Steward skills

## When not to use

- **Bulk repo validation** — e.g. “validate every skill in this repo” → `pnpm run validate` only ([skill-authoring-lifecycle](../skill-authoring-lifecycle/SKILL.md) for audit); do not start benchmark or SkillOpt loops.
- **Automated SkillOpt / cluster training** — Skill Steward documents a **manual** bounded-edit loop; no overnight optimizer pipeline.
- **Creating a new skill** — use [skill-authoring-lifecycle](../skill-authoring-lifecycle/SKILL.md) first; eval-improve applies after a skill exists.

Cursor scope (optional): activate when editing under `skills/**` or `scripts/validate-skills.mjs`.

## Mixture of experts (evaluation stack)

| Layer | Expert | Tool / method | Cost |
|-------|--------|---------------|------|
| **0 — Gate** | Lint | `pnpm run validate`, `skill-authoring-lifecycle` | seconds |
| **0b — Rules** | Routing/docs SSOT | `pnpm run eval` (T1 behavior-critical YAML cases) | seconds |
| **1 — Static** | Structure | Codex `plugin-eval analyze` (if available) | seconds |
| **2 — Human** | Behavior | 3–5 prompts with/without skill | minutes |
| **3 — Measured** | Usage | `plugin-eval benchmark` + `measurement-plan` | minutes–hours |
| **4 — Evolve** | Text optimization | SkillOpt-style bounded edits + held-out gate | hours |
| **5 — Navigate**| Telemetry / dogfood | Current `steward benchmark` scenarios on compact traces | seconds |

Use the **cheapest layer that answers the question**. Do not skip layer 0.

## Layer 0 — Skill Steward validator (always)

```bash
pnpm run validate
pnpm run validate:json   # CI / automation
```

Fix all `error:` lines. Treat `warn:` (missing `sources.md`, long SKILL.md) seriously.

## T-named skill quality gates ([ADR 0011](../../docs/decisions/0011-tiered-skill-evals-and-rule-based-ci.mdx), [ADR 0027](../../docs/decisions/0027-t-named-skill-quality-gates.mdx))

| Tier | Skills | CI |
|------|--------|-----|
| **T1 — Behavior-critical eval-gated** | Routing/procedure skills where drift can change agent decisions, claims, delegation, governance, or evidence boundaries | `pnpm run eval` + validate |
| **T2 — Structural validate-only** | All others | `pnpm run validate` |

T1 behavior-critical currently includes `harness-engineering-lifecycle`, `mcp-harness-repo-maintainer`, `mixture-of-experts`, `multi-agent-handoff`, `plugin-marketplace-setup`, `repo-quality-system-lifecycle`, `repository-governance-lifecycle`, `skill-authoring-lifecycle`, `skill-eval-improve`, `steward-continuity-boundary-lifecycle`, and `vision-alignment-foresight`. Each requires `evals/cases/*.yaml` (≥2) + `references/evals.md`. Schema: [eval-case-schema.md](references/eval-case-schema.md).

## Layer 0b — Rule-based cases (T1 behavior-critical CI)

```bash
pnpm run eval
pnpm run eval -- --skill mcp-harness-repo-maintainer
pnpm run eval:json
```

**Chrome eval design** (failure modes, rubrics, objective vs judge): [references/chrome-eval-design.md](references/chrome-eval-design.md).

**CI does not** run LLM judges. Subjective quality stays in `references/evals.md` (layer 2+).

## Layer 1 — Codex plugin-eval (local)

When Codex **plugin-eval** is installed (`~/.codex/plugins/.../plugin-eval`):

```bash
# Chat-first router
plugin-eval start skills/<name> --request "Evaluate this skill." --format markdown

# Static report
plugin-eval analyze skills/<name> --format markdown

# Token budget explanation
plugin-eval explain-budget skills/<name> --format markdown

# Starter benchmark config
plugin-eval init-benchmark skills/<name>
plugin-eval benchmark skills/<name> --dry-run
```

Hand off rewrite plans to plugin-eval’s **improve-skill** skill after `analyze --brief-out`.

Details: [references/plugin-eval.md](references/plugin-eval.md).

## Layer 2 — Human prompt suite (required for material edits)

1. Write **3–5 representative user prompts** (should trigger + should not trigger).
2. Run agent **without** skill → record failures.
3. Run **with** skill → record improvements and new failures.
4. Mirror prompts in `evals/cases/*.yaml` (CI rules) and `references/evals.md` (behavior log).

Split ~60% train (edit against) / 40% held-out (gate acceptance)—mirrors SkillOpt selection gate.

## Layer 3 — SkillOpt-inspired improve loop (research)

[SkillOpt](https://microsoft.github.io/SkillOpt/) treats `SKILL.md` as **trainable text** with a **frozen** agent:

```text
Rollout (tasks + current skill) → Reflect (failures vs successes)
  → Bounded edit (add/delete/replace under budget) → Held-out gate (keep only if better)
```

Skill Steward **manual** adaptation (no GPU cluster required):

| Step | Action |
|------|--------|
| 1 | Baseline: held-out pass rate without skill |
| 2 | With skill: same tasks, log pass rate |
| 3 | Reflect: list 1–3 concrete failure modes |
| 4 | **Bounded edit**: ≤10% line churn or one new section; no wholesale rewrite |
| 5 | Re-run **held-out only**; keep edit only if improved |
| 6 | Record outcome in `references/evals.md` + `sources.md` |

Paper: https://arxiv.org/abs/2605.23904 · Site: https://microsoft.github.io/SkillOpt/

Related: [SkillLens](https://microsoft.github.io/SkillOpt/) (model-generated skills study).

## Layer 4 — Ecosystem benchmarks (2026+)

| Resource | Use |
|----------|-----|
| [SkillsBench](https://arxiv.org/abs/2602.12670) | Inspiration for paired vanilla vs skill-augmented tasks |
| [skillgrade](https://github.com/mgechev/skillgrade) | Regression testing skill quality (mgechev) |
| Claude authoring best practices | Eval-before-write workflow |

## Layer 5 — Runtime Dogfood Benchmarks

At 10,000x scale, NLP prompt evaluation fails because LLMs suffer **Cognitive Overload** navigating massive toolsets. Runtime dogfood should objectively assert their logical trajectory using deterministic traces.

1. **Capture compact traces:** Store action IDs, tool counts, artifact digests, and redacted excerpts, not raw product traces.
2. **Define assertions:** Expected action trajectory, declared surfaces used first, maximum tool calls, maximum repair/setup attempts, maximum unrelated tool calls, required `return_to_goal_step`, required artifacts, and negative checks for unrelated actions.
3. **Run dogfood benchmarks:** Use `steward benchmark --scenario <id> --json` for runtime dogfood scenarios. Do not put product runtime scenarios under T1 behavior-critical skill evals.

The current `steward eval --name` registered-eval path is legacy/experimental. Skill quality remains `pnpm run eval`; runtime dogfood belongs to `steward benchmark`, where `durability_blocked` is valid blocked evidence when contract inputs are modified or untracked, not proof of runtime behavior.

## Improve workflow (checklist)

```
- [ ] sources.md cites plugin-eval + SkillOpt if used
- [ ] pnpm run validate
- [ ] T1 behavior-critical: `pnpm run eval` + cases updated
- [ ] plugin-eval analyze (optional)
- [ ] 3+ prompt evals documented in references/evals.md
- [ ] Bounded edit applied; held-out improved
- [ ] skill-authoring-lifecycle checklist
- [ ] PR mentions eval delta
```

## What to fix first (typical order)

1. `name` / `description` (routing)—must include **what + when**
2. Broken links / missing `references/sources.md`
3. Delete or replace duplicated rules before adding a new section or eval case
4. Move bulk to `references/` (SKILL.md &lt; 500 lines)
5. Add error-handling / validation steps agents skip
6. Token cost (description length, always-loaded content)

## Anti-patterns

- Rewriting entire SKILL.md from one failure (destroy working rules)
- Self-editing without held-out prompts (overfit)
- Adding skill rules, evals, or tools from one observed run when a smaller FAQ, error message, native command, observed-effect check, or deletion would solve the problem
- Adding a new eval for duplicated guidance before trying to compress, delete, or replace the overlapping rule
- Claims without `references/sources.md` rows
- Evaluating only with static analyze—never running real prompts
- LLM judge in CI (flake, cost) — offline only per [ADR 0011](../../docs/decisions/0011-tiered-skill-evals-and-rule-based-ci.mdx)
- Passing `pnpm run eval` and claiming agent behavior is proven

## Related skills

| Skill | Role |
|-------|------|
| `skill-source-citations` | Save research links |
| `skill-authoring-lifecycle` | Scaffold |
| `skill-authoring-lifecycle` | Pre-merge audit |

## Sources

See [references/sources.md](references/sources.md).

## Install

```bash
npx skills add arenukvern/skill_steward --skill skill-eval-improve
```
