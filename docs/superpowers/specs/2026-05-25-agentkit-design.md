# Agentkit Design Specification

**Status:** Draft — pending user review  
**Date:** 2026-05-25  
**Authors:** Architecture brainstorm (mcp_flutter → agentkit evolution)

---

## Summary

Evolve the Flutter MCP Toolkit’s tightly coupled tool/resource registry into **agentkit**: a transport-agnostic agent intent platform. A central **AgentRegistry** holds declarative **AgentIntent** definitions; multiple **AgentAdapter**s (MCP, WebMCP, Gemma, future native) attach to the same registry simultaneously. **mcp_flutter** remains the debug/runtime product built on agentkit.

**Authoring model (approved):** Hand-written and codegen are both first-class everywhere — server, host, **and Flutter client**. Codegen is **optional** on the client; teams choose per tool.

---

## Goals

1. Decouple registry from JSON-RPC, stdio, and SSE.
2. Expose the same intents to MCP, WebMCP, on-device Gemma, and (later) Apple/Android surfaces.
3. Preserve existing MCP tool names (`fmt_*`) and CLI behavior during migration.
4. Align with the Dart ecosystem **`dart_mcp`** package — complement, not compete with, the official [Dart and Flutter MCP server](https://docs.flutter.dev/ai/mcp-server).

## Non-goals (initial phases)

- Forking the MCP protocol or reimplementing `MCPServer`.
- Replacing `dart mcp-server` for static analysis / pub / format tooling.
- Full Apple App Intents / Android XML codegen in Phase 1.
- Mandatory `build_runner` for all app developers.

---

## Current state (mcp_flutter)

| Layer | Location | Transport coupling |
|-------|----------|-------------------|
| Execution | `CoreCommandExecutor`, `CoreResult` | Mostly agnostic (CLI + MCP) |
| Registration | `ToolRegistration`, `McpHost` | `dart_mcp` `CallToolRequest` / publish bridge |
| Dynamic app tools | `DynamicRegistry`, `MCPCallEntry` | `MCPToolkitServer`, `Tool`, `Resource` |
| Capabilities | `Capability` + `registerInteractionTools` | Imperative `registerTool` loops |

**Existing good patterns to keep:** extension-type wrappers (`MCPCallEntry`), `Set` composition, `CoreCommand` orchestration for VM/session work.

---

## Target architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                      AgentRuntime                            │
│  modules[] ──register──► AgentRegistry ◄──attach── adapters[]│
└─────────────────────────────────────────────────────────────┘
         │                        │                    │
         │                        │                    ├── agentkit_mcp (dart_mcp)
         │                        │                    ├── agentkit_webmcp
         │                        │                    ├── agentkit_gemma
         │                        │                    └── agentkit_apple/android (manifest)
         │                        │
         ▼                        ▼
   AgentModule bundles      validate + invoke + events
   (fmt, app, custom)
```

### Core types

| Type | Responsibility |
|------|----------------|
| `AgentIntent` | Schema + metadata + `execute(AgentInvocation)` |
| `AgentModule` | `register(AgentRegistry)` — composable bundle |
| `AgentRegistry` | Register, qualify names, validate, invoke, event stream |
| `AgentRuntime` | Run modules then attach adapters |
| `AgentAdapter` | Mirror registry to one external surface |

**Composition over inheritance:** Product code uses `AgentModule`, `AgentCallEntry` sets, and optional `@AgentTool` codegen — not subclasses of `AgentIntent`.

**Qualified names:** `{namespace}_{name}` (e.g. `fmt_tap_widget`). Namespace `app` reserved for dynamic Flutter app tools.

---

## Package layout

```text
agentkit/
├── agentkit_schema/       # InputSchema, validation, AgentResult
├── agentkit_core/         # Intent, Registry, Runtime, Module, Adapter
├── agentkit_codegen/      # @AgentTool, build_runner, agent_manifest.json
├── agentkit_testing/      # Fakes, contract harness
├── agentkit_mcp/          # Only package importing dart_mcp
├── agentkit_webmcp/       # navigator.modelContext (web + stub)
├── agentkit_gemma/        # flutter_gemma bridge (optional dependency)
├── agentkit_apple/        # Phase 3: Swift from manifest
└── agentkit_android/      # Phase 3: XML from manifest

mcp_flutter/ (consumer, then sibling repo)
├── mcp_server_dart
├── packages/ (capability core/kernel → agentkit modules)
└── mcp_toolkit (client SDK)
```

---

## Declarative authoring (Option C — revised)

Codegen is **optional on server and client**. Documentation presents two equal paths; choice is per-tool or per-team.

### Path 1 — Hand-written (default for simple / dynamic tools)

Evolution of `MCPCallEntry` → **`AgentCallEntry`** (extension types + `Set` composition).

**Best for:**

- Runtime-registered app tools (cart, feature flags, debug snapshots).
- Hot reload–friendly registrations.
- Prototypes and one-off tools.

```dart
extension type const CartTotalEntry._(AgentCallEntry entry) implements AgentCallEntry {
  factory CartTotalEntry({required CartService cart}) => CartTotalEntry._(
    AgentCallEntry.tool(
      namespace: 'app',
      name: 'cart_total',
      description: 'Current cart total',
      inputSchema: const {'type': 'object', 'properties': {}},
      handler: (args) async => AgentResult.success(data: {'total': cart.total}),
    ),
  );
}
```

### Path 2 — Codegen (optional everywhere)

`@AgentTool` + `build_runner` generates `AgentIntent` impl, JSON Schema, and manifest entries.

**Best for:**

- Server/host `fmt_*` capabilities (reduce schema boilerplate).
- **Client tools** when teams want typed parameters and compile-time schema checks.
- Native export (Apple/Android) via shared `agent_manifest.json`.

```dart
@AgentTool(namespace: 'app', name: 'loyalty_points')
Future<AgentResult> loyaltyPoints(
  @AgentParam('User id') String userId,
) async { ... }
```

### Decision guide (document in DX_FAQ / agentkit README)

| Situation | Recommended path |
|-----------|------------------|
| Dynamic registration, toggles, A/B | Hand-written `AgentCallEntry` |
| Few stable app tools, want type safety | Optional `@AgentTool` in app package |
| Server capability with large schema | Codegen (default in examples) |
| Native Siri / Shortcuts export | Codegen manifest (required for that surface) |

**No path is “second class.”** Pub examples show both; `flutter-mcp-toolkit init` can scaffold either template.

---

## Multi-adapter runtime

Multiple adapters attach to **one** registry:

```dart
final runtime = AgentRuntime(
  modules: [FmtAgentModule(), AppAgentModule()],
  adapters: [
    McpAgentAdapter(server: mcpServer),
    WebMcpAgentAdapter(),           // when supported
    GemmaAgentAdapter(chat: chat),  // optional
  ],
);
await runtime.start();
```

### Adapter behavior

```dart
abstract interface class AgentAdapter {
  String get id;
  Future<void> attach(AgentRegistry registry);
  Future<void> detach();
  bool get watchesRegistry; // default true for MCP, WebMCP, Gemma
}
```

| Adapter | attach | watchesRegistry | Notes |
|---------|--------|-----------------|-------|
| `agentkit_mcp` | Publish tools/resources to `dart_mcp` | yes | Maps `AgentResult` ↔ `CallToolResult` |
| `agentkit_webmcp` | `navigator.modelContext.registerTool` | yes | Feature-detect; stub on VM |
| `agentkit_gemma` | Build `tools` for `createChat` | yes | `FunctionCallResponse` → `registry.invoke` |
| `agentkit_apple` / `android` | N/A (build-time) | no | Reads `agent_manifest.json` |

### Registry events

- `IntentRegistered` / `IntentUnregistered` fan out to watching adapters.
- MCP clients without live tool-list updates: keep existing `await-dynamics` / discovery semantics.

---

## agentkit_gemma (on-device)

- Package: **`agentkit_gemma`** (optional dep on `flutter_gemma`).
- Maps registry → Gemma tool definitions; invoke loop:

```text
User → Gemma → FunctionCallResponse
  → registry.invoke(qualifiedName, args)
  → AgentResult → tool result → Gemma → final answer
```

- Same registry can serve MCP (remote agent) and Gemma (on-device) concurrently in one Flutter app.
- Unsupported models: adapter skips tools; registry + MCP unchanged.

---

## Dart MCP ecosystem alignment

| Principle | Implementation |
|-----------|----------------|
| Protocol | `agentkit_mcp` wraps `package:dart_mcp` — no fork |
| Product positioning | Official server = dev tooling; flutter-mcp-toolkit = live debug/control |
| Versioning | Track `dart_mcp` supported protocol versions in adapter |
| Core neutrality | `agentkit_core` has zero `dart_mcp` imports |

---

## Interface sketches (agentkit_core)

### AgentIntent

```dart
enum AgentIntentKind { tool, resource }

abstract interface class AgentIntent {
  String get id;
  String get namespace;
  String get name;
  String get description;
  AgentIntentKind get kind;
  InputSchema get inputSchema;
  String? get resourceUriTemplate;
  String? get mimeType;
  void validate(AgentArguments arguments);
  Future<AgentResult> execute(AgentInvocation invocation);
}
```

### AgentRegistry

```dart
abstract interface class AgentRegistry {
  String qualify({required String namespace, required String name});
  void register(AgentIntent intent, {String? qualifiedNameOverride});
  void unregister(String qualifiedName);
  AgentIntent? get(String qualifiedName);
  Iterable<AgentIntent> list({String? namespace});
  Future<AgentResult> invoke(String qualifiedName, AgentArguments arguments, {...});
  Stream<AgentRegistryEvent> get events;
}
```

### AgentModule

```dart
abstract interface class AgentModule {
  String get id;
  Future<void> register(AgentRegistry registry);
  Future<void> dispose();
}
```

### AgentRuntime

```dart
final class AgentRuntime {
  AgentRuntime({required List<AgentModule> modules, List<AgentAdapter> adapters = const []});
  AgentRegistry get registry;
  Future<void> start();  // modules.register → adapters.attach
  Future<void> stop();   // adapters.detach → modules.dispose
}
```

---

## Migration phases

### Phase 1 — Core in mcp_flutter workspace (4–6 weeks)

- Add `agentkit_schema`, `agentkit_core`, `AgentRuntime`.
- Bridge `ToolRegistration` → `AgentIntent`; MCP handlers call `registry.invoke` only.
- Introduce `AgentCallEntry`; deprecate `MCPCallEntry` with export alias.
- Optional codegen pilot: one `fmt_*` tool + **one optional client tool example** in `flutter_test_app`.
- Tests: registry-only + MCP parity contract.

**Exit:** All static server tools invoke via registry; external MCP/CLI unchanged.

### Phase 2 — Decouple host (3–5 weeks)

- `McpHost` → registry-only; `McpAgentAdapter` owns `dart_mcp` publish.
- `DynamicRegistry` stores intents, not `dart_mcp.Tool`.
- Remove `dart_mcp` from `server_capability_kernel`.
- Document client authoring: hand-written vs optional `@AgentTool`.

**Exit:** Kernel is transport-agnostic; MCP only in `agentkit_mcp` / server wiring.

### Phase 3 — agentkit repo + adapters (ongoing)

- Split `agentkit` monorepo; `mcp_flutter` consumes published packages.
- Ship `agentkit_webmcp`, `agentkit_gemma`.
- `agentkit_apple` / `agentkit_android` from manifest.
- Remove public shims after deprecation window.

---

## Error handling and testing

- **Single envelope:** `AgentResult` aligned with `CoreResult`; adapters map at boundary.
- **Unit tests:** Registry validate/invoke/collision without transport.
- **Contract tests:** Same args → same `AgentResult` via registry, MCP adapter, Gemma adapter.
- **Regression:** Existing `core_executor_test`, capability registration, dynamic registry integration.

---

## Key design decisions

| Topic | Decision |
|-------|----------|
| Authoring | Hand-written + codegen both first-class; **codegen optional on client and server** |
| Structure | `AgentModule` + `AgentCallEntry` composition; no intent inheritance |
| Multi-surface | `AgentRuntime` + multiple `AgentAdapter`s on one registry |
| MCP | `dart_mcp` only in `agentkit_mcp` |
| Gemma | `agentkit_gemma` optional adapter |
| Native | Build-time manifest from codegen; not runtime attach |
| Compatibility | Preserve `fmt_*` MCP names and CLI commands |

---

## Open questions (for implementation plan)

1. Exact `agent_manifest.json` schema version and fields for Apple/Android.
2. Whether `CoreCommand` remains separate from `AgentIntent` for VM/session orchestration (recommended: yes).
3. Pub package publish order: `agentkit_core` first vs in-repo path deps until Phase 3.

---

## References

- [dart_mcp](https://github.com/dart-lang/ai/tree/main/pkgs/dart_mcp) — Dart MCP client/server package
- [Dart and Flutter MCP server](https://docs.flutter.dev/ai/mcp-server) — Official tooling server
- [flutter_gemma](https://pub.dev/packages/flutter_gemma) — On-device Gemma + function calling
- [WebMCP / navigator.modelContext](https://docs.mcp-b.ai/explanation/webmcp/standard-api)
- mcp_flutter: `McpHost`, `ToolRegistration`, `MCPCallEntry`, `CoreCommandExecutor`
