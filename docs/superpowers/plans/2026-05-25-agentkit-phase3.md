# Agentkit Phase 3 Implementation Plan

> **Status:** Done (in-repo milestone, 2026-05-25). Closure: `docs/superpowers/closure/2026-05-25-agentkit-phase3.md`

**Goal:** Multi-adapter shipping, transport-free kernel resources, native manifest codegen starters.

---

## Completed

- [x] `ResourceRegistration` → `ResourceHandler` returns `AgentResult` (kernel has zero `dart_mcp`)
- [x] `agentkit_mcp` — `resourceRegistrationToRegistration`, `mcp_resource_mapper.dart`
- [x] `agentkit_webmcp` — `WebMcpPublishAdapter` (publish/unpublish callbacks)
- [x] `agentkit_gemma` — `GemmaPublishAdapter` (register/unregister callbacks)
- [x] `agentkit_apple` — `generateAppleAgentManifest`
- [x] `agentkit_android` — `generateAndroidAgentManifest`
- [x] Tests for all new packages

## Deferred

- [ ] Extract agentkit to standalone monorepo + pub publish
- [ ] Wire `flutter_gemma` package dependency in consumer app
- [ ] Host `McpHost.registerResource` via registry + MCP resource adapter
- [ ] Remove legacy public shims after deprecation window
- [ ] Swift/Kotlin codegen from manifest (beyond JSON generator)

---

## Key design decisions

- WebMCP/Gemma adapters use injectable callbacks (testable without browser/Gemma SDK)
- Native codegen emits `agent_manifest.json`; platform compilers are separate step
- Repo split deferred to avoid breaking mcp_flutter CI mid-rollout
