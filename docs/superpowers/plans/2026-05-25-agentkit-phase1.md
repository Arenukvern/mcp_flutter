# Agentkit Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce transport-agnostic `agentkit_schema` + `agentkit_core` inside the mcp_flutter workspace, route all static MCP tool invocations through `AgentRegistry.invoke`, and add hand-written + optional-codegen authoring paths without breaking external MCP/CLI contracts.

**Architecture:** New packages sit under `packages/agentkit_*`. `McpHost` dual-registers each `ToolRegistration` into `InMemoryAgentRegistry` and keeps existing `dart_mcp` publish bridge until Phase 2. Handlers become thin wrappers: `CallToolRequest` → `registry.invoke` → `AgentResult` → `CallToolResult`. `CoreCommand` stays for VM/session orchestration; tool-shaped work maps to intents.

**Tech Stack:** Dart 3.11 workspace, `meta`, `test`, existing `dart_mcp ^0.5.0`, optional `build_runner` + `source_gen` for codegen pilot.

**Design spec:** `docs/superpowers/specs/2026-05-25-agentkit-design.md`

> **Spec revision (2026-05-25):** Authoring uses `AgentCallEntry` / `@AgentTool`. Registry stores **`RegisteredAgentIntent`** (descriptor + executor), not author-implemented `AgentIntent`. Use `AgentIntentDescriptor` for adapter serialization. See spec section *Investigation: AgentIntent vs declarative authoring*.

---

## File map (Phase 1)

| File / package | Responsibility |
|----------------|----------------|
| `packages/agentkit_schema/` | `AgentResult`, `InputSchema`, JSON-schema validation |
| `packages/agentkit_core/` | `AgentIntentDescriptor`, `RegisteredAgentIntent`, `AgentRegistry`, `AgentRuntime`, `AgentAdapter`, `AgentCallEntry` |
| `packages/agentkit_codegen/` | `@AgentTool`, `@AgentParam`, generator pilot |
| `packages/agentkit_testing/` | `FakeAgentAdapter`, registry contract helpers |
| `packages/server_capability_kernel/lib/src/agent_bridge.dart` | `toolRegistrationToIntent`, qualify helpers |
| `mcp_server_dart/lib/src/mcp_toolkit_server/agent_registry_host.dart` | Registry owned by server; dual-write |
| `mcp_server_dart/lib/src/mcp_toolkit_server/mcp_result_mapper.dart` | `AgentResult` ↔ `CallToolResult` |
| `mcp_toolkit/lib/src/agent_call_entry.dart` | Client hand-written entries |
| `mcp_toolkit/lib/src/mcp_models.dart` | `typedef MCPCallEntry = AgentCallEntry` alias period |
| `flutter_test_app/lib/agent_tools/` | Optional client `@AgentTool` example |

**Explicitly not in Phase 1:** `agentkit_webmcp`, `agentkit_gemma`, `agentkit_apple`, removing `dart_mcp` from kernel, `DynamicRegistry` rewrite.

---

## Task 1: Workspace — add `agentkit_schema` package

**Files:**
- Create: `packages/agentkit_schema/pubspec.yaml`
- Create: `packages/agentkit_schema/analysis_options.yaml`
- Create: `packages/agentkit_schema/lib/agentkit_schema.dart`
- Create: `packages/agentkit_schema/lib/src/agent_result.dart`
- Create: `packages/agentkit_schema/lib/src/input_schema.dart`
- Create: `packages/agentkit_schema/lib/src/schema_validator.dart`
- Create: `packages/agentkit_schema/test/schema_validator_test.dart`
- Modify: `pubspec.yaml` (workspace root) — add workspace member

- [ ] **Step 1: Add workspace member**

Modify root `pubspec.yaml`:

```yaml
workspace:
  - packages/core
  - packages/server_capability_kernel
  - packages/server_capability_core
  - packages/agentkit_schema
  - mcp_server_dart
```

- [ ] **Step 2: Create `pubspec.yaml`**

```yaml
name: agentkit_schema
description: Transport-agnostic agent result envelopes and JSON Schema validation.
version: 0.1.0
publish_to: none
environment:
  sdk: ">=3.11.0 <4.0.0"
resolution: workspace
dependencies:
  meta: ^1.17.0
dev_dependencies:
  lints: ^6.1.0
  test: ^1.31.1
```

- [ ] **Step 3: Write `agent_result.dart`**

