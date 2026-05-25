# Agentkit Phase 2 Implementation Plan

> **Status:** Done (2026-05-25). Closure: `docs/superpowers/closure/2026-05-25-agentkit-phase2.md`

**Goal:** Extract MCP publish into `agentkit_mcp`, make `McpHost` registry-centric, and remove `dart_mcp` from capability tool registration.

---

## Completed

- [x] `packages/agentkit_mcp` — bridge, result mapper, `McpPublishAdapter`
- [x] `McpHost` delegates MCP publish to `McpPublishAdapter`
- [x] Kernel `ToolRegistration` → `Future<AgentResult> Function(AgentArguments)`
- [x] All `server_capability_core` fmt tools migrated to `AgentResult`
- [x] `handler_helpers.runCommand` returns `AgentResult`
- [x] `DynamicToolEntry` stores `RegisteredAgentIntent` + MCP `Tool` metadata
- [x] Dynamic tools registered in `capabilityHost.agentRegistry`
- [x] `agent_registry_host_test.dart`, host tests updated
- [x] Docs note in `docs/guides/creating_dynamic_tools.mdx`

## Deferred

- [ ] Remove `dart_mcp` from `ResourceRegistration` in kernel
- [ ] `McpPublishAdapter implements AgentAdapter` on `AgentRuntime` (optional)

---

## Key design decisions

- Single invoke path: `registry.invoke` for static and dynamic tools
- `agentkit_mcp` is the only package bridging `AgentResult` ↔ `CallToolResult` for MCP
- Image screenshot artifacts use `AgentArtifact.text(base64, mimeType: image/png)`
