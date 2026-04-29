# Tool Surface Inversion — Design

> **Status (post-v3.0.0):** the kernel + core capability shipped. T1, T2,
> T4, T6, T8, T9, T10 from the original sequencing landed. T3 / T5 / T7
> were live-edit shaped and were dropped along with the live-edit
> packages; this doc is now load-bearing only for the **post-v3.0
> re-integration of live-edit as a separate capability**.
>
> Trimmed 2026-04-29: implementation sequencing, spent test plans, and
> spent acceptance criteria removed. What survives is decisions and
> rationale that future capability authors will need.

## Why this shape (the design problem the kernel solved)

Pre-v3.0, the dependency graph was upside-down at the server boundary:

- `flutter_live_edit_toolkit` → `mcp_toolkit` was correct (app-side).
- `mcp_server_dart` → `flutter_live_edit_toolkit` was a leak: the
  server statically depended on Flutter, which it never renders. Source
  of the long-standing `uses-material-design` warnings.
- Every binary advertised live-edit's tool surface unconditionally; no
  way to compose a custom server with a different capability set.
- Tool names were flat across the MCP boundary — `tap_widget` from
  core and a hypothetical future `tap_widget` from another capability
  would collide silently.

## Goals (still applicable for future capabilities)

1. The server's static dep tree contains zero Flutter packages. ✅ shipped.
2. Each capability is its own Dart package, independently testable,
   independently composable.
3. `mcp_server_dart` and `flutter_mcp_cli` are thin shells. Their default
   `main.dart` registers the bundled capability set; power users write
   their own `main.dart` to compose a different set.
4. Tool names at the MCP boundary are prefixed by capability id
   (`core_tap_widget`, `live_edit_select`). The kernel enforces the
   prefix; capabilities cannot opt out or pre-prefix.
5. **Hard cuts at major versions.** No deprecation aliases, no soft
   errors. Reasoning: a capability rename is rare and a clean
   `tool_not_found` is easier to debug than a silent fallback.

## Non-goals (still applicable)

- A plugin-discovery mechanism — capabilities register at compile time;
  no dynamic loading.
- Cross-process or remote capabilities.
- Per-capability versioning beyond what `version` field surfaces in
  `doctor`.

## Architecture (as shipped — ground truth lives in
`mcp_capability_kernel/`)

The interfaces below are the contract every capability must satisfy.
Authoritative source is `mcp_capability_kernel/lib/`; the snippets here
are illustrative for design conversations.

### `Capability`

```dart
abstract interface class Capability {
  /// Stable id for the tool-name prefix (`<id>_<tool>`).
  /// Must match ^[a-z][a-z0-9_]*$. Examples: 'core', 'live_edit'.
  /// Reserved: 'app' (unscoped dynamic registrations).
  String get id;
  String get description;
  String get version;

  Future<void> register(CapabilityContext context);
  Future<void> dispose();
}
```

### `CapabilityContext`

```dart
abstract interface class CapabilityContext {
  CapabilityConfig get config;
  void registerTool(ToolRegistration registration);
  void registerResource(ResourceRegistration registration);
  T require<T extends HostService>();
}
```

The kernel applies the `<capability.id>_` prefix at registration.
Capabilities pass bare names; the kernel composes the public name. A
capability that pre-prefixes its name throws `PrePrefixedToolNameError`.

### `HostService` family

Defined as interfaces in the kernel; implemented by the server. Today
only `CommandRunner` is in production use (binds the executor for
shared-core commands). Designed to grow:

```dart
abstract interface class HostService {}
abstract interface class CommandRunner implements HostService { ... }
// Future: VmServiceClient, HotReloadCoordinator, DynamicRegistryBridge.
```

### Prefix enforcement (rules, all at registration)

- Capability id must match `^[a-z][a-z0-9_]*$`. Otherwise throws.
- Capability id is not reserved (`app` is reserved for unscoped dynamic
  registrations).
- Tool name passed to `registerTool` must not start with the capability's
  prefix already (no double-prefixing).
- Two static registrations of the same final prefixed name: fatal at
  host startup. Trivially unreachable when ids are unique.
- A dynamic entry arriving at the bridge with a name that collides with
  a static registration: rejected at the bridge with a structured error.

## Live-edit re-integration plan (post-v3.0)

When live-edit lands as a separate capability, the command split below is
the planned classification. Verified against the v2 source before
excision; classification may shift ±1 commands when bodies are re-read.

| Command                           | Side    | Why                                   |
|-----------------------------------|---------|---------------------------------------|
| `LiveEditStartSession`            | server  | hot-reload coordination, agent setup  |
| `LiveEditPrepareSession`          | server  | hot reload + VM service prep          |
| `LiveEditSetOverlay`              | app     | pure app-state mutation               |
| `LiveEditGetTree`                 | app     | pure app-state read                   |
| `LiveEditSelectAtPoint`           | app     | pure app-state mutation               |
| `LiveEditGetSelection`            | app     | pure app-state read                   |
| `LiveEditGetCapabilities`         | app     | pure app-state read                   |
| `LiveEditGetSelectionCandidates`  | app     | pure app-state read                   |
| `LiveEditSetActiveSelection`      | app     | pure app-state mutation               |
| `LiveEditGetPropertyPanel`        | app     | pure app-state read                   |

Server-side commands need the server because of hot-reload coordination
through VM service and agent orchestration (Codex/Cursor SDK calls).
Everything else lives where the data lives — in the running Flutter app.

The `live_edit_models` extraction (originally T3) is a prerequisite to
re-integration: the package has to be reborn before
`mcp_capability_live_edit` can re-import it.

## Open questions resolved during brainstorming (do not relitigate)

- **Composition unit:** per-capability Dart packages.
- **Naming scheme:** underscore prefix `<capability>_<tool>`.
- **Prefix enforcement:** kernel-only, no per-capability override.
- **Dynamic registry:** stays in server as host machinery, exposed via
  `DynamicRegistryBridge` interface in the kernel (not yet implemented;
  planned alongside live-edit re-integration).
- **Dynamic-path namespacing:** server-side via capability claim.
- **Live-edit command split:** ~2 server-side, ~8 app-side dynamic
  (table above).
- **Cut line:** all in v3.0.0, hard cut, no migration aliases. ✅ shipped.

## Out-of-scope follow-ups (optional v3.x)

- Capability-level configuration via config file (today: CLI flags only).
- A `flutter_mcp_cli capabilities list` subcommand.
- Loading capabilities at runtime (today: compile-time composition only).
