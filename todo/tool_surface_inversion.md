# Tool Surface Inversion — Design

**Status:** Design approved 2026-04-28 · **SCOPE REDUCED 2026-04-29 — live_edit deferred to post-v3.0.0**
**Target release:** v3.1.0 for live_edit portions; v3.0.0 ships without live_edit (see scope note below)
**Companion doc:** `todo/v3_release_audit_2026-04-28.md`

---

> **SCOPE CHANGE 2026-04-29**
>
> Live edit has been completely removed from the v3.0.0 release.
> `flutter_live_edit/` was deleted (commit `d0a11c9`) and all live_edit
> code was excised from `mcp_server_dart` (commit `2cea690`).
>
> **What this means for this design:**
> - T3 (`live_edit_models` extraction) — superseded; the package is deleted.
> - T5 (`mcp_capability_live_edit`) — deferred to post-v3.0.0.
> - T7 (`flutter_live_edit_toolkit` adoption) — deferred to post-v3.0.0.
> - The capability kernel (T1, T2) and `mcp_capability_core` (T4) remain in
>   scope for v3.0.0, but without any live_edit portions.
> - Acceptance criterion #4 (custom binary demo) and #5 (CHANGELOG rename table)
>   apply only to the core capability surface.
>
> The remainder of this document is preserved as the design for the eventual
> live_edit re-integration (post-v3.0.0).

---

## Problem

The current dependency graph has the wrong direction at the server boundary:

- ✅ `flutter_live_edit_toolkit` → `mcp_toolkit` (already correct, app-side)
- ❌ `mcp_server_dart` → `flutter_live_edit_toolkit` + `live_edit_tooling_ui_kit` (the leak)

Concretely:

- `mcp_server_dart/lib/src/capabilities/live_edit/` is hardcoded server-side glue for live-edit. The server pubspec depends on `flutter_live_edit_toolkit` and `live_edit_tooling_ui_kit`, dragging Flutter into a process that doesn't render anything. This is the source of the long-standing `uses-material-design` warnings (see `CLAUDE.md`, "v3.0 Gotchas").
- Every binary built from `mcp_server_dart` and `flutter_mcp_cli` advertises live-edit's tool surface unconditionally. There is no flag to turn it off and no way to compose a custom binary with a different capability set.
- Tool names are flat across the MCP boundary. `tap_widget` from core and a hypothetical future `tap_widget` from another capability would collide silently.

## Goals

1. The server's static dep tree contains zero Flutter packages.
2. Each capability (Playwright parity = "core"; live-edit; future capabilities) is its own Dart package, independently testable, independently composable.
3. `mcp_server_dart` and `flutter_mcp_cli` become thin shells. Their default `main.dart` registers the bundled capability set; power users write their own `main.dart` to compose a different set.
4. Tool names at the MCP boundary are prefixed by capability id (`core_tap_widget`, `live_edit_select`). The kernel enforces the prefix; capabilities cannot opt out or pre-prefix.
5. Hard cut at v3.0.0. No deprecation aliases, no soft errors. v2→v3 is already a chasm; one more breaking change is acceptable for a major version.

## Non-goals

- A plugin-discovery mechanism (capabilities register at compile time, no dynamic loading).
- Cross-process or remote capabilities.
- Backward compatibility for v2 tool names beyond what the standard `tool_not_found` error provides.
- Touching the selection state machine work in `todo/selection_state_machine.md` — orthogonal, app-side only.

## Architecture

### Package layout

