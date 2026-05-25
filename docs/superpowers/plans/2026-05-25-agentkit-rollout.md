# Agentkit Program Rollout

> **For agentic workers:** Run the [Self-Closing Implementation Loop](../agentkit-self-closing-loop.md) until `tracker/agentkit-rollout.yaml` reports `program.status: complete`.

**Goal:** Implement the full [agentkit design spec](../specs/2026-05-25-agentkit-design.md) across three phases with mandatory verification and plan regeneration between phases.

**Tracker (machine state):** [../tracker/agentkit-rollout.yaml](../tracker/agentkit-rollout.yaml)

---

## Phase map

| Phase | Plan | Status | Exit (summary) |
|-------|------|--------|----------------|
| **1** | [phase1](2026-05-25-agentkit-phase1.md) | `pending` | Registry invoke path; packages; client DX; MCP/CLI unchanged |
| **2** | [phase2](2026-05-25-agentkit-phase2.md) | `pending` | Kernel without `dart_mcp`; adapter-owned publish; dynamic registry intents |
| **3** | [phase3](2026-05-25-agentkit-phase3.md) | `pending` | Split repo; webmcp + gemma; native codegen; shim removal |

Phase 2 and Phase 3 plans are **authored by the Closer** after the previous phase gate passes. Placeholder paths exist; content is generated on first pass.

---

## Self-closing loop (summary)

1. **Implementer** executes the active phase plan.
2. **Closer** runs phase gate → writes closure report.
3. **If fail:** Closer regenerates **same** phase plan (v+1) with fix tasks; return to step 1.
4. **If pass:** Closer marks phase `done`, regenerates **next** phase plan, sets `active_phase`; return to step 1.
5. **Stop** when Phase 3 gate passes and tracker `program.status: complete`.

Full protocol: [../agentkit-self-closing-loop.md](../agentkit-self-closing-loop.md)

---

## Closer invocation (when to run)

| Trigger | Action |
|---------|--------|
| Implementer says "phase done" | Run Closer gate — do not trust without verification |
| All phase plan checkboxes `[x]` | Run Closer gate |
| CI failed on agentkit paths | Run Closer gate with `fail`; regenerate repair plan |
| User says "close phase N" | Run Closer gate for phase N |

---

## Design spec coverage (program-level)

Closer must confirm these design areas are **`pass`** by end of Phase 3 (may complete earlier per phase map):

| Design area | Target phase |
|-------------|--------------|
| Two-layer authoring (descriptor + registration) | 1 |
| Client DX (envelope, wire, lazy install, builder) | 1 |
| Multi-adapter `AgentRuntime` | 1–2 |
| MCP via `agentkit_mcp` only | 2 |
| Dynamic registry as intents | 2 |
| `agentkit_webmcp`, `agentkit_gemma` | 3 |
| Apple/Android manifest codegen | 3 |
| `dart_mcp` ecosystem alignment | 1–3 |

---

## Artifacts produced by the loop

| Artifact | Producer |
|----------|----------|
| Phase implementation plans | Closer (initial + next phase) / Implementer (task updates) |
| Closure reports | Closer |
| `tracker/agentkit-rollout.yaml` | Closer |
| Code & tests | Implementer |

---

## Current action

**Active phase:** `phase1` (see tracker)  
**Next step:** Implementer runs [2026-05-25-agentkit-phase1.md](2026-05-25-agentkit-phase1.md) → Closer runs gate per [self-closing loop](../agentkit-self-closing-loop.md).
