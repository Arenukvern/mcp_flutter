> ⚠️ **Pre-release (0.1.x)** — Highly experimental. APIs may change without notice. Not for production. [Details](../../PRE_RELEASE.md).


# agentkit_codegen

Optional `@AgentTool` / `@AgentParam` annotations and **build_runner** codegen pilot (Phase 5-C).

Hand-written `AgentCallEntry` remains first-class; codegen is opt-in for stable tools with typed parameters.

## Pilot usage

1. Add dependency:

```yaml
dependencies:
  agentkit_codegen:
    path: ../agentkit_codegen
  agentkit_core:
  agentkit_schema:

dev_dependencies:
  build_runner: ^2.4.15
```

2. Annotate a top-level function:

```dart
import 'package:agentkit_codegen/agentkit_codegen.dart';
import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_schema/agentkit_schema.dart';

part 'my_tools.g.dart';

@AgentTool(namespace: 'app', name: 'demo_ping', description: 'Ping')
Future<AgentResult> demoPing(@AgentParam('Message') String message) async {
  return AgentResult.success(data: {'pong': message});
}
```

3. Run codegen:

```bash
dart run build_runner build --delete-conflicting-outputs
```

4. Register generated intent:

```dart
registry.register(demoPingRegistration);
// or
registerAll(registry, {demoPingCallEntry});
```

## Generated output

For each `@AgentTool` function, `.g.dart` emits:

- `_<name>InputSchema` — JSON Schema from parameter types
- `<name>CallEntry` — `AgentCallEntry.tool(...)` factory
- `<name>Registration` — `RegisteredAgentIntent` via `.toRegistration()`

Supported parameter types: `String`, `int`, `bool`, `double`.

## Scope (pilot)

- Top-level functions only
- Tool kind only (resources: hand-write `AgentCallEntry.resource`)
- Test fixture: `test/fixtures/demo_ping_tool.dart`

See [agentkit design](https://github.com/Arenukvern/mcp_flutter/blob/main/docs/superpowers/specs/2026-05-25-agentkit-design.md) (declarative authoring).