```
                  ┌──────────────────────────────────┐
                  │  mcp_capability_kernel           │  ← shared contracts package
                  │  (Capability, ToolBundle,        │     - pure Dart, no Flutter
                  │   ResourceBundle, Registrar,     │     - no transport code
                  │   CapabilityContext)             │     - depends on dart_mcp only
                  └──────────────────────────────────┘
                           ▲           ▲           ▲
                           │           │           │
        ┌──────────────────┘           │           └────────────────────┐
        │                              │                                │
┌───────────────────────┐  ┌───────────────────────┐  ┌──────────────────────────────┐
│ mcp_toolkit (core)    │  │ mcp_capability_core   │  │ mcp_capability_live_edit     │
│ Flutter-side runtime  │  │ Server-side glue for  │  │ Server-side glue for         │
│ - VM service exts     │  │ Playwright parity +   │  │ live-edit (orchestration,    │
│ - dynamic registry    │  │ inspection tools      │  │ executor, host bindings)     │
│ - tool runtime stays  │  │ (no Flutter import)   │  │ depends on:                  │
│   here                │  │                       │  │   live_edit_models           │
└───────────────────────┘  └───────────────────────┘  │   (pure-Dart, no Flutter)    │
        ▲                              ▲              └──────────────────────────────┘
        │                              │                              ▲
        │ (Flutter app                 │                              │
        │  consumes)                   │                              │
        │                  ┌───────────┴──────────────┬───────────────┘
        │                  │                          │
        │          ┌──────────────────┐    ┌─────────────────────┐
        │          │ mcp_server_dart  │    │ flutter_mcp_cli     │
        │          │ (thin shell)     │    │ (thin shell)        │
        │          │ - JSON-RPC       │    │ - doctor, snapshot, │
        │          │ - capability     │    │   bundle, run       │
        │          │   registrar      │    │ - capability        │
        │          │ - default main:  │    │   registrar         │
        │          │   loads core +   │    │                     │
        │          │   live_edit      │    │                     │
        │          └──────────────────┘    └─────────────────────┘
        │
   (Flutter app
    initializes
    mcp_toolkit and
    optionally
    flutter_live_edit_toolkit)
```

### Packages introduced

| Package | Lives at | Depends on | Purpose |
|---|---|---|---|
| `mcp_capability_kernel` | new, top-level | `dart_mcp` only | Contracts: `Capability`, `CapabilityContext`, `ToolRegistration`, `HostService` interfaces, prefix enforcement |
| `mcp_capability_core` | new, top-level | `mcp_capability_kernel`, server-side runtime deps | Static-tool registrations for Playwright parity + inspection (`tap_widget`, `enter_text`, `wait_for`, `view_screenshots`, etc.) |
| `mcp_capability_live_edit` | new, top-level | `mcp_capability_kernel`, `live_edit_models` | Server-side glue for the 2 commands needing host services (StartSession, PrepareSession), agent service |
| `live_edit_models` | new, under `flutter_live_edit/` | nothing (pure-Dart) | Models shared between server-side capability and Flutter packages |

### Packages modified

- `mcp_server_dart` — drops deps on `flutter_live_edit_toolkit` + `live_edit_tooling_ui_kit`. Loses `lib/src/capabilities/live_edit/` (moved). Most of `lib/src/capabilities/{dart,error_analysis,visual_capture,diagnostics}/` migrates into `mcp_capability_core`. Gains capability registrar + thin `main.dart`.
- `flutter_mcp_cli` — same shape, thin shell with capability registrar.
- `mcp_toolkit` — `MCPToolkitBinding` gains `initialize(capabilityId: ...)`. Existing tool-registration APIs unchanged.
- `flutter_live_edit_toolkit` — calls `MCPToolkitBinding.instance.initialize(capabilityId: 'live_edit')` at init. Registers the 8 dynamic commands (see classification table below) via `addEntries`. Depends on `live_edit_models` instead of defining models inline.
- `live_edit_tooling_ui_kit` — depends on `live_edit_models` (it currently imports model types that the server reaches into via private paths).

## Components

### `Capability` interface

```dart
abstract interface class Capability {
  /// Stable id for the tool-name prefix (`<id>_<tool>`) and configuration.
  /// Must match `^[a-z][a-z0-9_]*$`. Examples: 'core', 'live_edit'.
  /// Reserved: 'app' (used for unscoped dynamic registrations).
  String get id;

  /// Human-readable description for `--list-capabilities`.
  String get description;

  /// Semver of this capability package. Surfaced in `doctor` output.
  String get version;

  /// Called once at host startup. Register tools, resources, host-service
  /// claims here. Calling twice on the same host throws (registration is
  /// configuration, not a stream). Must not perform I/O.
  Future<void> register(CapabilityContext context);

  /// Called once at host shutdown. Release resources, cancel subscriptions.
  Future<void> dispose();
}
```

### `CapabilityContext`