```dart
import 'package:meta/meta.dart';

typedef AgentArguments = Map<String, Object?>;
typedef InputSchema = Map<String, Object?>;

@immutable
final class AgentArtifact {
  const AgentArtifact.text(this.text, {this.mimeType = 'text/plain'});
  const AgentArtifact.bytes(this.bytes, {required this.mimeType});

  final String mimeType;
  final String? text;
  final List<int>? bytes;
}

@immutable
final class AgentResult {
  const AgentResult._({
    required this.ok,
    this.message = '',
    this.data = const {},
    this.artifacts = const [],
    this.code,
    this.details = const {},
  });

  factory AgentResult.success({
    String message = 'ok',
    Map<String, Object?> data = const {},
    List<AgentArtifact> artifacts = const [],
  }) => AgentResult._(ok: true, message: message, data: data, artifacts: artifacts);

  factory AgentResult.failure({
    required String code,
    required String message,
    Map<String, Object?> details = const {},
  }) => AgentResult._(ok: false, code: code, message: message, details: details);

  final bool ok;
  final String message;
  final Map<String, Object?> data;
  final List<AgentArtifact> artifacts;
  final String? code;
  final Map<String, Object?> details;
}
```

- [ ] **Step 4: Write minimal `schema_validator.dart`**

Validate `type: object`, `required`, `properties` types (`string`, `integer`, `number`, `boolean`). Throw `AgentValidationException` with field path. No full JSON Schema draft support in Phase 1 — match what `fmt_*` tools use today.

```dart
final class AgentValidationException implements Exception {
  AgentValidationException(this.message);
  final String message;
  @override
  String toString() => 'AgentValidationException: $message';
}

void validateAgainstSchema(InputSchema schema, AgentArguments arguments) {
  // implement: object root, required keys, property types, additionalProperties: false
}
```

- [ ] **Step 5: Write failing test**

```dart
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:test/test.dart';

void main() {
  test('rejects missing required field', () {
    const schema = {
      'type': 'object',
      'additionalProperties': false,
      'required': ['ref'],
      'properties': {'ref': {'type': 'string'}},
    };
    expect(
      () => validateAgainstSchema(schema, {}),
      throwsA(isA<AgentValidationException>()),
    );
  });
}
```

- [ ] **Step 6: Run test**

```bash
cd /Users/anton/mcp/mcp_flutter/packages/agentkit_schema
dart test test/schema_validator_test.dart -r expanded
```

Expected: PASS after implementation.

- [ ] **Step 7: Commit**

```bash
git add packages/agentkit_schema pubspec.yaml
git commit -m "feat(agentkit): add agentkit_schema package"
```

---

## Task 2: `agentkit_core` — descriptors, registrations, naming

**Files:**
- Create: `packages/agentkit_core/pubspec.yaml`
- Create: `packages/agentkit_core/lib/agentkit_core.dart`
- Create: `packages/agentkit_core/lib/src/intent/agent_intent.dart`
- Create: `packages/agentkit_core/lib/src/intent/callable_agent_intent.dart`
- Create: `packages/agentkit_core/lib/src/naming/qualified_name.dart`
- Create: `packages/agentkit_core/lib/src/adapter/agent_adapter.dart`
- Create: `packages/agentkit_core/lib/src/module/agent_module.dart`
- Create: `packages/agentkit_core/test/qualified_name_test.dart`
- Modify: root `pubspec.yaml` workspace

- [ ] **Step 1: Add workspace member `packages/agentkit_core`**

`pubspec.yaml` depends on `agentkit_schema` only (no `dart_mcp`).

- [ ] **Step 2: Implement naming (mirror kernel validators)**

```dart
// packages/agentkit_core/lib/src/naming/qualified_name.dart
final _idPattern = RegExp(r'^[a-z][a-z0-9_]*$');
const reservedNamespaces = {'app'};

void validateNamespace(String namespace) {
  if (!_idPattern.hasMatch(namespace)) {
    throw ArgumentError('Invalid namespace: $namespace');
  }
  if (reservedNamespaces.contains(namespace) && namespace != 'app') {
    throw ArgumentError('Reserved namespace: $namespace');
  }
}

String qualifyName({required String namespace, required String name}) {
  validateNamespace(namespace);
  if (name.startsWith('${namespace}_')) {
    throw ArgumentError('Bare name must not include namespace prefix: $name');
  }
  return '${namespace}_$name';
}
```

- [ ] **Step 3: Define `AgentIntentDescriptor` + `RegisteredAgentIntent`**

