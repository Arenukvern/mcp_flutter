# Agentkit Phase 2 Implementation Plan

> **Status:** Active after Phase 1 gate pass (2026-05-25).

**Goal:** Extract MCP publish into `agentkit_mcp`, make `McpHost` registry-centric, and remove `dart_mcp` from `server_capability_kernel` where possible.

**Prerequisite:** Phase 1 closure `docs/superpowers/closure/2026-05-25-agentkit-phase1.md`

---

## Completed in this branch (partial Phase 2)

- [x] `packages/agentkit_mcp` — bridge, result mapper, `McpPublishAdapter`
- [x] `McpHost` delegates MCP publish to `McpPublishAdapter`
- [x] Kernel `agent_bridge` removed; bridge lives in `agentkit_mcp`
- [x] `agent_registry_host_test.dart` — registry invoke parity

## Remaining tasks

### Task 1: Kernel — remove `dart_mcp` from `ToolRegistration`

**Files:** `packages/server_capability_kernel/lib/src/tool_registration.dart`

- [ ] Change handler to `Future<AgentResult> Function(AgentArguments)` (or `RegisteredAgentIntent` factory)
- [ ] Update all capabilities to return `AgentResult` directly
- [ ] Remove `dart_mcp` from kernel `pubspec.yaml`

### Task 2: DynamicRegistry → `RegisteredAgentIntent`

**Files:** `mcp_server_dart/lib/src/capabilities/dynamic_registry/`

- [ ] Store `RegisteredAgentIntent` alongside or instead of `dart_mcp.Tool`
- [ ] Publish dynamic tools via `McpPublishAdapter` + registry invoke

### Task 3: `McpHost` registry-only surface

- [ ] Optional: wire `AgentRuntime` with `McpPublishAdapter implements AgentAdapter`
- [ ] Remove duplicate `DartMcpDispatchBridge` typedefs; use `agentkit_mcp` types only

### Task 4: Docs + gate

- [ ] Update `creating_dynamic_tools.mdx`
- [ ] Closer gate → phase3 plan

---

## Key design decisions

- Single invoke path unchanged: `registry.invoke`
- Kernel stays transport-free after Task 1
- `agentkit_mcp` is the only package that imports `dart_mcp` for server publish
