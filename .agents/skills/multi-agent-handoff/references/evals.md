# Evals — multi-agent-handoff

## Should trigger

| ID | User prompt | Pass criteria |
|----|-------------|---------------|
| T1 | Use subagents to fix several independent repo problems while preserving the original goal and native gates | Uses a parent batch contract with original goal, acceptance check, product impact line, native/aggregate gates, claim ceiling, non-claims, lane write sets, and terminal states; closes by filling a structured acceleration note with `Saved`, `Cost/duplication`, and `Future hot path`. |
| T2 | A worker proved a fix in a temp clone; decide whether it is adoption evidence | Requires a landing phase: isolate the source-owned diff, apply it to the owner checkout, rerun the native gate, update evidence only if the claim changed, and keep temp proof as input until then. |
| T3 | Parallel Steward work reports green gates but no product-facing change | Requires a product impact check and downgrades the claim to stewardship support unless the owner checkout has a product delta or product-native proof. |
| T4 | A parallel subagent batch created overhead without lowering uncertainty or future repair time | Chooses `leave_native`, `rejected`, or another low-claim terminal state; collapses/deletes batch scaffolding and avoids durable artifacts unless future behavior changed. |

## Should not trigger

| ID | User prompt | Pass criteria |
|----|-------------|---------------|
| N1 | Run a single native formatter after a small local edit | Dormant; use the repo's native workflow unless context must move between agents. |

## Held-out

| ID | Prompt | Notes |
|----|--------|-------|
| H1 | A read-only reviewer times out during a MoE audit | Parent synthesis records the lens as `timed_out` or `partial`, downgrades the claim, and does not silently treat it as integrated evidence. |

## Edit log

| Date | Change | Kept? |
|------|--------|-------|
| 2026-06-13 | Added parallel batch, source-owned landing, terminal-state routing, and acceleration closeout cases after ADR 0026 adoption review | Yes |
| 2026-06-13 | Added product-impact guardrail so parallel proof cannot claim product acceleration without source-owned product movement | Yes |
| 2026-06-15 | Added parallel-overhead collapse case so subagent batches can be rejected or left native instead of becoming project-management residue | Yes |
