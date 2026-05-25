# Agentkit Phase 2 Implementation Plan

> **Status:** Placeholder — **do not implement** until Closer generates this plan after Phase 1 gate `pass`.

**Prerequisite:** `docs/superpowers/tracker/agentkit-rollout.yaml` → `phases[phase1].status: done`

**How this file is created:** Closer agent runs [self-closing loop](../agentkit-self-closing-loop.md) Step 4b using:

- Design spec: [2026-05-25-agentkit-design.md](../specs/2026-05-25-agentkit-design.md) — *Migration phases / Phase 2*
- Closure: `docs/superpowers/closure/YYYY-MM-DD-agentkit-phase1.md`
- Skill: `writing-plans`

**Expected scope (from design spec):**

- `McpHost` registry-only; `McpAgentAdapter` owns `dart_mcp` publish
- `DynamicRegistry` stores `RegisteredAgentIntent`, not `dart_mcp.Tool`
- Remove `dart_mcp` from `server_capability_kernel`
- Document client authoring paths

---

*Replace this placeholder with the full task-by-task plan when Phase 1 closes.*
