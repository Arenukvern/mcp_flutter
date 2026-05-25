# agentkit_core

Transport-agnostic agent intent registry and runtime for Flutter MCP Toolkit.

## Authoring

| Style | Server | Client (`mcp_toolkit`) |
|-------|--------|------------------------|
| Hand-written | `ToolRegistration` via capability kernel | `AgentCallEntry` + `AgentModuleFromEntries` |
| Codegen (optional) | `@AgentTool` (Phase 1 pilot) | Same annotations (optional) |

Authors define **descriptors + executors**; they do not implement a public `AgentIntent` interface. The registry stores `RegisteredAgentIntent` (descriptor + `execute`).

## Invoke path

```
MCP CallToolRequest → AgentRegistry.invoke → AgentResult → CallToolResult
```

MCP publish lives in `agentkit_mcp` (`McpPublishAdapter`).

## Client helpers

- `AgentResult.envelope` / `resourceEnvelope` (`agentkit_schema`)
- `AgentWireArgs` for string-key maps
- `AgentClientInstall.once` in `mcp_toolkit` for lazy registration

## Related packages

- `agentkit_schema` — results, validation, wire args
- `agentkit_mcp` — MCP bridge and publish adapter
- `agentkit_testing` — registry contract helpers

See `docs/superpowers/specs/2026-05-25-agentkit-design.md`.
