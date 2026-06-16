# Evals — mixture-of-experts

## Should trigger

| ID | User prompt | Pass criteria |
|----|-------------|---------------|
| T1 | Run a MoE audit with specialized subagents to criticize this architecture plan | Spawns or simulates orthogonal expert lenses, includes the Generational Architecture Skeptic for stewardship/tooling/growing-product work, gives each lens a scope/output/integration contract, labels partial or missing lenses, and synthesizes findings. |
| T2 | Run MoE critique on these evidence artifacts and retention rules. Which notes are ADRs, current ledgers, historical evidence, templates, checks, or deletion candidates? | Includes Evidence / Retention QA, names artifact status and claim protected, and routes stale or repeated material to ledger, check/tool, ADR/FAQ/skill, or deletion before recommending new evidence. |
| T3 | Run MoE subagents to judge whether a parallel stewardship conversation helped or became overhead | Uses MoE for contradiction and evidence-boundary critique, records lens status, checks cold-to-hot usefulness and native-gate evidence, and hands implementation authority to `multi-agent-handoff` instead of authorizing writes from MoE findings. |
| T4 | Run MoE critique on duplicated skill guidance and command-shape proposals | Ends with a surface disposition such as `compress_existing`, `delete_or_retire`, or `leave_native` when that is stronger than promoting another artifact. |

## Should not trigger

| ID | User prompt | Pass criteria |
|----|-------------|---------------|
| N1 | Install Skill Steward skills into Cursor | Dormant; use install/update docs. |

## Held-out

| ID | Prompt | Notes |
|----|--------|-------|
| H1 | Quick read-only critique with no artifact requested | Should run read-only critique mode and avoid creating plan files. |

## Edit log

| Date | Change | Kept? |
|------|--------|-------|
| 2026-06-05 | Added T1 behavior-critical routing cases and read-only critique coverage | Yes |
| 2026-06-10 | Added Generational Architecture Skeptic coverage to prevent tool-loop and adoption-drift overclaims | Yes |
| 2026-06-11 | Added subagent ownership contracts, partial-lens handling, and Evidence / Validation QA coverage | Yes |
| 2026-06-12 | Added Evidence / Retention QA coverage for evidence archive and claim-proof discipline | Yes |
| 2026-06-13 | Added parallel governance boundary coverage so MoE critique cannot replace parent lane contracts, landing, or terminal states | Yes |
| 2026-06-15 | Added evolutionary-simplicity synthesis coverage so MoE can recommend compression, deletion, or native ownership instead of artifact promotion | Yes |
