# Agentkit Program Rollout

> **For agentic workers:** Run the [Self-Closing Implementation Loop](../agentkit-self-closing-loop.md) until tracker `program.status` reflects the active milestone. Phases 1–4 are **done**; Phase 5 hardening is tracked separately.

**Goal:** Implement the [agentkit design spec](../specs/2026-05-25-agentkit-design.md) through registry-backed MCP (Phases 1–4), then harden via [Phase 5 hardening spec](../specs/2026-05-25-agentkit-phase5-hardening-design.md).

**Tracker (machine state):** [../tracker/agentkit-rollout.yaml](../tracker/agentkit-rollout.yaml)

---

## Phase map

| Phase | Plan / spec | Status | Exit (summary) |
|-------|-------------|--------|----------------|
| **1** | [phase1](2026-05-25-agentkit-phase1.md) | `done` | Registry invoke path; packages; MCP/CLI unchanged; codegen annotations-only |
| **2** | [phase2](2026-05-25-agentkit-phase2.md) | `done` | Kernel without `dart_mcp`; adapter-owned publish; dynamic registry intents |
| **3** | [phase3](2026-05-25-agentkit-phase3.md) | `done` | WebMCP + Gemma adapters shipped; native manifest codegen started; split/shims deferred |
| **4** | [phase4 closure](../closure/2026-05-25-agentkit-phase4-registry-resources.md) | `done` | Registry-backed `registerResource`; dynamic resources; WebMCP hot-sync |
| **5** | [phase5 hardening](../specs/2026-05-25-agentkit-phase5-hardening-design.md) | `in_progress` | **5-A** docs hygiene `done`; **5-B** runtime consolidation; **5-C** authoring/codegen |

Closure reports: [../closure/](../closure/) (phase1–4).

---

## Self-closing loop (summary)

1. **Implementer** executes the active phase plan or hardening sub-phase.
2. **Closer** runs phase gate → writes closure report.
3. **If fail:** Closer regenerates **same** phase plan (v+1) with fix tasks; return to step 1.
4. **If pass:** Closer marks phase `done`, sets next `active_phase`; return to step 1.
5. **Milestone stop:** Phases 1–4 gates passed → `program.status: complete_milestone`. Phase 5 sub-phases use the hardening spec until B/C gates pass or work is deferred with tracker notes.

Full protocol: [../agentkit-self-closing-loop.md](../agentkit-self-closing-loop.md)

---

## Closer invocation (when to run)

| Trigger | Action |
|---------|--------|
| Implementer says "phase done" | Run Closer gate — do not trust without verification |
| All phase plan checkboxes `[x]` | Run Closer gate |
| CI failed on agentkit paths | Run Closer gate with `fail`; regenerate repair plan |
| User says "close phase N" | Run Closer gate for phase N |
| Phase 5 sub-phase done | Update tracker `phase5` sub-phase status; optional closure note |

---

## Design spec coverage (program-level)

Phases 1–4 delivered the table below. Phase 5-B/C close remaining gaps (codegen generator, runtime consolidation, expanded native docs).

| Design area | Status (phases 1–4) |
|-------------|---------------------|
| Two-layer authoring (descriptor + registration) | done |
| Client DX (envelope, wire, lazy install, builder) | done |
| Multi-adapter `AgentRuntime` | done (MCP, WebMCP, Gemma example-only) |
| MCP via `agentkit_mcp` only | done |
| Dynamic registry as intents | done |
| `agentkit_webmcp`, `agentkit_gemma` | done (adapters shipped; Gemma example-only) |
| Apple/Android manifest codegen | started |
| Registry-backed resources + hot-sync | done (phase 4) |
| `dart_mcp` ecosystem alignment | done (kernel decoupled) |
| Optional `@AgentTool` codegen generator | deferred → Phase 5-C |
| Standalone repo split / shim removal | deferred → tracker `deferred_work` |

---

## Artifacts produced by the loop

| Artifact | Producer |
|----------|----------|
| Phase implementation plans | Closer (initial + next phase) / Implementer (task updates) |
| Closure reports | Closer |
| `tracker/agentkit-rollout.yaml` | Closer |
| Phase 5 hardening spec | Architecture / Implementer (5-A) |
| Code & tests | Implementer (phases 1–4 done; 5-B/C pending) |

---

## Current action

**Phase 5-A (documentation & program hygiene):** complete.  
**Next step:** Implementer runs **Phase 5-B** per [2026-05-25-agentkit-phase5-hardening-design.md](../specs/2026-05-25-agentkit-phase5-hardening-design.md) — runtime consolidation (code changes allowed; Closer gate when done).
