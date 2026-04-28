# T3 Migration Inventory (deleted at end of T3)

## flutter_live_edit_toolkit/lib/src/models/

| File | Pure Dart? | Server uses? | Action |
|---|---|---|---|
| `models.dart` (barrel) | yes | yes (via `live_edit_models.dart` re-export) | replace with re-export |
| `live_edit_models.dart` | yes | yes (direct) | move |
| `live_edit_models.freezed.dart` | yes (generated) | no (generated) | regen in new location |
| `live_edit_models.g.dart` | yes (generated) | no (generated) | regen in new location |
| `live_edit_interaction_models.dart` | yes | no (but used by live_edit_models.dart) | move |
| `live_edit_flow_graph_helpers.dart` | yes | no | move |
| `live_edit_schemas.dart` | yes | no | move |
| `live_edit_timeline_pipeline_primitives.dart` | yes | no | move |

## live_edit_tooling_ui_kit/lib/src/models/

| File | Pure Dart? | Server uses? | Action |
|---|---|---|---|
| `models.dart` (source, not barrel) | yes | yes (direct, via private import) | move |
| `models.freezed.dart` | yes (generated) | no | regen in new location |
| `models.g.dart` | yes (generated) | no | regen in new location |

## Server import set (must be exported from live_edit_models)

From `mcp_server_dart/lib/src/capabilities/live_edit/live_edit_command_executor.dart`:
- `package:flutter_live_edit_toolkit/src/models/live_edit_models.dart` → all types therein
- `package:live_edit_tooling_ui_kit/src/models/models.dart` → `LiveEditBounds`, `LiveEditEditMode`

From `mcp_server_dart/lib/src/mcp_toolkit_server/handlers/live_edit_handler.dart`:
- `package:flutter_live_edit_toolkit/src/models/live_edit_models.dart` → all types therein

From `mcp_server_dart/lib/src/shared_core/commands/commands.dart`:
- `package:flutter_live_edit_toolkit/src/models/live_edit_models.dart` → all types therein

## Dependency order for migration (important: move foundational first)

1. `live_edit_tooling_ui_kit/models.dart` → `live_edit_models/lib/src/models.dart`
   (provides `LiveEditBounds`, `LiveEditEditMode` — no deps on other live-edit files)

2. All toolkit model files together (they form a closed set of cross-imports):
   - `live_edit_models.dart` → `live_edit_models/lib/src/live_edit_models.dart`
   - `live_edit_interaction_models.dart` → `live_edit_models/lib/src/live_edit_interaction_models.dart`
   - `live_edit_flow_graph_helpers.dart` → `live_edit_models/lib/src/live_edit_flow_graph_helpers.dart`
   - `live_edit_schemas.dart` → `live_edit_models/lib/src/live_edit_schemas.dart`
   - `live_edit_timeline_pipeline_primitives.dart` → `live_edit_models/lib/src/live_edit_timeline_pipeline_primitives.dart`

## Notes on taint check

`grep -rn "dart:ui\|package:flutter/" flutter_live_edit/flutter_live_edit_toolkit/lib/src/models/ flutter_live_edit/live_edit_tooling_ui_kit/lib/src/models/`
Result: empty → ALL model files are pure Dart. No splitting required.