Per approved spec — **no** `abstract interface class AgentIntent` for authors.

```dart
@immutable
final class AgentIntentDescriptor { /* namespace, name, description, kind, inputSchema, methodName?, resourceUri?, mimeType? */ }

@immutable
final class AgentInvocation {
  final AgentIntentDescriptor descriptor;
  final AgentArguments arguments;
}

final class RegisteredAgentIntent {
  RegisteredAgentIntent({required this.descriptor, required AgentExecutor execute, ...});
  final AgentIntentDescriptor descriptor;
  String get qualifiedName => descriptor.qualifiedName;
  Future<AgentResult> execute(AgentInvocation invocation);
}
```

- [ ] **Step 4: `AgentAdapter` + `AgentModule` interfaces**

Copy signatures from design spec (`attach`, `detach`, `watchesRegistry` default `true`).

- [ ] **Step 5: Test qualifyName**

```dart
test('qualifyName prefixes namespace', () {
  expect(qualifyName(namespace: 'fmt', name: 'tap_widget'), 'fmt_tap_widget');
});
```

- [ ] **Step 6: Run tests and commit**

```bash
cd packages/agentkit_core && dart test && cd ../..
git add packages/agentkit_core pubspec.yaml
git commit -m "feat(agentkit): add descriptor, RegisteredAgentIntent, naming"
```

---

## Task 3: `InMemoryAgentRegistry` + events

**Files:**
- Create: `packages/agentkit_core/lib/src/registry/agent_registry.dart`
- Create: `packages/agentkit_core/lib/src/registry/in_memory_agent_registry.dart`
- Create: `packages/agentkit_core/lib/src/registry/registry_events.dart`
- Create: `packages/agentkit_core/test/in_memory_agent_registry_test.dart`

- [ ] **Step 1: Failing test — register and invoke**

```dart
test('invoke runs intent handler', () async {
  final registry = InMemoryAgentRegistry();
  registry.register(RegisteredAgentIntent(
    descriptor: AgentIntentDescriptor(namespace: 'demo', name: 'echo', ...),
    description: 'echo',
    kind: AgentIntentKind.tool,
    inputSchema: const {'type': 'object', 'properties': {}},
    executeFn: (inv) async => AgentResult.success(
      data: {'in': inv.arguments['x']},
    ),
  ));
  final out = await registry.invoke('demo_echo', {'x': 1});
  expect(out.ok, isTrue);
  expect(out.data['in'], 1);
});
```

- [ ] **Step 2: Implement registry**

Storage: `Map<String, RegisteredAgentIntent>`. On `register`, emit `IntentRegistered(qualifiedName)`. On collision, throw `AgentIntentCollisionError`. `invoke`:

1. Resolve registration
2. `registration.validate(arguments)`
3. `registration.execute(AgentInvocation(descriptor: registration.descriptor, arguments: ...))`

- [ ] **Step 3: Failing test — collision**

```dart
test('duplicate qualified name throws', () {
  final registry = InMemoryAgentRegistry();
  final intent = /* same name twice */;
  registry.register(intent);
  expect(() => registry.register(intent), throwsA(isA<AgentIntentCollisionError>()));
});
```

- [ ] **Step 4: Run tests, commit**

```bash
cd packages/agentkit_core && dart test
git commit -m "feat(agentkit): add InMemoryAgentRegistry"
```

---

## Task 4: `AgentCallEntry` (hand-written client path)

**Files:**
- Create: `packages/agentkit_core/lib/src/authoring/agent_call_entry.dart`
- Create: `packages/agentkit_core/test/agent_call_entry_test.dart`

- [ ] **Step 1: Implement `AgentCallEntry` (mirror `MCPCallEntry` shape)**

```dart
typedef AgentCallHandler = FutureOr<AgentResult> Function(AgentArguments request);

extension type const AgentCallEntry._(MapEntry<String, _AgentCallEntryValue> _entry) {
  factory AgentCallEntry.tool({
    required String namespace,
    required String name,
    required String description,
    required InputSchema inputSchema,
    required AgentCallHandler handler,
  }) => AgentCallEntry._(MapEntry(name, (
    namespace: namespace,
    description: description,
    inputSchema: inputSchema,
    handler: handler,
    kind: AgentIntentKind.tool,
    resourceUri: null,
    mimeType: null,
  )));

  RegisteredAgentIntent toRegistration() => RegisteredAgentIntent(
    descriptor: AgentIntentDescriptor(
      namespace: value.namespace,
      name: _entry.key,
      description: value.description,
      kind: value.kind,
      inputSchema: value.inputSchema,
      methodName: value.methodName,
      resourceUri: value.resourceUri,
      mimeType: value.mimeType,
    ),
    execute: (inv) => value.handler(inv.arguments),
  );
}

void registerAll(AgentRegistry registry, Iterable<AgentCallEntry> entries) {
  for (final entry in entries) {
    registry.register(entry.toRegistration());
  }
}
```

