> **ARCHIVED** — Historical snapshot (C5 complete). For current status see [deconstruct verification](../../evals/2026-05-26-deconstruct-verification.md) and [visual reconstruct plan](../2026-05-26-visual-reconstruct-next.md).

# Phase C coordination — deconstruct + reconstruct.start

**Status:** C5 validated (offline integration green, 2026-05-26)  
**Repos:** `flutter_visual_reconstruct`, `flutter_harness`, `mcp_flutter`  
**IR draft:** `flutter_harness/specs/ir_v0.schema.yaml`

## Agent roster

| Agent | Role | Deliverables | Status |
|-------|------|----------------|--------|
| **C1 Planner** | Architecture + task breakdown | `flutter_visual_reconstruct/plans/2026-05-26-phase-c-deconstruct.md` | Done |
| **C2 Library** | Deconstruct sidecar | `lib/src/deconstruct/`, CLI `deconstruct`, IR YAML writer | Done — 26 tests |
| **C3 Harness** | HS ops | `deconstruct`, `reconstruct` steps; linter; tests | Done — 57 tests |
| **C4 Agentkit** | MCP tool + entry | `reconstruct.start` in mcp_flutter; dogfood eval hook | Done |
| **C5 Validate** | E2E + fix | Tests green; HS smoke; eval script update | Done — no integration fixes required |

## Key design decisions

| Topic | Decision |
|-------|----------|
| IR format | YAML matching `ir_v0.schema.yaml` |
| Deconstruct v0 | MIT-only: tile color clustering + optional semantic hints file (no VLM) |
| Output | `ir.yaml` + `layers/` preview PNGs optional |
| `reconstruct.start` | Agentkit `AgentCallEntry` returning IR paths + harness script hint |
| HS `deconstruct` | VM capture name → write IR under `--bundle-dir` |
| HS `reconstruct` | Load IR → stub “render” = compare golden again (v0) |

## C5 validation results (2026-05-26)

| Gate | Result |
|------|--------|
| `flutter_visual_reconstruct` `dart test` | 26 passed |
| `flutter_harness` `dart test` | 57 passed |
| `check_hs_fixtures.sh` | OK (incl. `deconstruct_smoke.hs.yaml` offline) |
| `run_dogfood_eval.sh --skip-runtime --run-deconstruct-smoke` | exit 0; bundle under `.showcase/eval_runs/<id>/deconstruct_smoke_bundle` |
| Integration fixes | None |

**Remaining (non-blocking):** checkpoint protocol (HS + human `.approved`); full runtime dogfood with `WS_URI` / `DOGFOOD_VISUAL=1`.

## Verification (all agents)

```bash
cd flutter_visual_reconstruct && dart test
cd flutter_harness && dart test
FLUTTER_MCP_TOOLKIT_ROOT=../mcp_flutter bash flutter_harness/tool/harness/check_hs_fixtures.sh
cd mcp_flutter && bash tool/evals/run_dogfood_eval.sh --skip-runtime --run-deconstruct-smoke
```

## Merge order

1. C1 plan (non-blocking if prompts are complete)
2. C2 library + C3 harness + C4 agentkit (parallel)
3. C5 validate and fix integration breaks — **complete**
