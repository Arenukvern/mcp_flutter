# Agentkit Design Specification

**Status:** Approved (2026-05-25)  
**Date:** 2026-05-25  
**Authors:** Architecture brainstorm (mcp_flutter → agentkit evolution)

---

## Summary

Evolve the Flutter MCP Toolkit’s tightly coupled tool/resource registry into **agentkit**: a transport-agnostic agent intent platform. Authors declare tools via **`AgentCallEntry` / `@AgentTool`**; a central **AgentRegistry** holds **`RegisteredAgentIntent`** (descriptor + executor). Multiple **AgentAdapter**s (MCP, WebMCP, Gemma, future native) attach to the same registry simultaneously. **mcp_flutter** remains the debug/runtime product built on agentkit.

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

### Core types (two layers — authoring vs runtime)

The spec previously conflated **declarative authoring** with **`AgentIntent`**, which looked like a class app developers must implement. They must not. The model is two layers:

| Layer | Types | Who authors them |
|-------|--------|------------------|
| **Authoring** (declarative) | `AgentCallEntry`, `@AgentTool`, `AgentIntentDescriptor` | App and capability developers |
| **Runtime** (registry) | `RegisteredAgentIntent` (descriptor + executor) | Framework only — from `toRegistration()`, codegen, or bridges |

```text
AgentCallEntry / @AgentTool
        │  toRegistration() / codegen
        ▼
RegisteredAgentIntent  ──stored in──►  AgentRegistry
        ▲
ToolRegistration bridge (Phase 1)
```

| Type | Responsibility |
|------|----------------|
| `AgentIntentDescriptor` | Immutable metadata + `InputSchema` (no `execute`) |
| `AgentCallEntry` | Extension-type authoring bundle → produces registration |
| `RegisteredAgentIntent` | Descriptor + `AgentExecutor` callback; registry unit |
| `AgentModule` | `register(AgentRegistry)` — composable bundle |
| `AgentRegistry` | Register, qualify names, validate, invoke, event stream |
| `AgentRuntime` | Modules → registry; adapters attach |
| `AgentAdapter` | Reads descriptors; invokes via registry |

**Composition over inheritance:** Authors compose `Set<AgentCallEntry>` and `AgentModule` lists. They never `implements AgentIntent` or `implements RegisteredAgentIntent`.

**Qualified names:** `{namespace}_{name}` (e.g. `fmt_tap_widget`). Namespace `app` reserved for dynamic Flutter app tools. There is no separate `id` field on descriptors — use `namespace` (equals legacy capability id, e.g. `fmt`).

**VM / service extension:** Authoring may set `methodName` when it differs from surfaced tool `name` (same rule as `MCPMethodName` vs `MCPToolDefinition.name` today). Defaults to `name`.

---

## Package layout

```text
agentkit/
├── agentkit_schema/       # InputSchema, validation, AgentResult, envelope, AgentWireArgs
├── agentkit_core/         # Intent, Registry, Runtime, Module, Adapter
├── agentkit_codegen/      # @AgentTool, build_runner, agent_manifest.json
├── agentkit_testing/      # Fakes, contract harness
├── agentkit_mcp/          # Only package importing dart_mcp
├── agentkit_webmcp/       # navigator.modelContext (browser); VM uses test fakes
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

`@AgentTool` + `build_runner` generates a `RegisteredAgentIntent` factory + JSON Schema + manifest entries (not a type authors subclass).

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

### Path 3 — Builder function + dependency injection (recommended for Flutter apps)

Validated in **ecsly** (`spark_physics_ecs`, `arena_sandbox`, `vfx_lab`): a pure Dart function returns `Set<AgentCallEntry>` with **injected readers/updaters**, not widget/state access inside handlers.

```dart
typedef SparkSnapshotReader = Map<String, Object?> Function();

Set<AgentCallEntry> buildSparkAgentEntries({
  required SparkSnapshotReader readSnapshot,
  required SparkControlUpdater applyControls,
}) => {
  AgentCallEntry.resource(
    namespace: 'app',
    name: 'spark_runtime_snapshot',
    description: 'Read-only runtime snapshot.',
    inputSchema: const {'type': 'object', 'properties': {}},
    handler: (_) => AgentResult.envelope(
      kind: 'spark_runtime_snapshot',
      snapshot: readSnapshot(),
    ),
  ),
  // ...
};