```dart
abstract interface class CapabilityContext {
  Logger get logger;

  /// Register an MCP tool. The kernel applies the `<id>_` prefix to
  /// [registration.name] before exposing it; capabilities must NOT
  /// pre-prefix. Throws on duplicate within the same capability.
  void registerTool(ToolRegistration registration);

  /// Register an MCP resource. Same prefix rules.
  void registerResource(ResourceRegistration registration);

  /// Access to host services the capability declared it needs.
  /// Throws if the capability didn't declare the dependency.
  T require<T extends HostService>();

  /// Capability-scoped configuration parsed from CLI flags or config file.
  CapabilityConfig get config;
}
```

### `HostService` family

Defined as interfaces in the kernel; implemented by the server.

```dart
abstract interface class HostService {}

abstract interface class VmServiceClient implements HostService { ... }
abstract interface class HotReloadCoordinator implements HostService { ... }
abstract interface class DynamicRegistryBridge implements HostService {
  /// Capability claims a namespace. Inbound dynamic entries tagged with
  /// this namespace get the `<namespace>_` prefix when exposed.
  void claim({required String namespace});
  ...
}
```

### Prefix enforcement

The kernel applies the `<capability.id>_` prefix at registration time. Capabilities pass bare names; the kernel composes the public name. Validation rules, all enforced at registration:

- Capability id must match `^[a-z][a-z0-9_]*$`. Otherwise: throws.
- Capability id is not reserved (`app` is reserved for unscoped dynamic registrations). Otherwise: throws.
- Tool name passed to `registerTool` must not start with the capability's prefix already (no double-prefixing). Otherwise: throws.
- Two static registrations of the same final prefixed name: fatal at host startup. Trivially unreachable when ids are unique.
- A dynamic entry arriving at the bridge with a name that collides with a static registration of the same final prefixed name: rejected at the bridge with a `tool_name_collision` error envelope.

## Data flow

### Path 1 — Static (server-side) registration

```
mcp_capability_core.register(ctx)
  └─→ ctx.registerTool(name: 'tap_widget', ...)
       └─→ kernel applies prefix → 'core_tap_widget'
            └─→ stored in host registry, exposed over MCP
```

### Path 2 — Dynamic (app-side) registration via DTD

```
flutter_live_edit_toolkit init:
  MCPToolkitBinding.instance.initialize(capabilityId: 'live_edit')
  MCPToolkitBinding.instance.addEntries({selectEntry, sketchEntry, …})

DTD event flows to server:
  DynamicRegistryBridge sees entry tagged with capabilityId='live_edit'
  Bridge has prior claim from mcp_capability_live_edit.register():
    claim(namespace: 'live_edit')
  Bridge applies prefix: 'select' → 'live_edit_select'
  Tool exposed via MCP tools/list as 'live_edit_select'
```

When a client invokes `live_edit_select`:

```
MCP tools/call name=live_edit_select
  └─→ host routes to DynamicRegistryBridge (recognizes prefixed name)
       └─→ bridge strips prefix, looks up app-side entry
            └─→ DTD round-trip to running app
                 └─→ entry handler runs, returns result
```

The static-vs-dynamic dispatch is transparent to the client. Both surfaces are flat at the MCP boundary.

### Apps using `mcp_toolkit` directly without a capability package

Apps that call `MCPToolkitBinding.addEntries()` for custom debugging tools (the existing power-user path documented in `ARCHITECTURE.md`) and don't call `initialize(capabilityId: ...)` get the reserved `app` namespace by default. Their tools surface as `app_<name>`. This breaks current users of that path (their tool names change), but is consistent with the no-namespace-pollution goal.

## Live-edit command classification

Verified during implementation; classification may shift ±1 commands as bodies are read.

| Command | Server-needed? | Why | Destination |
|---|---|---|---|
| `LiveEditStartSession` | yes | hot-reload coordination, agent setup | static tool in `mcp_capability_live_edit` |
| `LiveEditPrepareSession` | yes | hot reload + VM service prep | static tool in `mcp_capability_live_edit` |
| `LiveEditSetOverlay` | no | pure app-state mutation | dynamic, registered app-side |
| `LiveEditGetTree` | no | pure app-state read | dynamic |
| `LiveEditSelectAtPoint` | no | pure app-state mutation | dynamic |
| `LiveEditGetSelection` | no | pure app-state read | dynamic |
| `LiveEditGetCapabilities` | no | pure app-state read | dynamic |
| `LiveEditGetSelectionCandidates` | no | pure app-state read | dynamic |
| `LiveEditSetActiveSelection` | no | pure app-state mutation | dynamic |
| `LiveEditGetPropertyPanel` | no | pure app-state read | dynamic |

