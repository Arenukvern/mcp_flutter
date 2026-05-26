# flutter_mcp_toolkit_capability_core

Core MCP capability (`fmt`) for [Flutter MCP Toolkit](https://github.com/Arenukvern/mcp_flutter): VM inspection, UI interaction, navigation, logs, diagnostics, and hot-reload coordination.

Server-side Dart only — no Flutter SDK dependency.

## Install

```yaml
dependencies:
  flutter_mcp_toolkit_capability_core: ^0.1.0
  flutter_mcp_toolkit_capability_kernel: ^0.1.0
  flutter_mcp_toolkit_core: ^0.1.0
```

## Usage

```dart
import 'package:flutter_mcp_toolkit_capability_core/flutter_mcp_toolkit_capability_core.dart';

final capability = FmtCapability(/* host services */);
```

## Adding tools with `@AgentTool` (Phase 6c pilot)

Optional codegen via `agentkit_codegen` + `build_runner`. Hand-written
`ToolRegistration` remains first-class.

1. Add deps (`agentkit_codegen`, `agentkit_core`, `agentkit_mcp`) and
   `build_runner` dev_dep (see `pubspec.yaml`).
2. Annotate a top-level function returning `Future<AgentResult>`:

```dart
part 'my_tool.g.dart';

@AgentTool(namespace: 'fmt', name: 'my_tool', description: '...')
Future<AgentResult> fmtMyTool(@AgentParam('...') String arg) async { ... }
```

3. Run `dart run build_runner build` in this package.
4. Register through the host path:

```dart
context.registerTool(
  agentCallEntryToToolRegistration(
    myToolCallEntry,
    mergeInputSchema: (schema) => { /* e.g. connection override */ ...schema },
    handler: (args) => runCommand(runner, args, MyCommand(...)),
  ),
);
```

Pilot: `lib/src/tools/codegen/get_recent_logs_tool.dart` → `get_recent_logs`.

## Monorepo development

`pubspec_overrides.yaml` resolves sibling packages from local paths (not published).

## Pub.dev publishing checklist

| Requirement | Status |
|-------------|--------|
| `LICENSE`, `README.md`, `CHANGELOG.md` | Included |
| Hosted sibling deps in `pubspec.yaml` | kernel + core `^0.1.0` |
| Publish **after** kernel and core `0.1.0` on pub.dev | Required |
| `dart pub publish --dry-run` | Run before release |

## License

MIT — see [LICENSE](LICENSE).