// Module wrapper for AgentRuntime / MCPToolkitBinding
final appModule = AgentModule.fromEntries(
  id: 'spark',
  build: () => buildSparkAgentEntries(
    readSnapshot: host.readMcpSnapshot,
    applyControls: host.applyMcpControls,
  ),
);
```

**Why:** Handlers stay thin; **unit tests** call `buildSparkAgentEntries` with fakes — no `MCPToolkitBinding`, no VM (see ecsly `spark_mcp_extensions_test.dart`).

| ecsly pattern | agentkit API |
|---------------|--------------|
| `buildSparkMcpEntries(...)` | `Set<AgentCallEntry> buildXAgentEntries({...})` |
| `addEntries(entries: ...)` | `AgentModule.fromEntries` + `MCPToolkitBinding.addEntries` (Phase 1 shim) |
| `getFlutterMcpToolkitEntries(binding:)` | `ToolkitBuiltinAgentModule` composed with app module |

---

## Client DX patterns (ecsly-derived)

Production usage in `~/xs/ecsly` prototypes informs first-class client helpers in **`agentkit_schema`** and **`mcp_toolkit`** (re-export). These are **not** required for protocol correctness; they reduce copy-paste and agent confusion.

### 1. Response envelope (`AgentResult.envelope`)

Apps repeatedly wrap payloads with `schema_version`, `kind`, `tool_name`, `snapshot`, and (for resources) MCP-shaped `resource` / `contents` blocks.

```dart
// agentkit_schema
extension AgentResultEnvelope on AgentResult {
  static AgentResult envelope({
    required String kind,
    required Map<String, Object?> snapshot,
    String message = 'ok',
    int schemaVersion = 1,
    Map<String, Object?>? extra,
  }) => AgentResult.success(
    message: message,
    data: {
      'schema_version': schemaVersion,
      'kind': kind,
      'tool_name': kind,
      'snapshot': snapshot,
      'snapshot_json': jsonEncode(snapshot),
      if (extra != null) ...extra,
    },
  );

  static AgentResult resourceEnvelope({
    required String resourceName,
    required Map<String, Object?> snapshot,
    String mimeType = 'application/json',
  }) {
    final uri = AgentIntentDescriptor.resourceUriForName(resourceName);
    final text = jsonEncode(snapshot);
    return AgentResult.success(
      message: '$resourceName snapshot.',
      data: {
        'schema_version': 1,
        'kind': resourceName,
        'resource_name': resourceName,
        'resource_uri': uri,
        'mimeType': mimeType,
        'snapshot': snapshot,
        'snapshot_json': text,
        'resource': {'uri': uri, 'mimeType': mimeType, 'text': text},
        'contents': [
          {'uri': uri, 'mimeType': mimeType, 'text': text},
        ],
      },
    );
  }
}
```

**Rule:** Compute `resource_uri` once on the descriptor; envelope helpers must not re-derive URIs differently than `AgentIntentDescriptor.resourceUriForName`.

### 2. Wire parsers (`AgentWireArgs`)

Flutter VM service extensions deliver tool arguments as **`Map<String, String>`** (not typed JSON). Every ecsly handler reimplements `_readOptionalBool`, `_readOptionalInt`, etc.

```dart
// agentkit_schema — parses ServiceExtension wire map
extension type const AgentWireArgs(Map<String, String> _raw) {
  String? string(String key) => _raw[key]?.trim().isEmpty == true ? null : _raw[key]?.trim();
  bool? bool_(String key) { /* true/false/1/0/yes/no */ }
  int? int_(String key) => int.tryParse(_raw[key]?.trim() ?? '');
  double? double_(String key) => double.tryParse(_raw[key]?.trim() ?? '');
  Map<String, Object?>? jsonObject(String key) { /* jsonDecode when present */ }
}

