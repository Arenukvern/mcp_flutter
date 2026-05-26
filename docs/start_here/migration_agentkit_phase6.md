# Agentkit Phase 6 — MCPCallEntry → AgentCallEntry migration

Phase 6 removed the dual authoring path. **`MCPCallEntry` is deleted** from
`mcp_toolkit`; use **`AgentCallEntry`** and the operator tools below for straggler repos.

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

## MCP tool

`fmt_migrate_agent_entries` — report-only by default (`projectRoot` required);
set `apply: true` to rewrite files on the host. CLI equivalent:
`flutter-mcp-toolkit migrate agent-entries`.

## Platform hooks (native + web)

One-time project setup (dogfood: [flutter_test_app/AGENTKIT_PLATFORM.md](../../flutter_test_app/AGENTKIT_PLATFORM.md)):

```bash
flutter-mcp-toolkit init agentkit-platform --project-dir path/to/flutter_app
flutter-mcp-toolkit codegen sync --platform web,android,ios,macos,linux,windows \
  --project-dir path/to/flutter_app
```

CI drift: add `--check` to both commands (also in `make check-contracts`).

## Related docs

- [Phase 6 spec](../superpowers/specs/2026-05-26-agentkit-pre-extract-completion-design.md)
- [What's next](../superpowers/WHATS_NEXT.md) — forward index
- [Phase 7 extract](../superpowers/plans/2026-05-27-agentkit-phase7-extract.md) — active extract work
- [Integration completion plan](../superpowers/plans/archive/2026-05-26-agentkit-integration-completion-next.md) — archived (complete 2026-05-27)
- [v2 → v3 migration](./migration_v2_to_v3.mdx) — server-side `fmt_` prefix (unchanged)

## Validation

```bash
cd mcp_server_dart && dart test test/migrate_agent_entries_test.dart
flutter-mcp-toolkit migrate agent-entries --check path/to/your_app/lib
flutter-mcp-toolkit init agentkit-platform --check --project-dir path/to/flutter_app
```
