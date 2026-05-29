---
name: flutter-mcp-toolkit-intentcall-migration
description: >-
  Migrate Flutter app code from removed MCPCallEntry to AgentCallEntry after
  intentcall Phase 6b. Use when upgrading mcp_toolkit, fixing compile errors after
  a major bump, or running flutter-mcp-toolkit migrate agent-entries.
---

<!-- @FMT_MODE_PRELUDE -->

# intentcall migration — MCPCallEntry → AgentCallEntry

**Phase 6b hard cut:** `MCPCallEntry` is **removed** from `mcp_toolkit`. App code must use
`AgentCallEntry` (from `intentcall_core`, re-exported by `mcp_toolkit`).

Canonical doc: [migration_intentcall_phase6.md](https://github.com/Arenukvern/mcp_flutter/blob/main/docs/start_here/migration_intentcall_phase6.md)

## When to use this skill

- `dart analyze` reports undefined `MCPCallEntry` after pulling intentcall Phase 6
- User asks to migrate custom tools/resources to the new API
- Before shipping a major `mcp_toolkit` bump to consumers

## CLI (preferred)

```bash
# Preview (exit 1 if changes pending)
flutter-mcp-toolkit migrate agent-entries --check lib/

# Apply
flutter-mcp-toolkit migrate agent-entries --write lib/
flutter-mcp-toolkit migrate agent-entries --write --namespace my_app lib/main.dart
```

Alias: `migrate mcp-call-entry` (same behavior).

## After migration — registration

- `MCPToolkitBinding.addEntries(entries: Set<AgentCallEntry>)`
- `bootstrapFlutter(additionalEntries: { ... })`
- `addMcpTool(AgentCallEntry)` — still a shortcut for a single entry

Handlers should return **`AgentResult`** (`AgentResult.success` / `AgentResult.failure`).
For legacy `MCPCallResult` + `MCPToolDefinition` handlers, use **`mcpToolkitTool`** /
**`mcpToolkitResource`** (see `flutter-mcp-toolkit-custom-tools`).

## Legacy pattern (before — do not ship new code)

```dart
// BEFORE (removed in Phase 6b)
final tool = MCPCallEntry.tool(
  handler: (request) async => MCPCallResult(
    message: 'ok',
    parameters: {'n': request['n']},
  ),
  definition: MCPToolDefinition(
    name: 'my_tool',
    description: 'Example',
    inputSchema: {'type': 'object', 'properties': {}},
  ),
);
```

## Target pattern (after)

```dart
import 'package:mcp_toolkit/mcp_toolkit.dart';

final tool = AgentCallEntry.tool(
  namespace: 'app',
  name: 'my_tool',
  description: 'Example',
  inputSchema: const {
    'type': 'object',
    'additionalProperties': false,
    'properties': {'n': {'type': 'string'}},
    'required': ['n'],
  },
  handler: (final args) async {
    final n = args['n']?.toString() ?? '';
    return AgentResult.success(
      message: 'ok',
      data: {'n': n},
    );
  },
);

await MCPToolkitBinding.instance.addEntries(entries: {tool});
```

## Platform sync (optional)

After tool surfaces compile:

```bash
flutter-mcp-toolkit codegen sync --platform web
flutter-mcp-toolkit codegen sync --platform android,ios,macos --check
```

See `docs/platform-notes/android-oem.md` for Xiaomi/Huawei (same shortcuts XML as AOSP).

## MCP migrate tool

`fmt_migrate_agent_entries` is **shipped** (report-only by default; `apply: true` to
rewrite). CLI equivalent: `flutter-mcp-toolkit migrate agent-entries`.

## Maintainer checklist (in-repo product gate)

1. `flutter-mcp-toolkit migrate agent-entries --check` on `flutter_test_app/lib`
2. `make sync-skills` after any `plugin/skills/` edit
3. `cd mcp_server_dart && dart test test/contract/`
4. Grep: no `MCPCallEntry` in skills except this file's BEFORE examples

## Phase 7 extract (external monorepo)

When intentcall publishes to pub.dev (see `decisions/0009-intentcall-extract.mdx`):

1. Replace `path: ../agentkit/packages/intentcall_*` (or hosted `^0.1.0` after publish) in `pubspec.yaml`.
2. Run `flutter pub get` and `migrate agent-entries --check` again.
3. CI: use `make check-intentcall-integration` in mcp_flutter; package matrix moves to intentcall repo.

Until then, all intentcall packages remain **in-repo** with `publish_to: none`.

## Related skills

- **`flutter-mcp-toolkit-custom-tools`** — authoring `AgentCallEntry` surfaces
- **`flutter-mcp-toolkit-repo-maintainer`** — CHANGELOG, version pins, `sync-skills`