- [ ] **Step 2: Test `toRegistration` qualified name**

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(agentkit): add AgentCallEntry authoring"
```

---

## Task 5: `AgentRuntime`

**Files:**
- Create: `packages/agentkit_core/lib/src/runtime/agent_runtime.dart`
- Create: `packages/agentkit_core/test/agent_runtime_test.dart`

- [ ] **Step 1: Failing test — module + fake adapter**

```dart
final class EchoModule implements AgentModule {
  @override
  String get id => 'echo';
  @override
  Future<void> register(AgentRegistry registry) async {
    registry.register(/* echo intent */);
  }
  @override
  Future<void> dispose() async {}
}

final class RecordingAdapter implements AgentAdapter {
  final attached = <String>[];
  @override
  String get id => 'recording';
  @override
  Future<void> attach(AgentRegistry registry) async {
    attached.addAll(registry.list().map((i) => qualifyName(namespace: i.namespace, name: i.name)));
  }
  @override
  Future<void> detach() async {}
  @override
  bool get watchesRegistry => false;
}
```

- [ ] **Step 2: Implement `start()` / `stop()`**

Order: `modules.register` → `adapters.attach`. `stop()` reverses.

- [ ] **Step 3: Run tests, commit**

---

## Task 6: Bridge `ToolRegistration` → `RegisteredAgentIntent`

**Files:**
- Create: `packages/server_capability_kernel/lib/src/agent_bridge.dart`
- Create: `packages/server_capability_kernel/test/agent_bridge_test.dart`
- Modify: `packages/server_capability_kernel/pubspec.yaml` — add `agentkit_core`, `agentkit_schema`
- Modify: `packages/server_capability_kernel/lib/flutter_mcp_toolkit_capability_kernel.dart` — export bridge

- [ ] **Step 1: Add dependencies**

```yaml
dependencies:
  agentkit_core:
  agentkit_schema:
  dart_mcp: ^0.5.0
```

- [ ] **Step 2: Implement bridge**

```dart
RegisteredAgentIntent toolRegistrationToRegistration({
  required String capabilityId,
  required ToolRegistration registration,
}) {
  final qualified = applyPrefix(capabilityId: capabilityId, name: registration.name);
  return RegisteredAgentIntent(
    descriptor: AgentIntentDescriptor(
      namespace: capabilityId,
      name: registration.name,
      description: registration.description,
      kind: AgentIntentKind.tool,
      inputSchema: registration.inputSchema,
    ),
    execute: (inv) async {
      final mcpResult = await registration.handler(CallToolRequest(
        name: qualified,
        arguments: inv.arguments,
      ));
      return mcpResultToAgentResult(mcpResult);
    },
  );
}
```

Place `mcpResultToAgentResult` in bridge file temporarily (moves to `mcp_result_mapper.dart` in Task 7).

- [ ] **Step 3: Unit test round-trip**

Use a stub handler returning `CallToolResult(content: [TextContent(text: '{"a":1}')])` → expect `AgentResult.success` with decoded data.

- [ ] **Step 4: Commit**

---

## Task 7: `McpHost` dual-write + invoke via registry

**Files:**
- Create: `mcp_server_dart/lib/src/mcp_toolkit_server/agent_registry_host.dart`
- Create: `mcp_server_dart/lib/src/mcp_toolkit_server/mcp_result_mapper.dart`
- Modify: `mcp_server_dart/lib/src/mcp_toolkit_server/host.dart`
- Modify: `mcp_server_dart/lib/src/mcp_toolkit_server/server.dart`
- Modify: `mcp_server_dart/pubspec.yaml` — `agentkit_core`, `agentkit_schema`
- Create: `mcp_server_dart/test/agent_registry_host_test.dart`

- [ ] **Step 1: `mcp_result_mapper.dart`**

```dart
AgentResult mcpResultToAgentResult(CallToolResult result) { /* map TextContent/ImageContent */ }
CallToolResult agentResultToMcpResult(AgentResult result) { /* inverse */ }
```

- [ ] **Step 2: Extend `McpHost` with registry field**

```dart
final class McpHost {
  McpHost({...}) : agentRegistry = InMemoryAgentRegistry();
  final AgentRegistry agentRegistry;
}
```

In `_registerTool`, after storing `_RegisteredTool`:

```dart
agentRegistry.register(toolRegistrationToRegistration(
  capabilityId: capabilityId,
  registration: registration,
));
```

Change published MCP handler to:

```dart
bridge.publish(
  dart_mcp.Tool(...),
  (request) async {
    final result = await agentRegistry.invoke(
      fullName,
      request.arguments ?? const {},
    );
    return agentResultToMcpResult(result);
  },
);
```

**Important:** Remove direct call to `registration.handler` from MCP path to avoid double execution. The bridged `CallableAgentIntent` in registry must NOT call `registration.handler` when MCP path uses registry — use two intents or a flag:

**Preferred Phase 1 approach:** `RegisteredAgentIntent` executor calls the **business** handler only once:

- Extract handler body to `Future<AgentResult> Function(AgentArguments)` at bridge time by wrapping existing MCP handler without re-entering registry.

Simplest: store `ToolRegistration` in host; registry intent's `executeFn` calls `registration.handler` with synthetic `CallToolRequest`; MCP wrapper calls `registry.invoke` which calls same — **single path through registry only** (MCP publish uses registry.invoke, remove duplicate registration.handler call from publish lambda).

- [ ] **Step 3: Test — register capability tool, invoke registry, compare MCP**

Use fake `CommandRunner` in existing capability test pattern.

- [ ] **Step 4: Run full server tests**

```bash
cd mcp_server_dart && dart test test/agent_registry_host_test.dart test/flutter_mcp_toolkit_contract_test.dart -r expanded
```

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(server): route MCP tool calls through AgentRegistry"
```

