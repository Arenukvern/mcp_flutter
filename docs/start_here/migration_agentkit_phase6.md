# Agentkit Phase 6 — MCPCallEntry → AgentCallEntry migration

Phase 6 removes the dual authoring path. **Phase 6b** deletes `MCPCallEntry` from
`mcp_toolkit`; **Phase 6f** adds operator tools so you can migrate app code ahead of
that hard cut.

## TL;DR

```bash
# Preview changes (exit 1 if anything would change)
flutter-mcp-toolkit migrate agent-entries --check lib/

# Apply in place
flutter-mcp-toolkit migrate agent-entries --write lib/main.dart
```

Alias: `migrate mcp-call-entry` (same flags).

## What changes

| Before (MCPCallEntry) | After (AgentCallEntry) |
| --------------------- | ---------------------- |
| `MCPCallEntry.tool(definition: MCPToolDefinition(...), handler: …)` | `AgentCallEntry.tool(namespace:, name:, description:, inputSchema:, handler: …)` |
| `MCPCallEntry.resource(definition: MCPResourceDefinition(...), handler: …)` | `AgentCallEntry.resource(...)` |
| `Set<MCPCallEntry>` | `Set<AgentCallEntry>` |
| Handler returns `MCPCallResult` | Handler returns `AgentResult.success(...)` (migrator wraps legacy handlers) |
| `import 'package:mcp_toolkit/mcp_toolkit.dart';` only | Adds `agentkit_core` + `agentkit_schema` imports when needed |

Default namespace: `app` (override with `--namespace my_ns`).

## CLI reference

```text
flutter-mcp-toolkit migrate agent-entries [--check] [--write] [--namespace app] <path>

  path    Dart file or directory (recursive for directories)
  --check Report files that would change; exit 1 if any pending
  --write Apply migrations in place (mutually exclusive with --check)
```

Examples:

```bash
flutter-mcp-toolkit migrate agent-entries --check .
flutter-mcp-toolkit migrate agent-entries --write lib/custom_tools.dart
flutter-mcp-toolkit migrate agent-entries --write --namespace my_app lib/
```

## Limitations (manual follow-up)

The migrator is **text-based**, not a full analyzer rewrite:

1. **Extension types** — `extension type Foo._(MCPCallEntry entry) implements MCPCallEntry`
   are retargeted to `AgentCallEntry`, but you should review namespace and handler bodies.
2. **`inputSchema`** — `ObjectSchema(...)` from `dart_mcp` becomes a placeholder empty
   object schema. Copy constraints from the old definition manually.
3. **Complex handlers** — block bodies with multiple returns may need hand-editing to
   return `AgentResult` directly instead of the adapter wrapper.
4. **Bootstrap APIs** — `addMcpTool`, `MCPToolkitBinding.addEntries`, and
   `agent_client_install` accept **`AgentCallEntry` only** (Phase 6b hard cut).

## MCP tool (TODO)

`fmt_migrate_agent_entries` — report-only migration over host paths (`files[]` or
`projectRoot`), optional `apply: true`. Planned for a follow-up slice; use the CLI
for now.

## Related docs

- [Phase 6 spec](../superpowers/specs/2026-05-26-agentkit-pre-extract-completion-design.md)
- [Phase 6 plan](../superpowers/plans/2026-05-26-agentkit-phase6-pre-extract.md)
- [v2 → v3 migration](./migration_v2_to_v3.mdx) — server-side `fmt_` prefix (unchanged)

## Validation

```bash
cd mcp_server_dart && dart test test/migrate_agent_entries_test.dart
flutter-mcp-toolkit migrate agent-entries --check path/to/your_app/lib
```

After Phase 6b lands, `MCPCallEntry` and the bridge are removed; this CLI remains
for any straggler repos until the major `mcp_toolkit` release is fully adopted.