The two server-side commands need the server because of hot-reload coordination through VM service and agent orchestration (Codex/Cursor SDK calls). Everything else lives where the data lives — in the running Flutter app.

## Tool naming — the migration set

All current static tools listed in the audit get the `core_` prefix:

- `app_errors` → `core_app_errors`
- `view_screenshots` → `core_view_screenshots`
- `view_details` → `core_view_details`
- `inspect_widget_at_point` → `core_inspect_widget_at_point`
- `semantic_snapshot` → `core_semantic_snapshot`
- `tap_widget` → `core_tap_widget`
- `enter_text` → `core_enter_text`
- `scroll` → `core_scroll`
- `long_press` → `core_long_press`
- `swipe` → `core_swipe`
- `drag` → `core_drag`
- `get_recent_logs` → `core_get_recent_logs`
- `wait_for` → `core_wait_for`
- `press_key` → `core_press_key`
- `handle_dialog` → `core_handle_dialog`
- `navigate` → `core_navigate`
- `fill_form` → `core_fill_form`
- `hover` → `core_hover`
- (full list verified during implementation against `interaction_toolkit.dart`, `flutter_mcp_toolkit.dart`, `flutter_permission_toolkit.dart`)

Server-managed tools that don't move into a capability (e.g., `listClientToolsAndResources`, `runClientTool`, `runClientResource` from `dynamic_registry`) stay unprefixed — they are host machinery, not capability surface.

## Implementation sequencing

Each step is independently mergeable and revertible up through step 7. Step 8 is the irreversible cut.

1. **Create `mcp_capability_kernel`** — contracts only, zero behavior change.
2. **Add capability machinery to server** — `McpHost`, registrar, prefix enforcement, conflict detection. Behind `--use-capability-kernel` flag (default off). Legacy registration path still active.
3. **Extract `live_edit_models`** — pure-Dart package. `flutter_live_edit_toolkit` and `live_edit_tooling_ui_kit` re-export through it. `mcp_server_dart` switches deps. Fixes Flutter-in-server independently. **Best done in a separate agent / branch** since it is self-contained and high-value.
4. **Create `mcp_capability_core`** — extract static tool glue from `mcp_server_dart/lib/src/capabilities/{dart,error_analysis,visual_capture,diagnostics}/`. Default `main.dart` registers it under the flag.
5. **Create `mcp_capability_live_edit`** — extract `mcp_server_dart/lib/src/capabilities/live_edit/`. Server pubspec drops Flutter deps. The 2 server-side commands become static `Capability` tools.
6. **Extend `MCPToolkitBinding`** — add `initialize(capabilityId)` and tag dynamic entries. Implement `DynamicRegistryBridge.claim` server-side.
7. **Update `flutter_live_edit_toolkit`** — call `initialize(capabilityId: 'live_edit')`, register the 8 dynamic commands via `addEntries`. Remove the corresponding 8 server-side handlers.
8. **Flip the flag default to on.** Both paths still in the codebase. Run full test suite + Maestro flows to validate nothing depended on the legacy path. This is the breaking moment for tool names — old names start returning `tool_not_found`.
9. **Delete the flag and the legacy registration path.** Mechanical cleanup once step 8 is validated.
10. **Docs + contracts** — `MCP_RPC_DESCRIPTION.md` regenerated. `tool/contracts/check_plugin_surfaces.sh` updated to expect prefixed names. CHANGELOG includes a static reference table mapping old names to new (documentation only — no runtime aliases).

## Testing strategy

### Per-package