---

## Task 8: `agentkit_testing` + MCP parity contract

**Files:**
- Create: `packages/agentkit_testing/pubspec.yaml`
- Create: `packages/agentkit_testing/lib/agentkit_testing.dart`
- Create: `packages/agentkit_testing/lib/src/registry_contract.dart`
- Create: `mcp_server_dart/test/agent_registry_mcp_parity_test.dart`

- [ ] **Step 1: Contract helper**

```dart
Future<void> expectRegistryMcpParity({
  required AgentRegistry registry,
  required Future<CallToolResult> Function(String name, Map<String, Object?> args) callMcp,
  required String qualifiedName,
  required Map<String, Object?> args,
}) async {
  final agent = await registry.invoke(qualifiedName, args);
  final mcp = await callMcp(qualifiedName, args);
  // assert semantic equality of payload (normalize JSON text)
}
```

- [ ] **Step 2: Parity test for one real tool**

Pick `fmt_get_app_errors` or smallest tool — use live `McpHost` with fmt capability registered.

- [ ] **Step 3: Commit**

---

## Task 9: Client SDK — `AgentCallEntry` in `mcp_toolkit`

**Files:**
- Create: `mcp_toolkit/lib/src/agent_call_entry.dart` (re-export from agentkit_core or thin wrapper)
- Modify: `mcp_toolkit/pubspec.yaml` — `agentkit_core`
- Modify: `mcp_toolkit/lib/mcp_toolkit.dart` — export `AgentCallEntry`
- Modify: `mcp_toolkit/lib/src/mcp_models.dart` — deprecation typedef

- [ ] **Step 1: Add dependency and export**

```dart
// mcp_toolkit/lib/src/mcp_models.dart
@Deprecated('Use AgentCallEntry from agentkit_core')
typedef MCPCallEntry = AgentCallEntry;
```

Keep existing `MCPCallEntry.tool` / `.resource` factories as forwarding constructors if needed for API stability.

- [ ] **Step 2: Migrate one toolkit entry to `AgentCallEntry` in docs only** (code optional in test app Task 10).

- [ ] **Step 3: `dart analyze mcp_toolkit`**

- [ ] **Step 4: Commit**

---

## Task 10: `agentkit_codegen` pilot (optional server + client)

**Files:**
- Create: `packages/agentkit_codegen/pubspec.yaml`
- Create: `packages/agentkit_codegen/lib/agentkit_codegen.dart`
- Create: `packages/agentkit_codegen/lib/src/annotations.dart`
- Create: `packages/agentkit_codegen/lib/src/agent_tool_generator.dart`
- Create: `packages/server_capability_core/lib/src/tools/wait_tools_agent.dart` (annotated source)
- Create: `flutter_test_app/lib/agent_tools/demo_loyalty_tool.dart`
- Modify: `packages/server_capability_core/build.yaml`, `flutter_test_app/pubspec.yaml`

