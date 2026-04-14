# flutter_live_edit

In-app Live Edit runtime for Flutter: an overlay that lets an AI agent target,
instruct, plan, and apply changes against a running app. Ships as three
packages plus a playground.

## Packages

| Path                                | Purpose                                                                                                                                                                           |
| ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `flutter_live_edit_toolkit/`        | Full toolkit — overlay, scope/host, Commands, Resources, Services, MCP runtime bridge (`getFlutterLiveEditEntries`), AI backend wiring, and domain models. Depends on mcp_toolkit. |
| `live_edit_tooling_ui_kit/`         | View-model + callback driven widgets (bubble, panel, chips). No toolkit dependency — reusable in isolation for UI iteration.                                                      |
| `live_edit_tooling_ui_kit_playground/` | Runnable app that renders the UI kit with prefilled view-models for fast widget iteration without a connect/bootstrap cycle.                                                   |

There is no separate `flutter_live_edit_core` or `flutter_live_edit_agent`
package anymore — domain models, MCP tool names, and agent orchestration live
inside `flutter_live_edit_toolkit`.

## Integration

Minimal entrypoint:

```dart
import 'package:flutter_live_edit_toolkit/live_edit_facade.dart';
// or for commands/selectors/types:
import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';
```

- `FlutterLiveEditHost` — host widget that composes overlay + child.
- `LiveEditScope` — provides `LiveEditContext` (Resources + Services).
- `bootstrapFlutterLiveEditApp(...)` — opinionated bootstrap wiring for apps
  that want the MCP auto-host path.
- `getFlutterLiveEditEntries()` — registers the in-app MCP runtime bridge
  (`live_edit_runtime_*` tools) via `mcp_toolkit`.

The MCP server side (`live_edit_*` server tools, catalog, executor) lives in
`mcp_server_dart`; the toolkit is its in-app counterpart.

## Architecture

Command–Resource pattern (see repo `ARCHITECTURE.md`):

```
UI → Command(context) → Service → Resource → UI
```

- **Resources** (`lib/src/resources/`) hold immutable state — `ValueNotifier<Data>`.
- **Commands** (`lib/src/commands/`) take only `LiveEditContext`; no Controller parameter.
- **Services** (`lib/src/services/`) are focused capabilities called from Commands (apply, bubble state, session, hit-test, layout, worktree).
- **DI**: Resources + Services registered once in `LiveEditScope` / orchestrator.

Domain models are Freezed (`lib/src/models/`).

## UI iteration without a running target

For refining bubble/panel/chip widgets, run
`live_edit_tooling_ui_kit_playground` — it renders the tool layer with
prefilled data, so you don't need a full connect cycle. Main hit-testing
domain is `appScene` (see root `ARCHITECTURE.md` → "Live Edit Overlay").

## Tests

```bash
cd flutter_live_edit_toolkit && flutter test
cd live_edit_tooling_ui_kit && flutter test
```

The toolkit test suite lives in `flutter_live_edit_toolkit/test/` and covers
Commands, Services, Resources, overlay/panel/bubble behavior, flow graph
primitives, protocol v2, worktree, and LRU caches.