// Hand-written handler: parse once, call typed app API
handler: (args) async {
  final wire = AgentWireArgs(args);
  final snapshot = applyControls(
    viewMode: wire.string('viewMode'),
    strictEnabled: wire.bool_('strictEnabled'),
    ...
  );
  return AgentResult.envelope(kind: 'spark_set_parity_controls', snapshot: snapshot, extra: {...});
}
```

Codegen path maps `@AgentParam` types directly; hand-written and builder paths use `AgentWireArgs` at the boundary.

### 3. Lazy / deferred client install (`AgentClientInstall`)

Registration timing varies by app:

| Pattern | When | Example (ecsly) |
|---------|------|------------------|
| Early `main` | Before `runApp`, static deps | `arena_sandbox` |
| `bootstrapFlutter` | Zone + toolkit + optional entries | `gltf_playground` |
| Post-init / post-bridge | World or render runtime ready | `spark_physics_ecs` (`initState` → `_installMcpToolkitEntries`) |
| Bundled only | Default toolkit entries | `vfx_lab` |

```dart
// mcp_toolkit (re-export agentkit_core helper)
final class AgentClientInstall {
  AgentClientInstall._();
  static Future<void> once({
    required Future<Set<AgentCallEntry>> Function() buildEntries,
    Future<void> Function(Set<AgentCallEntry> entries)? register,
  }) async {
    if (kReleaseMode || _done) return;
    _done = true;
    try {
      final entries = await buildEntries();
      await (register ?? MCPToolkitBinding.instance.addEntries)(entries: entries);
    } on Object {
      _done = false;
      rethrow;
    }
  }
  static bool _done = false;
}
```

**Rules (document in DX_FAQ):**

- Never register inside `build()` or per-frame.
- Prefer **one** install per process; use `once` guard.
- If state is not ready at `main`, use builder + `AgentClientInstall.once` after first frame or world attach.

### 4. Compose builtin + app modules

```dart
await MCPToolkitBinding.instance.bootstrapFlutter(
  additionalEntries: () => {
    ...ToolkitBuiltinAgentEntries(binding: MCPToolkitBinding.instance),
    ...buildMyAppAgentEntries(readSnapshot: _readSnapshot),
  },
  runApp: () => runApp(const MyApp()),
);
```

`AgentRuntime` server-side equivalent: `modules: [FmtAgentModule(), AppAgentModule.fromEntries(...)]`.

### 5. Entry testing without Flutter (`agentkit_testing`)

Mirror ecsly `spark_mcp_extensions_test.dart`:

```dart
test('tool echoes controls', () async {
  final entries = buildSparkAgentEntries(
    readSnapshot: () => {'phase': 'playing'},
    applyControls: ({viewMode}) => {'view_mode': viewMode},
  );
  final entry = entries.byName('spark_set_parity_controls');
  final result = await entry.invokeWire({'viewMode': 'composite'});
  expect(result.data['snapshot']['view_mode'], 'composite');
});
```

Helpers: `entries.byName`, `invokeWire(Map<String, String>)`, golden checks on `schema_version` / `resource_uri`.

### Client authoring decision guide (extended)

| Situation | Recommended path |
|-----------|------------------|
| ECS / game host with late world attach | **Builder** + `AgentClientInstall.once` |
| Single diagnostics resource at startup | Builder or inline `AgentCallEntry.resource` in `main` |
| Many tools, typed params | Optional `@AgentTool` codegen |
| Branded typed constructors | Extension type wrapping `AgentCallEntry` (mcp_toolkit style) |
| Agent-stable JSON | Always use `AgentResult.envelope` / `resourceEnvelope` |

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
| `agentkit_webmcp` | `navigator.modelContext.registerTool` | yes | Feature-detect; in-memory fake on VM/tests |
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

> **Note:** `AgentIntent` was renamed/split in this revision to match declarative authoring. See [Investigation: AgentIntent vs declarative authoring](#investigation-agentintent-vs-declarative-authoring) below.

### AgentIntentDescriptor (declarative metadata)

```dart
enum AgentIntentKind { tool, resource }

@immutable
final class AgentIntentDescriptor {
  const AgentIntentDescriptor({
    required this.namespace,
    required this.name,
    required this.description,
    required this.kind,
    required this.inputSchema,
    this.methodName,
    this.resourceUri,
    this.mimeType,
  });