- [ ] **Step 1: Annotations**

```dart
class AgentTool {
  const AgentTool({required this.namespace, required this.name});
  final String namespace;
  final String name;
}

class AgentParam {
  const AgentParam(this.description);
  final String description;
}
```

- [ ] **Step 2: Generator outputs `*.agent.g.dart`**

For each `@AgentTool` function, emit:

- `RegisteredAgentIntent get $nameRegistration => ...`
- `const inputSchema = {...}` from parameters (String, int, bool, optional)

Use `package:source_gen` + `build_runner`. Start with **one parameter type set**; expand in Phase 2.

- [ ] **Step 3: Server pilot — `wait_tools_agent.dart`**

Annotate `wait` tool handler (smallest schema). Generated intent registered alongside existing `registerWaitTools` during transition, or replace handler body to call generated intent only.

- [ ] **Step 4: Client pilot — `flutter_test_app`**

```dart
@AgentTool(namespace: 'app', name: 'demo_ping')
Future<AgentResult> demoPing(@AgentParam('Message') String message) async {
  return AgentResult.success(data: {'pong': message});
}
```

Document in comment: **codegen is optional**; hand-written `AgentCallEntry` remains valid.

- [ ] **Step 5: Run build**

```bash
cd packages/server_capability_core && dart run build_runner build --delete-conflicting-outputs
cd ../../flutter_test_app && dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 6: Commit**

```bash
git commit -m "feat(agentkit): add optional @AgentTool codegen pilot"
```

---

## Task 11: Documentation

**Files:**
- Modify: `docs/superpowers/specs/2026-05-25-agentkit-design.md` — status → Approved
- Create: `packages/agentkit_core/README.md`
- Modify: `docs/guides/creating_dynamic_tools.mdx` — mention `AgentCallEntry` + optional codegen

- [ ] **Step 1: README for agentkit_core** — authoring table (hand-written vs codegen, server vs client)

- [ ] **Step 2: Short architecture pointer in `docs/core/project_architecture.mdx`**

- [ ] **Step 3: Commit**

```bash
git commit -m "docs: agentkit Phase 1 authoring and architecture"
```

---

## Task 12: Phase 1 exit verification

- [ ] **Step 1: Full test suite**

```bash
cd /Users/anton/mcp/mcp_flutter
dart test packages/agentkit_schema
dart test packages/agentkit_core
dart test packages/server_capability_kernel
cd mcp_server_dart && dart test
```

- [ ] **Step 2: CLI smoke**

```bash
cd mcp_server_dart
dart run bin/flutter_mcp_cli.dart schema --name fmt_wait
dart run bin/flutter_mcp_cli.dart capabilities
```

Expected: tool still listed; schema unchanged.

- [ ] **Step 3: Contract test green**

`flutter_mcp_toolkit_contract_test.dart` passes.

- [ ] **Step 4: Update design spec status to Implemented (Phase 1)**

---

## Spec coverage checklist (Phase 1)

| Spec requirement | Task |
|------------------|------|
| `agentkit_schema` | Task 1 |
| `agentkit_core` registry/runtime | Tasks 2–5 |
| Hand-written `AgentCallEntry` | Tasks 4, 9 |
| Optional codegen server + client | Task 10 |
| Bridge `ToolRegistration` | Task 6 |
| MCP invoke via registry | Task 7 |
| Preserve `fmt_*` names | Task 6–7 (use `applyPrefix`) |
| MCP parity tests | Task 8 |
| No `dart_mcp` removal from kernel yet | Deferred Phase 2 |
| Multi-adapter runtime | `AgentRuntime` + `AgentAdapter` stub only; full MCP adapter extract Phase 2 |
| `CoreCommand` separate | Documented; no change to executor in Phase 1 |

---

## Phase 2 preview (not in this plan)

- Extract `agentkit_mcp` package; delete `DartMcpDispatchBridge` from host
- `DynamicRegistry` stores `AgentIntent`
- Remove `dart_mcp` from `server_capability_kernel`

---

## Key design decisions (locked)

- Codegen optional on **server and client**
- Single invoke path: `registry.invoke` for MCP-published tools
- `CoreCommand` unchanged for VM/session
- In-repo path deps until separate agentkit repo (Phase 3)
