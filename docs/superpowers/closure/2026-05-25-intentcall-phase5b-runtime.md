# intentcall Phase 5-B — Runtime consolidation

**Date:** 2026-05-26  
**Gate:** pass  
**Branch:** feat/intentcall-phase1-3

## Summary

Single MCP attach path via `McpHost` → `AgentRuntime` → `McpPublishAdapter`. Dynamic registry tools/resources register into `AgentRegistry` only; adapter hot-sync publishes MCP surface. Dual `registerTool` / `addResource` paths removed.

## Checklist

| Item | Status |
|------|--------|
| `McpHost` owns `AgentRuntime` with `McpPublishAdapter` | pass |
| `runtime.start()` on host init; `runtime.stop()` on dispose | pass |
| `publishCapabilityTool/Resource` registry-only (no direct MCP publish) | pass |
| Dynamic tool/resource single publish via registry events | pass |
| Connection policy wrapped in dynamic intent executors | pass |
| `app/errors/{count}` template documented exception | pass |
| `fmt_*` MCP names unchanged | pass |
| No `intentcall_gemma` / repo split changes | pass |

## Validation

| Command | Result |
|---------|--------|
| `dart test packages/intentcall_mcp` | 6 passed |
| `dart test packages/intentcall_core packages/intentcall_webmcp` | 5 passed |
| `dart test mcp_server_dart/test/host_test.dart test/agent_registry_host_test.dart test/host_extras_test.dart` | 18 passed |
| `dart test mcp_server_dart/test/capability_kernel_e2e_test.dart test/tool_surface_snapshot_test.dart` | 5 passed |

## GitNexus

Impact analysis unavailable — `mcp_flutter` not in indexed repos (vitamins_quiz_bot, ecsly, codemap only).

## Blockers for Phase 5-C

None. Optional follow-ups: parameterized resource template intent for `app/errors/{count}`; `@AgentTool` build_runner generator.
