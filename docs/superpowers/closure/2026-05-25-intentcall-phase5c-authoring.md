# intentcall Phase 5-C closure — Authoring & optional codegen

**Date:** 2026-05-26  
**Branch:** `feat/intentcall-phase1-3`  
**Spec:** [2026-05-25-intentcall-phase5-hardening-design.md](../specs/2026-05-25-intentcall-phase5-hardening-design.md) Section C

## Delivered

| Goal | Status | Notes |
|------|--------|-------|
| `intentcall_codegen` build_runner pilot | **done** | `AgentToolGenerator`, `build.yaml`, `build_test` coverage |
| `AgentCallEntry` bridge in `mcp_toolkit` | **done** | `@Deprecated` on `MCPCallEntry`; `MCPCallEntryAgentBridge.toAgentCallEntry()` |
| Hand-written example | **done** | `mcp_toolkit/example/agent_call_entry_starter.dart` |
| Generated tool fixture | **done** | `packages/intentcall_codegen/test/fixtures/demo_ping_tool.dart` |
| Apple/Android manifest docs | **done** | README author workflows (~10 lines + snippets) |

## Validation

```bash
dart test packages/intentcall_codegen
dart test packages/intentcall_core
dart analyze packages/intentcall_codegen packages/intentcall_apple packages/intentcall_android
```

## Deferred (explicit)

- Mass migration of `MCPCallEntry` call sites across repo
- Server capability `@AgentTool` codegen in `server_capability_core`
- Resource-kind codegen; optional/required param expansion beyond pilot types
- Swift/XML emitters (manifest JSON + documented mapping only)
- `flutter_gemma` product wiring

## Gate

Phase 5-C exit criteria met for in-repo milestone. Tracker: `phase5.sub_phases.5c` → done; `program.status` → `complete_milestone` with codegen note in deferred_work trimmed.
