# agentkit_core

Transport-agnostic agent intent registry and runtime for Flutter MCP Toolkit.

## Authoring

| Style | Server | Client (`mcp_toolkit`) |
|-------|--------|------------------------|
| Hand-written | `ToolRegistration` / `ResourceRegistration` via capability kernel | `AgentCallEntry` + `AgentModuleFromEntries` |
| Codegen (optional) | `@AgentTool` (Phase 1 pilot) | Same annotations (optional) |

Authors define **descriptors + executors**; they do not implement a public `AgentIntent` interface. The registry stores `RegisteredAgentIntent` (descriptor + `execute`).

## Invoke path

```
MCP CallToolRequest → AgentRegistry.invoke → AgentResult → CallToolResult
```

MCP publish lives in `agentkit_mcp` (`McpPublishAdapter`). WebMCP and Gemma use parallel adapters on the same registry:

```dart
final runtime = AgentRuntime(
  registry: InMemoryAgentRegistry(),
  adapters: [
    McpPublishAdapter(publish: ..., unpublish: ...),
    WebMcpPublishAdapter(publish: ..., unpublish: ...),
    GemmaPublishAdapter(register: ..., unregister: ...),
  ],
);
await runtime.start();
```

## Client helpers

- `AgentResult.envelope` / `resourceEnvelope` (`agentkit_schema`)
- `AgentWireArgs` for string-key maps
- `AgentClientInstall.once` in `mcp_toolkit` for lazy registration

## Related packages

- `agentkit_schema` — results, validation, wire args
- `agentkit_mcp` — MCP bridge, publish adapter, resource mapper
- `agentkit_webmcp` — WebMCP `modelContext` publish adapter
- `agentkit_gemma` — on-device Gemma function-calling adapter
- `agentkit_apple` / `agentkit_android` — `agent_manifest.json` codegen
- `agentkit_testing` — registry contract helpers

See `docs/superpowers/specs/2026-05-25-agentkit-design.md`.
