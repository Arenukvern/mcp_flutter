# Evals — mcp-harness-repo-maintainer

## Should trigger

| ID | User prompt | Pass criteria |
|----|-------------|---------------|
| T1 | Enforce CLI/MCP/core split on product MCP PR | Archetype A checklist |
| T2 | Bootstrap a local repo harness with `steward.yaml` and prove the cold-start contract before diagnosing failures | Runs `doctor -> actions list -> action inspect -> probe -> benchmark`, interprets `durability_blocked`, and does not invent diagnostics |
| T3 | Repeated adoption friction should become an unknown case or action candidate | Uses the H3→H5 promotion packet; captures first, promotes only after review |
| T4 | Single fresh-agent transcript asks for immediate diagnostic promotion | Rejects same-run promotion; records unknown case first |
| T5 | Adoption proof contains local-only Steward invocation paths | Routes to portable invocation hierarchy; keeps absolute paths as provenance only |
| T6 | Deterministic native gate should become a useful Steward action | Requires a tool improvement packet with falsifier, positive proof, safety/effects, redaction, validation, and non-claims |
| T7 | One proved workflow is being called a fully adopted repo | Classifies the capability with adoption-run/v2 and uses capability-level proof language |
| T8 | Tool restoration is taking over the original user task | Applies the detour budget, stops after two repair/setup attempts, records friction, and returns to the acceptance check |
| T9 | Steward adoption keeps adding tools without a pattern-layer decision | Runs the Skeptic/generational check, names the smallest useful layer, and records maintenance delta plus held-out proof requirement |
| T10 | A harness command mixes unrelated effects/proof while adopters need one CI route | Applies evolutionary simplicity for interfaces: split internals by owner/proof/effects and keep compressed CLI/MCP/help wrappers only when structured child outcomes remain inspectable |

## Should not trigger

| ID | User prompt | Pass criteria |
|----|-------------|---------------|
| N1 | Sourdough recipe | Dormant |

## Held-out

| ID | Prompt | Notes |
|----|--------|-------|
| H1 | Generalize a local Steward harness change across ecsly and intentcall after each repo already has a passing contract scenario | Should route primarily to `harness-engineering-lifecycle`; use this skill only for local contract shape questions |

## Edit log

| Date | Change | Kept? |
|------|--------|-------|
| 2026-06-05 | Added cold-start contract routing case after Steward benchmark proof loop landed | Yes |
| 2026-06-10 | Added H3→H5 adoption promotion routing cases | Yes |
| 2026-06-10 | Added portable Steward invocation routing case after local-path adoption proof drift | Yes |
| 2026-06-10 | Added native deterministic gate promotion case after bounded `mcp_flutter` hosted-dependency adoption | Yes |
| 2026-06-10 | Added goal-first detour and capability-classification cases after adoption-drift review | Yes |
| 2026-06-10 | Added generational architecture skeptic case after tool-loop drift review | Yes |
| 2026-06-15 | Added interface split/compress case so validation lanes and CLI/MCP wrappers preserve child truths | Yes |
