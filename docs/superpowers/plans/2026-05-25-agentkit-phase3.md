# Agentkit Phase 3 Implementation Plan

> **Status:** Stub packages landed on `feat/agentkit-phase1-3`; full implementation after Phase 2 gate.

**Goal:** Split agentkit for external consumption; ship WebMCP and Gemma adapters; start native manifest codegen.

## Stub packages (this branch)

| Package | Status |
|---------|--------|
| `agentkit_webmcp` | `WebMcpAgentAdapter` interface stub |
| `agentkit_gemma` | `GemmaAgentAdapter` interface stub |
| `agentkit_apple` | codegen placeholder |
| `agentkit_android` | codegen placeholder |
| `agentkit_codegen` | `@AgentTool` / `@AgentParam` annotations |

## Remaining tasks

### Task 1: Repo split

- [ ] Extract `packages/agentkit_*` to standalone repo
- [ ] Path / version dependency from `mcp_flutter` consumer

### Task 2: WebMCP adapter

- [ ] Implement `WebMcpAgentAdapter.attach` — publish registry descriptors to WebMCP

### Task 3: Gemma adapter

- [ ] Map intents to on-device tool definitions for `flutter_gemma`

### Task 4: Native codegen

- [ ] `agentkit_apple` — App Intents manifest from descriptors
- [ ] `agentkit_android` — shortcuts / App Actions manifest

### Task 5: Deprecation shims

- [ ] Remove legacy MCP-only registration paths after window

---

## Key design decisions

- Stubs prove workspace layout before split
- All adapters share one `AgentRegistry` (multi-adapter design spec)
