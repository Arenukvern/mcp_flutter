---
name: custom-toolkit-tools
description: Use this skill when the agent needs to expose app-specific functionality to itself by registering custom MCP tools from inside the Flutter app via mcp_toolkit's dynamic registry (MCPCallEntry / addEntries). Covers schema design, registration timing, hot-reload behavior, and surfacing via listClientToolsAndResources / runClientTool.
---

# Custom MCP Toolkit Tools (Dynamic Registry)

Use this skill when a generic MCP tool (screenshot, snapshot, tap) is not enough and you need app-specific introspection or actions — e.g. "give me the current cart total", "force the feature flag X", "dump the Riverpod graph for provider Y". These are registered **inside the Flutter app** at runtime and surface to the agent via the dynamic registry.

## When to register a custom tool (vs. `evaluate_dart_expression`)

- **Prefer `evaluate_dart_expression`** for one-off reads of plain values. No app change required.
- **Register a custom tool** when the operation is:
  - Reused across sessions (worth a stable `name` + schema).
  - Too complex to express as a single expression (needs assembly, async, multiple calls).
  - Destructive or parameterized and deserves a typed schema so the agent can't pass garbage.
  - Something the user will run repeatedly — turning it into a tool is cheaper than re-prompting.

## Minimal registration

```dart
import 'package:mcp_toolkit/mcp_toolkit.dart';

final tool = MCPCallEntry.tool(
  handler: (request) {
    final userId = request.arguments['userId'] as String;
    final cart = CartRepository.instance.for(userId);
    return MCPCallResult(
      message: 'ok',
      parameters: {
        'total': cart.total,
        'items': cart.items.map((i) => i.toJson()).toList(),
      },
    );
  },
  definition: MCPToolDefinition(
    name: 'get_cart_snapshot',
    description: 'Return current cart total and items for a user.',
    inputSchema: {
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        'userId': {'type': 'string'},
      },
      'required': ['userId'],
    },
  ),
);

await MCPToolkitBinding.instance.addEntries(entries: {tool});
```

Register **after** `MCPToolkitBinding.instance..initialize()..initializeFlutterToolkit();` and **before** or during `runApp`. Registering inside build methods re-registers on every rebuild — don't.

## Schema rules (important)

The server enforces strict schemas. Mirror its defaults in your tool:

- Set `additionalProperties: false` unless you genuinely want open inputs. Unknown params **reject**, which is usually what you want — it catches agent typos early.
- Use `required` for anything the handler will dereference unconditionally.
- Prefer primitive types and enums (`"enum": [...]`) over free-form strings.
- Return `parameters` as a JSON-serializable map; the server does not deep-inspect — non-serializable values silently flatten to `toString()`.

## Tool discovery from the agent side

1. `listClientToolsAndResources` — enumerates what the running app has registered.
2. `runClientTool --name <name> --args '<json>'` — invoke it.
3. If a tool is expected but missing: check that `addEntries` ran (log it), then hot **restart** — reload does not always re-emit DTD registration events.

## Lifecycle gotchas

- **Hot reload clears nothing but may double-register** if you call `addEntries` from a widget lifecycle. Register once, at app bootstrap.
- **Hot restart** clears the registry — tools must re-register on next boot (they will, if bootstrap does it).
- **Debug mode only**. Release builds do not expose VM service extensions; the registry is inert.
- **Naming**: tool names are flat and global within the app. Prefix with a domain (`cart_`, `flags_`, `perf_`) to avoid collisions.

## When the agent itself is authoring the tool

If you (the agent) are adding a tool to the user's app on their behalf:

1. Add the `mcp_toolkit` dep if missing.
2. Put the registration in a dedicated file (e.g. `lib/mcp_tools/<domain>_tools.dart`) with one `registerXTools()` function called from bootstrap.
3. Write the schema tight (`additionalProperties: false`, explicit `required`).
4. After adding, do a hot **restart**, then `listClientToolsAndResources` to confirm the tool is live before you try to call it.
5. If the user is iterating, keep the handler pure where possible — easier to test with `evaluate_dart_expression` in parallel.

## Common traps

- Registering from `initState` of the root widget → fires again on hot reload, duplicate entries. Register in `main()` after `WidgetsFlutterBinding.ensureInitialized()`.
- Forgetting `await` on `addEntries` → agent queries before the DTD event fires → tool appears missing.
- Returning `Future` values in `parameters` without awaiting → serialized as `Instance of 'Future'`. Await inside the handler.
- Schema mismatch between docstring and `inputSchema` → the agent trusts the schema. Update both together.

## Related

- For driving a live app (snapshot/tap/reload), see the `flutter-mcp` skill.
- Architecture details: `ARCHITECTURE.md` → "Dynamic Registry Architecture".