  final String namespace;
  final String name;
  final String description;
  final AgentIntentKind kind;
  final InputSchema inputSchema;

  /// VM service extension suffix; defaults to [name] when null.
  final String? methodName;

  /// Resource URI for [AgentIntentKind.resource]; computed when null.
  final String? resourceUri;
  final String? mimeType;

  String get qualifiedName => '${namespace}_$name';
  String get effectiveMethodName => methodName ?? name;

  /// Same rule as MCPCallEntry.resourceUri: `visual://localhost/a/b/c`.
  static String resourceUriForName(String name) =>
      'visual://localhost/${name.split('_').join('/')}';
}
```

### RegisteredAgentIntent (runtime — framework only)

```dart
typedef AgentExecutor = Future<AgentResult> Function(AgentInvocation invocation);

@immutable
final class AgentInvocation {
  const AgentInvocation({
    required this.descriptor,
    required this.arguments,
    this.correlationId,
  });
  final AgentIntentDescriptor descriptor;
  final AgentArguments arguments;
  final String? correlationId;
}

/// Registry-stored unit. Authors do not implement this type.
final class RegisteredAgentIntent {
  RegisteredAgentIntent({
    required this.descriptor,
    required AgentExecutor execute,
    void Function(AgentArguments args)? validate,
  }) : _execute = execute,
       _validate = validate ?? ((_) {});

  final AgentIntentDescriptor descriptor;
  final AgentExecutor _execute;
  final void Function(AgentArguments arguments) _validate;

  String get qualifiedName => descriptor.qualifiedName;
  void validate(AgentArguments arguments) => _validate(arguments);
  Future<AgentResult> execute(AgentInvocation invocation) => _execute(invocation);
}
```

### AgentCallEntry → registration (authoring)

```dart
extension type const AgentCallEntry._(/* record: descriptor fields + handler */) {
  factory AgentCallEntry.tool({...});

  RegisteredAgentIntent toRegistration() => RegisteredAgentIntent(
    descriptor: AgentIntentDescriptor(...),
    execute: (inv) => handler(inv.arguments),
  );
}
```

### AgentRegistry

```dart
abstract interface class AgentRegistry {
  String qualify({required String namespace, required String name});
  void register(RegisteredAgentIntent intent, {String? qualifiedNameOverride});
  void unregister(String qualifiedName);
  RegisteredAgentIntent? get(String qualifiedName);
  Iterable<AgentIntentDescriptor> listDescriptors({String? namespace});
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

/// ecsly-style: pure builder → entries → registrations
final class AgentModuleFromEntries implements AgentModule {
  AgentModuleFromEntries({
    required this.id,
    required this.buildEntries,
  });
  final String id;
  final Set<AgentCallEntry> Function() buildEntries;

  factory AgentModule.fromEntries({
    required String id,
    required Set<AgentCallEntry> Function() build,
  }) => AgentModuleFromEntries(id: id, buildEntries: build);

