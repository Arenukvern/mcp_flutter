# Live Edit — contract (single source of truth)

**Authoritative definitions** live in the Dart package **`flutter_live_edit_core`**:

- **Domain models & JSON** — `LiveEditSchemas`, Freezed types in `lib/src/live_edit_models.dart`.
- **MCP tool name strings** — `LiveEditMcpToolNames` (Flutter Inspector MCP server / command catalog).
- **In-app MCP bridge tool names** — `LiveEditRuntimeToolNames` (tools registered inside the running app via `mcp_toolkit`).

Do not duplicate tool name literals in docs or other packages; import from core or regenerate this document from code.

---

## Glossary: “property” and related terms

| Term                                          | Meaning                                                                                                 | Not                                               |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| **JSON Schema `properties`**                  | Standard schema keyword for object fields.                                                              | Widget “properties” in the Flutter sense.         |
| **Inspector `properties` / `propertiesTree`** | Serialized widget field values for **AI context** (see `LiveEditSelection`).                            | End-user property editing in the product UI.      |
| **`live_edit_get_property_panel`**            | MCP command returning **read-only** normalized panel payload for the current selection (model context). | A property editor or direct mutation API.         |
| **`propertyId` (draft)**                      | Identifier tying a draft change to an inspector field in agent flows.                                   | User-facing “property” branding in the PRD sense. |

---

## Namespace A — MCP server (`live_edit_*`)

Exposed by **Flutter Inspector MCP Server** (`mcp_server_dart`): same strings as `LiveEditMcpToolNames` in core. These commands run **through the server executor** (VM connection, `LiveEditAgentService` on the server for resolve/apply, etc.).

Full set: use `LiveEditMcpToolNames.allSorted` in tests or grep `LiveEditMcpToolNames` in `flutter_live_edit_core`.

---

## Namespace B — In-app runtime bridge (`live_edit_runtime_*` + shared selector)

Registered by **`flutter_live_edit_toolkit`** for calls **into the running isolate** via `getFlutterLiveEditEntries()`:

| Logical action  | Constant                                 | Wire name                                        |
| --------------- | ---------------------------------------- | ------------------------------------------------ |
| Start session   | `LiveEditRuntimeToolNames.startSession`  | `live_edit_runtime_start_session`                |
| Set overlay     | `LiveEditRuntimeToolNames.setOverlay`    | `live_edit_runtime_set_overlay`                  |
| Widget tree     | `LiveEditRuntimeToolNames.getTree`       | `live_edit_runtime_get_tree`                     |
| Select at point | `LiveEditRuntimeToolNames.selectAtPoint` | `select_widget_at_point` (shared with inspector) |
| Get selection   | `LiveEditRuntimeToolNames.getSelection`  | `live_edit_runtime_get_selection`                |
| Update draft    | `LiveEditRuntimeToolNames.updateDraft`   | `live_edit_runtime_update_draft`                 |
| Get draft       | `LiveEditRuntimeToolNames.getDraft`      | `live_edit_runtime_get_draft`                    |
| Discard draft   | `LiveEditRuntimeToolNames.discardDraft`  | `live_edit_runtime_discard_draft`                |
| End session     | `LiveEditRuntimeToolNames.endSession`    | `live_edit_runtime_end_session`                  |

**Why two namespaces?** Server tools orchestrate session + agent + VM; runtime tools are the narrow bridge to app state. Names differ on purpose to avoid collisions and to make logs unambiguous. Unifying wire names would be a **semver** change for all MCP clients.

---

## Mapping (overlap concepts)

| Concept                  | Server tool (`LiveEditMcpToolNames`)                                       | Runtime bridge (`LiveEditRuntimeToolNames`) |
| ------------------------ | -------------------------------------------------------------------------- | ------------------------------------------- |
| Session start            | `live_edit_start_session`                                                  | `live_edit_runtime_start_session`           |
| Overlay                  | `live_edit_set_overlay`                                                    | `live_edit_runtime_set_overlay`             |
| Tree                     | `live_edit_get_tree`                                                       | `live_edit_runtime_get_tree`                |
| Selection                | `live_edit_get_selection`                                                  | `live_edit_runtime_get_selection`           |
| Draft update/get/discard | `live_edit_update_draft`, `live_edit_get_draft`, `live_edit_discard_draft` | `live_edit_runtime_*` counterparts          |
| End session              | `live_edit_end_session`                                                    | `live_edit_runtime_end_session`             |
| Select at point          | `live_edit_select_at_point`                                                | `select_widget_at_point`                    |

Server-only (no runtime twin in `LiveEditRuntimeToolNames`): prepare session, capabilities, candidates, active selection, property panel, edit mode, preview, backends, resolve, apply draft, accept/reject resolution, etc.

---

## Package boundaries

- **`flutter_live_edit_core`** — types + tool name constants only (no Flutter).
- **`flutter_live_edit_agent`** — server-side agent orchestration; depended on by **`mcp_server_dart`** and by **`flutter_live_edit_toolkit`** only for **auto/bootstrap** wiring (`live_edit_auto*.dart`), not for typical app UI code paths.
- **`flutter_live_edit_toolkit`** — overlay, scope, commands, MCP registration for the app.
- **`live_edit_tooling_ui_kit`** — widgets + view models; depends on **core** only.

See [BOUNDARIES.md](BOUNDARIES.md) for the toolkit ↔ agent dependency rationale.
