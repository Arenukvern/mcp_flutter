# Agentkit Program Rollout

> **For agentic workers:** Use [tracker](../tracker/agentkit-rollout.yaml) for machine state. Phases 1–5 are **done**. Pre-extract completion is **Phase 6** (spec pending).

**Goal:** Finish agentkit **inside mcp_flutter** (real wiring, no stubs, migration complete), then extract to a standalone repo.

| Spec | Role |
|------|------|
| [Design](../specs/2026-05-25-agentkit-design.md) | Architecture |
| [Phase 5 hardening](../specs/2026-05-25-agentkit-phase5-hardening-design.md) | Docs + runtime + codegen pilot (done) |
| [Phase 6 pre-extract](../specs/2026-05-26-agentkit-pre-extract-completion-design.md) | Bar D — hard cut, Swift/XML, migration CLI/MCP |

**Tracker:** [../tracker/agentkit-rollout.yaml](../tracker/agentkit-rollout.yaml)

---

## Phase map

| Phase | Doc | Status | Summary |
|-------|-----|--------|---------|
| **1** | [archive/phase1](archive/2026-05-25-agentkit-phase1.md) | done | Registry, packages, client DX |
| **2** | [archive/phase2](archive/2026-05-25-agentkit-phase2.md) | done | Kernel without `dart_mcp` |
| **3** | [archive/phase3](archive/2026-05-25-agentkit-phase3.md) | done | WebMCP, Gemma example, manifest JSON |
| **4** | [closure phase4](../closure/2026-05-25-agentkit-phase4-registry-resources.md) | done | Registry-backed resources + hot-sync |
| **5** | [hardening spec](../specs/2026-05-25-agentkit-phase5-hardening-design.md) | done | 5-A docs, 5-B runtime, 5-C codegen pilot |
| **6** | [spec](../specs/2026-05-26-agentkit-pre-extract-completion-design.md) | pending | Bar D: hard cut, Swift/XML, migration tools, skills |

Closures: [../closure/](../closure/).

---

## Program status

- **Phases 1–5:** Gates passed on `feat/agentkit-phase1-3`.
- **`program.status`:** `complete_milestone` — in-repo delivery; see tracker `deferred_work`.
- **Extract:** Blocked until Phase 6 exit criteria pass (no standalone repo until then).

---

## Self-closing loop

[agentkit-self-closing-loop.md](../agentkit-self-closing-loop.md) — Closer runs verification; implementer executes active plan/spec.

---

## Design coverage (1–5)

| Area | Status |
|------|--------|
| Registry invoke (tools + static resources) | done |
| `AgentRuntime` + `McpPublishAdapter` attach | done (5-B) |
| Dynamic registry intents + hot-sync | done |
| `agentkit_codegen` pilot | done (5-C; not full product codegen) |
| `MCPCallEntry` → `AgentCallEntry` migration | **partial** — bridge only |
| Resource templates via registry | **exception** — `addResourceTemplate` for `app/errors/{count}` |
| Skills/docs teach `AgentCallEntry` | **pending** → Phase 6 |
| Public shim removal | **pending** → Phase 6 |
| Standalone repo | **after Phase 6** |

---

## Current action

**Phase 6:** Spec approved (Bar D). Implement per [phase6 plan](2026-05-26-agentkit-phase6-pre-extract.md) when published. No monorepo extract until `complete_in_repo` gate.
