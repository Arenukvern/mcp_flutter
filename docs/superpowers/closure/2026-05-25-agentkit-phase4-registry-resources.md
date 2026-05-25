# Agentkit Phase 4 — Registry-backed resources (closure)

**Date:** 2026-05-25  
**Verdict:** pass  
**Branch:** `feat/agentkit-phase1-3`

## Scope

Complete the deferred Phase 3 item **host `registerResource` via registry** and wire dynamic + static MCP resources through `AgentRegistry.invoke`, with hot-sync on registry events. **Gemma** intentionally unchanged (example-only adapter).

## Validation

| Command | Result |
|---------|--------|
| `dart test packages/agentkit_mcp` | pass (6) |
| `dart test packages/agentkit_webmcp` | pass (2) |
| `dart test mcp_server_dart test/host_test.dart test/agent_registry_host_test.dart` | pass (15) |
| `dart analyze mcp_server_dart` | pass (errors cleared; info-level lints only) |

## Delivered

| Item | Evidence |
|------|----------|
| `McpHost.registerResource` / `registerPublishedResource` | `host.dart` → `McpPublishAdapter.publishCapabilityResource` |
| MCP resource hot-sync | `McpPublishAdapter` listens to `AgentRegistryEvent` |
| Flutter Inspector `visual://` via registry | `flutter_inspector.dart` → `registerPublishedResource` |
| Dynamic resources as `RegisteredAgentIntent` | `dynamic_registry.dart` `_intentForResource` + `forwardResourceRead` |
| Dynamic resource sync to `agentRegistry` | `dynamic_registry_integration.dart` |
| WebMCP tool hot-sync | `WebMcpPublishAdapter` registry event subscription |
| Resource mapper round-trip | `mcp_resource_mapper.dart` + tests |

## Deferred (unchanged)

- Standalone agentkit monorepo extract
- Public shim removal
- Gemma / `flutter_gemma` product wiring
- Resource templates still on `addResourceTemplate` (not registry-backed)

## Handoff

Merge `feat/agentkit-phase1-3` when ready; run full `mcp_server_dart` test suite in CI before release.
