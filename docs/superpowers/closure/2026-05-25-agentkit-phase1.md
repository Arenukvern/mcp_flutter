# Agentkit Phase 1 — Closure Report

**Date:** 2026-05-25  
**Verdict:** pass (with noted deferrals)  
**Branch:** `feat/agentkit-phase1-3`

## Validation

| Command | Result |
|---------|--------|
| `dart test packages/agentkit_schema` | pass (4) |
| `dart test packages/agentkit_core` | pass (3) |
| `dart test packages/agentkit_mcp` | pass (1) |
| `dart test packages/server_capability_kernel` | pass (25) |
| `dart test mcp_server_dart` (subset: host, registry, e2e, snapshot, core_executor) | pass (30); contract test not re-run |

## Spec coverage

| Requirement | Status | Evidence |
|-------------|--------|----------|
| `agentkit_schema` | pass | `packages/agentkit_schema/` |
| `agentkit_core` registry/runtime | pass | `InMemoryAgentRegistry`, `AgentRuntime` |
| Hand-written `AgentCallEntry` | pass | `agent_call_entry.dart`, tests |
| Optional codegen | partial (by design) | `agentkit_codegen` **annotations-only**; no `build_runner` generator until Phase 5-C |
| Bridge `ToolRegistration` | pass | `agentkit_mcp/lib/src/agent_bridge.dart` |
| MCP invoke via registry | pass | `host.dart`, `agent_registry_host_test.dart` |
| `fmt_*` prefix preserved | pass | existing `applyPrefix` |
| Client DX (ecsly) | pass | envelope, `AgentWireArgs`, `AgentClientInstall.once` |
| Multi-adapter runtime | partial | `AgentAdapter` in core; WebMCP/Gemma adapters shipped in Phase 3 (Gemma example-only) |
| `agentkit_mcp` extract | partial | shipped early on this branch (Phase 2 overlap) |

## Deferrals (acceptable for Phase 1)

- Full `@AgentTool` build_runner generator
- `flutter_test_app/lib/agent_tools/` example
- `flutter_mcp_toolkit_contract_test.dart` full green (not blocking registry path)
- Kernel `dart_mcp` removal → Phase 2 Task 1
- `DynamicRegistry` intent storage → Phase 2 Task 2

## Handoff

- **Active phase:** phase2  
- **Plan:** `docs/superpowers/plans/2026-05-25-agentkit-phase2.md`  
- **Implementer:** complete Phase 2 remaining tasks; Phase 3 ships webmcp/gemma/apple/android packages (adapters + manifest codegen starters)
