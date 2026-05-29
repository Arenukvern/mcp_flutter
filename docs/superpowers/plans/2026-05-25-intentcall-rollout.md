# intentcall Program Rollout

> **For agentic workers:** Use [tracker](../tracker/intentcall-rollout.yaml) for machine state. Phases 1–6 + integration + **product (phase 8)** are **done**. Extract is **Phase 7** (pending).

**Goal:** Finish intentcall **inside mcp_flutter** (real wiring, no stubs, migration complete), then extract to a standalone repo.

| Spec | Role |
|------|------|
| [Design](../specs/2026-05-25-intentcall-design.md) | Architecture |
| [Phase 5 hardening](../specs/2026-05-25-intentcall-phase5-hardening-design.md) | Docs + runtime + codegen pilot (done) |
| [Phase 6 pre-extract](../specs/2026-05-26-intentcall-pre-extract-completion-design.md) | Bar D — hard cut, Swift/XML, migration CLI/MCP |

**Tracker:** [../tracker/intentcall-rollout.yaml](../tracker/intentcall-rollout.yaml)

---

## Phase map

| Phase | Doc | Status | Summary |
|-------|-----|--------|---------|
| **1** | [archive/phase1](archive/2026-05-25-intentcall-phase1.md) | done | Registry, packages, client DX |
| **2** | [archive/phase2](archive/2026-05-25-intentcall-phase2.md) | done | Kernel without `dart_mcp` |
| **3** | [archive/phase3](archive/2026-05-25-intentcall-phase3.md) | done | WebMCP, Gemma example, manifest JSON |
| **4** | [closure phase4](../closure/2026-05-25-intentcall-phase4-registry-resources.md) | done | Registry-backed resources + hot-sync |
| **5** | [hardening spec](../specs/2026-05-25-intentcall-phase5-hardening-design.md) | done | 5-A docs, 5-B runtime, 5-C codegen pilot |
| **6** | [spec](../specs/2026-05-26-intentcall-pre-extract-completion-design.md) | done | Bar D: hard cut, platform sync, migration CLI, skills — [closure](../closure/2026-05-26-intentcall-program-complete-in-repo.md) |
| **8** | [product closure](../closure/2026-05-26-intentcall-product-complete-in-repo.md) | done | Init CLI, invoke plugin, `fmt_migrate_agent_entries`, CI codegen `--check` |
| **7** | [phase7 extract](2026-05-27-intentcall-phase7-extract.md) | in progress | Standalone intentcall monorepo (7.4–7.7 pending publish) |

Closures: [../closure/](../closure/).

---

## Program status

- **Phases 1–5:** Gates passed on `feat/intentcall-phase1-3`.
- **`program.status`:** `complete_in_repo_product` — see [product closure](../closure/2026-05-26-intentcall-product-complete-in-repo.md) and [integration closure](../closure/2026-05-26-intentcall-integration-complete.md).
- **Extract:** Phase 7 — **in progress** (7.1–7.3, 7.6 done; 7.4–7.5, 7.7 pending — see [tracker](../tracker/intentcall-rollout.yaml)).

---

## Self-closing loop

[intentcall-self-closing-loop.md](../intentcall-self-closing-loop.md) — Closer runs verification; implementer executes active plan/spec.

---

## Design coverage (1–5)

| Area | Status |
|------|--------|
| Registry invoke (tools + static resources) | done |
| `AgentRuntime` + `McpPublishAdapter` attach | done (5-B) |
| Dynamic registry intents + hot-sync | done |
| `intentcall_codegen` pilot | done (5-C; not full product codegen) |
| `MCPCallEntry` → `AgentCallEntry` migration | **done** — hard cut + CLI migrate |
| Resource templates via registry | **done** — `app/errors/{count}` |
| Skills/docs teach `AgentCallEntry` | **done** |
| Platform emitters (`intentcall_platform`) | **done** — web + native |
| Standalone repo | **Phase 7** |

---

## Current action

**Integration hardening:** complete (2026-05-27) — archived [integration completion plan](archive/2026-05-26-intentcall-integration-completion-next.md). Tracker: `integration_hardening_complete: true`.

**Phase 7:** [Phase 7 extract plan](2026-05-27-intentcall-phase7-extract.md) — **in progress** (publish/cutover pending). Index: [WHATS_NEXT](../WHATS_NEXT.md) · [tracker](../tracker/intentcall-rollout.yaml).