  @override
  Future<void> register(AgentRegistry registry) async {
    registerAll(registry, buildEntries());
  }
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

## Self-closing implementation loop

Agentkit work uses a **self-closing** agent pair so phases do not stall on unverified “done” claims:

| Role | Responsibility |
|------|----------------|
| **Implementer** | Execute the active [phase plan](plans/2026-05-25-agentkit-phase1.md) tasks |
| **Closer** | Verify exit criteria, audit spec coverage, write closure report; **regenerate** the same phase plan on failure or the **next** phase plan on success |

Repeat until [rollout tracker](tracker/agentkit-rollout.yaml) sets `program.status: complete`.

**Playbook:** [agentkit-self-closing-loop.md](agentkit-self-closing-loop.md)  
**Program overview:** [plans/2026-05-25-agentkit-rollout.md](plans/2026-05-25-agentkit-rollout.md)

Phase 2 and Phase 3 implementation plans are **not** written upfront — the Closer generates them after the previous phase gate passes.

---

## Migration phases

### Phase 1 — Core in mcp_flutter workspace (4–6 weeks)

- Add `agentkit_schema`, `agentkit_core`, `AgentRuntime`.
- Bridge `ToolRegistration` → `AgentIntent`; MCP handlers call `registry.invoke` only.
- Introduce `AgentCallEntry`; deprecate `MCPCallEntry` with export alias.
- Optional codegen pilot: one `fmt_*` tool + **one optional client tool example** in `flutter_test_app`.
- Client DX: `AgentResult.envelope`, `AgentWireArgs`, `AgentModule.fromEntries`, `AgentClientInstall.once` in `agentkit_schema` / `mcp_toolkit`.
- Tests: registry-only + MCP parity contract + **entry builder tests** (ecsly spark pattern).

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

- **Single envelope:** `AgentResult` aligned with `CoreResult`; adapters map at boundary. Client apps use **`AgentResult.envelope`** for agent-stable JSON (ecsly `schema_version` / `kind` / `snapshot`).
- **Unit tests:** Registry validate/invoke/collision without transport.
- **Entry tests:** `buildXAgentEntries` + `agentkit_testing.invokeWire` without `MCPToolkitBinding` (ecsly `spark_mcp_extensions_test.dart`).
- **Contract tests:** Same args → same `AgentResult` via registry, MCP adapter, Gemma adapter.
- **Regression:** Existing `core_executor_test`, capability registration, dynamic registry integration.

---

## Key design decisions

| Topic | Decision |
|-------|----------|
| Authoring | Hand-written + codegen both first-class; **codegen optional on client and server** |
| Structure | `AgentModule` + `AgentCallEntry` composition; `RegisteredAgentIntent` is framework-internal |
| Multi-surface | `AgentRuntime` + multiple `AgentAdapter`s on one registry |
| MCP | `dart_mcp` only in `agentkit_mcp` |
| Gemma | `agentkit_gemma` optional adapter |
| Native | Build-time manifest from codegen; not runtime attach |
| Compatibility | Preserve `fmt_*` MCP names and CLI commands |
| Client DX | Builder + `AgentModule.fromEntries`, `AgentResult.envelope`, `AgentWireArgs`, `AgentClientInstall.once` (ecsly-validated) |

---

## Investigation: AgentIntent vs declarative authoring

### What was inconsistent

| Issue | Spec said | Problem |
|-------|-----------|---------|
| Authoring API | `AgentCallEntry` extension types, `@AgentTool` on functions | Declarative, compositional |
| Runtime API | `abstract interface class AgentIntent` with 10 members + `execute` | Looks like the type authors **implement** — contradicts “not subclasses of AgentIntent” |
| Codegen output | “generates `AgentIntent` impl” | Implies inheritance / `implements` |
| Identity | `id` + `namespace` + `name` | `AgentCallEntry` examples only use `namespace` + `name`; `id` duplicated capability id |
| Resources | `resourceUriTemplate` in sketch, `resourceUri` in plan | Naming drift |
| MCP parity | `MCPCallEntry` keys by `MCPMethodName` | Flat `namespace`/`name` in sketches dropped `methodName` |

So readers could reasonably infer: *“I declare tools by implementing `AgentIntent`”* — the opposite of Option C.

### Resolution (approved model)

1. **`AgentIntentDescriptor`** — pure declarative metadata (what adapters serialize to MCP / WebMCP / Gemma / manifest).
2. **`RegisteredAgentIntent`** — descriptor + executor; only the registry holds these.
3. **`AgentCallEntry` / `@AgentTool`** — authoring; convert once at `register()` time.
4. **Drop author-facing `AgentIntent` interface** — avoids inheritance pressure; adapters use `listDescriptors()` + `invoke()`.
5. **Single identity key** — `namespace` + `name` → `qualifiedName`; `namespace` replaces legacy `Capability.id` / redundant `id`.
6. **`methodName`** — optional on descriptor for VM extensions when ≠ tool `name`.

### What stays the same

- Registry validate + invoke pipeline
- Multi-adapter attachment to one registry
- Phase 1 bridge from `ToolRegistration` builds `RegisteredAgentIntent`
- `CoreCommand` remains separate from tool descriptors

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
- ecsly: `prototypes/spark_physics_ecs/lib/spark/spark_mcp_extensions.dart`, `spark_mcp_extensions_test.dart`, `arena_sandbox/example/lib/main.dart`, `vfx_lab/example/lib/main.dart`
