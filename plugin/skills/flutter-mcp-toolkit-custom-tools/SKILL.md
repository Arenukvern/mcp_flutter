---
name: flutter-mcp-toolkit-custom-tools
description: Use this skill when the agent exposes app-specific surfaces by registering custom MCP tools and resources inside the Flutter app (mcp_toolkit dynamic registry — AgentCallEntry, bootstrapFlutter additionalEntries / addEntries). Covers tool vs resource vs evaluate-expression, Map-based handlers, schema strictness, discovery via fmt_list_client_tools_and_resources, fmt_client_tool, fmt_client_resource, and lifecycle pitfalls.
---

<!-- @FMT_MODE_PRELUDE -->

# Custom MCP Toolkit Tools & Resources (Dynamic Registry)

Use this when bundled MCP tools (screenshot, semantic snapshot, tap, …) are not enough and you need **app-specific** read surfaces or actions — e.g. cart totals, feature flags, curated debug snapshots of internal state. Entries are registered **in the Flutter process** and exposed to the agent through the **dynamic registry**.

> **Migration:** The legacy call-entry type was removed in intentcall Phase 6b. Use **`AgentCallEntry`** or **`mcpToolkitTool` / `mcpToolkitResource`**. See **`flutter-mcp-toolkit-intentcall-migration`**.

## Pick the right primitive

| Need | Use |
|------|-----|
| One-off read of a simple value | **`fmt_evaluate_dart_expression`** (no app code change). |
| Stable **read-only** payload (diagnostics, JSON snapshot, “current route”) | **`AgentCallEntry.resource`** + **`fmt_client_resource`**. Prefer resources when the contract is “GET-like” and idempotent. |
| Parameterized or mutating action, or reusable named operation | **`AgentCallEntry.tool`** + **`fmt_client_tool`**. |

## Handler signatures

### Native `AgentCallEntry` (preferred for new code)

Handlers receive **`AgentArguments`** (`Map<String, Object?>`) and return **`AgentResult`**:

```dart
import 'package:mcp_toolkit/mcp_toolkit.dart';

final tool = AgentCallEntry.tool(
  namespace: 'app',
  name: 'cart_get_snapshot',
  description: 'Return current cart total and items for a user.',
  inputSchema: const {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'userId': {'type': 'string'},
    },
    'required': ['userId'],
  },
  handler: (final args) async {
    final userId = args['userId']?.toString() ?? '';
    final cart = CartRepository.instance.forUser(userId);
    return AgentResult.success(
      message: 'ok',
      data: {
        'total': cart.total,
        'items': cart.items.map((final i) => i.toJson()).toList(),
      },
    );
  },
);

await MCPToolkitBinding.instance.addEntries(entries: {tool});
```

### Legacy `MCPToolDefinition` + `MCPCallResult` (bridge)

Built-in toolkits still use **`mcpToolkitTool`** / **`mcpToolkitResource`** to adapt
`Map<String, String>` service-extension handlers:

```dart
final tool = mcpToolkitTool(
  namespace: 'app',
  handler: (final request) async {
    final userId = request['userId'] ?? '';
    return MCPCallResult(
      message: 'ok',
      parameters: {'userId': userId},
    );
  },
  definition: MCPToolDefinition(
    name: 'cart_get_snapshot',
    description: 'Return current cart total and items for a user.',
    inputSchema: ObjectSchema(
      properties: {
        'userId': StringSchema(),
      },
      required: ['userId'],
    ),
  ),
);
```

- Tool arguments on the wire are **strings** keyed by schema property names — parse with `int.tryParse`, `jsonDecode`, etc.
- Do **not** use `request.arguments` on the app side.

Prefer **`MCPToolkitBinding.instance.bootstrapFlutter(additionalEntries: { ... }, runApp: ...)`** so tools/resources register in one place with zone/error setup.

Register **once** at bootstrap — not inside `build`, not per-widget `initState`.

## Custom resources

```dart
final resource = AgentCallEntry.resource(
  namespace: 'app',
  name: 'app_cart_digest',
  description: 'Compact cart summary for agents (read-only).',
  mimeType: 'application/json',
  handler: (final args) async => AgentResult.success(
    message: 'Cart digest',
    data: {
      'itemCount': CartRepository.instance.visibleCount,
      'currency': CartRepository.instance.currencyCode,
    },
  ),
);
```

Or via bridge:

```dart
mcpToolkitResource(
  namespace: 'app',
  definition: MCPResourceDefinition(
    name: 'app_cart_digest',
    description: 'Compact cart summary for agents (read-only).',
    mimeType: 'application/json',
  ),
  handler: (final request) async => MCPCallResult(
    message: 'Cart digest',
    parameters: {'itemCount': 3},
  ),
),
```

- **`name`** must be `snake_case`. Published resource URIs follow **`visual://localhost/...`** conventions; agents use **`fmt_client_resource`** and listings from **`fmt_list_client_tools_and_resources`**.

## Schema rules (tools)

The MCP server enforces strict JSON Schema:

- Prefer **`additionalProperties: false`** unless you intentionally accept arbitrary keys.
- Mark **`required`** for anything the handler reads unconditionally.
- **`AgentResult.data`** / **`MCPCallResult.parameters`** must be JSON-serializable.

## Discovery from the agent side

1. **`fmt_list_client_tools_and_resources`** — enumerate app-registered tools and resources.
2. **`fmt_client_tool`** — invoke a dynamic tool by name with JSON args.
3. **`fmt_client_resource`** — fetch a registered resource URI from the listing.

If something should appear but does not: confirm **`addEntries`** completed (**`await`**), then hot **restart**.

## Lifecycle gotchas

- **Hot reload** + **`addEntries`** from widget code → duplicate registrations. Register once in **`main()` / bootstrap**.
- **Debug mode only** — release builds do not expose VM service extensions.
- **Naming**: flat global namespace per app — prefix tools/resources (`cart_`, `flags_`, `nav_`).

## When the agent authors surfaces for the user’s app

1. Ensure **`mcp_toolkit`** is in **`pubspec.yaml`**.
2. Add **`lib/mcp_tools/<domain>_surfaces.dart`** returning **`Set<AgentCallEntry>`** or calling **`addEntries`** once.
3. Wire from **`bootstrapFlutter(..., additionalEntries: ...)`** — never from **`StatefulWidget` lifecycle**.
4. Tight schemas; hot **restart**; then **`fmt_list_client_tools_and_resources`** before first client invoke.

## Safety and scope

- Treat handlers as **powerful debug hooks**: avoid secrets, unchecked IO.
- Keep handlers thin: delegate to existing app services.

## Common traps

- Mixing **`AgentArguments`** with **`Map<String, String>`** — pick one API (native vs `mcpToolkitTool`).
- Missing **`await`** on **`addEntries`** → race before discovery.
- **`inputSchema`** out of sync with the handler → agents trust the schema; update both.

## Related

- **`flutter-mcp-toolkit-intentcall-migration`** — CLI migrator, breaking upgrade
- **`flutter-mcp-toolkit-guide`** → inspect / control / debug skills
- Repository **`ARCHITECTURE.md`** → “Dynamic Registry Architecture”