- **`mcp_capability_kernel`** — pure-Dart unit tests. Prefix enforcement, invalid id, reserved prefix, double-prefix detection, double-register throws.
- **`mcp_capability_core`** — capability tests using fake `CapabilityContext`. Existing P0–P2 tests in `mcp_server_dart/test/` move with the tool definitions; names update mechanically.
- **`mcp_capability_live_edit`** — static-tool tests for the 2 server-side commands. Host-service contract test: `LiveEditCapability.register()` claims `live_edit` namespace on the bridge mock.
- **`mcp_server_dart`** — JSON-RPC integration tests. Conflict detection: two capabilities with same id → host fails to start with structured error. `tools/list` returns prefixed names. `tools/call` routes correctly to static and dynamic handlers.
- **`flutter_live_edit_toolkit`** — existing test suite gets `MCPToolkitBinding.initialize(capabilityId: 'live_edit')` in setup. New tests assert the 8 commands appear with `live_edit_` prefix when the bridge is queried.
- **`mcp_toolkit`** — new tests for `initialize(capabilityId)` and DTD tagging.

### End-to-end

`flutter_test_app` + `maestro/` flows reference tools by their new prefixed names. One negative test: call `tap_widget` (old name) → assert `tool_not_found`. Codifies the hard cut.

### Contracts

`tool/contracts/check_plugin_surfaces.sh` validates the public surface against a versioned snapshot of expected (prefixed) tool names. Adding a new tool to a capability becomes a deliberate snapshot update reviewed in PR.

### Out of scope for unit testing

- Real DTD event flow with a real Flutter app — covered by Maestro/showcase only.
- Performance — capability loading is one-shot at startup.
- Hot reload survival — `MCPToolkitBinding` already handles it; kernel inherits the binding's behavior.

## Risk-by-step

| Step | Reverts cleanly? | Test cost | Behavior change |
|---|---|---|---|
| 1. kernel package | yes (unused) | unit tests on contracts | none |
| 2. host machinery behind flag | yes | new integration suite, flag default off | none |
| 3. `live_edit_models` extraction | yes (revert pubspec) | per-package tests pass | none — but fixes Flutter-in-server bug |
| 4. `mcp_capability_core` | yes (legacy path active) | snapshot of registered tools | none under flag |
| 5. `mcp_capability_live_edit` | yes | per-capability tests | none under flag |
| 6. `MCPToolkitBinding.initialize` | yes | binding tests | none unless capabilityId set |
| 7. `flutter_live_edit_toolkit` adoption | yes | live_edit tests pass with prefixed names | none under flag |
| 8. **flag flip default on** | **no** (renames go live) | full e2e + Maestro | **hard rename break** |
| 9. delete flag + legacy path | yes (cleanup) | tests still green | none after step 8 |
| 10. docs + contracts | yes | check-contracts green | none |

## Open questions resolved during brainstorming

- **Composition unit:** per-capability Dart packages (option A from brainstorm Q2).
- **Naming scheme:** underscore prefix `<capability>_<tool>` (option B from Q3).
- **Prefix enforcement:** kernel-only, no per-capability override.
- **Dynamic registry:** stays in server as host machinery, exposed via `DynamicRegistryBridge` interface in the kernel.
- **Dynamic-path namespacing:** server-side via capability claim (option β from Section 3).
- **Live-edit command split:** ~2 server-side, ~8 app-side dynamic; verify each body during implementation.
- **`live_edit_models` extraction:** in scope for this refactor; ideally a separate agent.
- **Cut line:** all in v3.0.0, hard cut, no migration aliases.

## Out-of-scope follow-ups

- Capability-level configuration via config file (today: CLI flags only).
- A `flutter_mcp_cli capabilities list` subcommand (could come in v3.1 once the surface stabilizes).
- Per-capability versioning beyond what `version` field surfaces in `doctor`.
- Loading capabilities at runtime (today: compile-time composition only).

## Acceptance criteria

The refactor is done when:

1. `mcp_server_dart/pubspec.yaml` has no Flutter package dependencies.
2. `make check-contracts` passes against the new prefixed-names snapshot.
3. `flutter_test_app` Maestro flows pass with new tool names.
4. A new `mcp_server_dart_minimal` example package (or doc snippet) demonstrates building a custom binary with only the core capability — no live-edit code linked.
5. CHANGELOG documents the rename clearly.
6. The `uses-material-design` warnings noted in `CLAUDE.md` no longer appear in `mcp_server_dart` test runs.
