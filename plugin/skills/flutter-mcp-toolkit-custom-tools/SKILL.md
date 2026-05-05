---
name: flutter-mcp-toolkit-custom-tools
description: Use this skill when the agent exposes app-specific surfaces by registering custom MCP tools and resources inside the Flutter app (mcp_toolkit dynamic registry — MCPCallEntry, bootstrapFlutter additionalEntries / addEntries). Covers tool vs resource vs evaluate-expression, Map-based handlers, schema strictness, discovery via fmt_list_client_tools_and_resources, fmt_client_tool, fmt_client_resource, and lifecycle pitfalls.
---

<!-- @FMT_MODE_PRELUDE -->

# Custom MCP Toolkit Tools & Resources (Dynamic Registry)

Use this when bundled MCP tools (screenshot, semantic snapshot, tap, …) are not enough and you need **app-specific** read surfaces or actions — e.g. cart totals, feature flags, curated debug snapshots of internal state. Entries are registered **in the Flutter process** and exposed to the agent through the **dynamic registry**.

## Pick the right primitive

| Need | Use |
|------|-----|
| One-off read of a simple value | **`fmt_evaluate_dart_expression`** (no app code change). |
| Stable **read-only** payload (diagnostics, JSON snapshot, “current route”) | **`MCPCallEntry.resource`** + **`fmt_client_resource`**. Prefer resources when the contract is “GET-like” and idempotent. |
| Parameterized or mutating action, or reusable named operation | **`MCPCallEntry.tool`** + **`fmt_client_tool`**. |

## Handler signature (tools and resources)

[`MCPCallHandler`](https://github.com/Arenukvern/mcp_flutter/blob/main/mcp_toolkit/lib/src/mcp_models.dart) is `FutureOr<MCPCallResult> Function(ServiceExtensionRequestMap request)` where **`ServiceExtensionRequestMap` is `Map<String, String>`**.

- Tool arguments arrive as **string values** keyed by schema property names — mirror the README pattern: `request['n']`, `request['userId']`, then parse (`int.tryParse`, `double.tryParse`, `jsonDecode` for nested blobs if the wire format sends JSON-as-string).
- Do **not** use `request.arguments` — that is not the app-side API.

## Minimal tool registration

```dart
import 'package:mcp_toolkit/mcp_toolkit.dart';

final tool = MCPCallEntry.tool(
  handler: (request) async {
    final userId = request['userId'] ?? '';
    final cart = CartRepository.instance.forUser(userId);
    return MCPCallResult(
      message: 'ok',
      parameters: {
        'total': cart.total,
        'items': cart.items.map((i) => i.toJson()).toList(),
      },
    );
  },
  definition: MCPToolDefinition(
    name: 'cart_get_snapshot',
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

Prefer **`MCPToolkitBinding.instance.bootstrapFlutter(additionalEntries: { ... }, runApp: ...)`** so tools/resources register in one place with zone/error setup — same entries shape as above.

Register **after** `initialize()` / **`bootstrapFlutter`** wiring, **once** at bootstrap — not inside `build`, not per-widget `initState`.

## Custom resources

Resources are for **read-only** MCP surfaces: diagnostics, config summaries, or JSON blobs the agent polls without treating them as imperative actions.

```dart
MCPCallEntry.resource(
  definition: MCPResourceDefinition(
    name: 'app_cart_digest',
    description: 'Compact cart summary for agents (read-only).',
    mimeType: 'application/json',
  ),
  handler: (request) async => MCPCallResult(
    message: 'Cart digest',
    parameters: {
      'itemCount': CartRepository.instance.visibleCount,
      'currency': CartRepository.instance.currencyCode,
    },
  ),
),
```

- **`name`** must be `snake_case` (letters, digits, underscores). [`resourceUri`](https://github.com/Arenukvern/mcp_flutter/blob/main/mcp_toolkit/lib/src/mcp_models.dart) maps it to a **`visual://localhost/...`** URI (underscore segments become path segments). Agents consume it via **`fmt_client_resource`** using that URI / listing from **`fmt_list_client_tools_and_resources`**.
- Set **`mimeType`** honestly (`application/json` vs `text/plain`) so clients know how to interpret payloads.

## Schema rules (tools)

The MCP server enforces strict JSON Schema:

- Prefer **`additionalProperties: false`** unless you intentionally accept arbitrary keys. Unknown keys **fail validation** — good for catching agent typos.
- Mark **`required`** for anything the handler reads unconditionally.
- Prefer primitives and **`enum`** over unconstrained strings.
- **`parameters`** in **`MCPCallResult`** must be JSON-serializable; non-serializable objects degrade to **`toString()`**.

## Discovery from the agent side

1. **`fmt_list_client_tools_and_resources`** — enumerate app-registered tools and resources.
2. **`fmt_client_tool`** — invoke a tool by name with JSON args (CLI: `flutter-mcp-toolkit exec --name fmt_client_tool --args '...'` per your transport).
3. **`fmt_client_resource`** — fetch a registered resource (URI from listing / `resourceUri` convention).

If something should appear but does not: confirm **`addEntries`** completed (**`await`**), then hot **restart** — reload does not always replay discovery cleanly.

## Lifecycle gotchas

- **Hot reload** + **`addEntries`** from widget code → duplicate registrations. Register once in **`main()` / bootstrap**, not in **`build`**.
- **Hot restart** clears VM state; registrations tied to **`bootstrapFlutter`** / **`main`** run again on boot — correct pattern survives restart.
- **Debug mode only** — release builds do not expose these VM service extensions.
- **Naming**: flat global namespace per app — prefix tools/resources (`cart_`, `flags_`, `nav_`) to avoid collisions with builtins or other domains.

## When the agent authors surfaces for the user’s app

1. Ensure **`mcp_toolkit`** is in **`pubspec.yaml`**.
2. Add **`lib/mcp_tools/<domain>_surfaces.dart`** exporting **`registerXSurfaces()`** that returns **`Set<MCPCallEntry>`** or performs **`addEntries`** once.
3. Wire **`registerXSurfaces()`** from **`bootstrapFlutter(..., additionalEntries: ...)`** or call **`addEntries`** immediately after **`initializeFlutterToolkit`** inside **`bootstrapFlutter`**’s chain — **never** from **`StatefulWidget` lifecycle**.
4. Tight schemas (**`additionalProperties: false`**, explicit **`required`**).
5. Hot **restart**, then **`fmt_list_client_tools_and_resources`** before first **`fmt_client_tool`** / **`fmt_client_resource`** call.

## Safety and scope

- Treat handlers as **powerful debug hooks**: avoid exposing secrets, full databases, or unchecked filesystem/network IO.
- Keep handlers thin: delegate to domain/services already used by the app (same DI/getters), **don’t** duplicate business logic in MCP-only paths unless intentional.

## Common traps

- **`request.arguments`** — wrong shape; use **`request['key']`** on **`Map<String, String>`**.
- Missing **`await`** on **`addEntries`** → race before discovery lists your surface.
- Returning **`Future`** instances inside **`parameters`** → useless serialization; **`await`** inside the handler.
- **`inputSchema`** out of sync with the handler → agents trust the schema; update both.

## Related

- Driving the live app (snapshot / tap / reload): **`flutter-mcp-toolkit-guide`** → **`flutter-mcp-toolkit-inspect`** / **`flutter-mcp-toolkit-control`**.
- Repository **`ARCHITECTURE.md`** → “Dynamic Registry Architecture”.
