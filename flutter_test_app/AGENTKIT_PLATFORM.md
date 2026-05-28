# Agentkit platform hooks (flutter_test_app)

Dogfood project for in-repo agentkit platform sync and one-time hooks.

## One-time hooks

From repo root:

```bash
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart init agentkit-platform \
  --project-dir flutter_test_app
```

CI / drift check (same paths as `make check-contracts`):

```bash
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart init agentkit-platform \
  --project-dir flutter_test_app --check
```

Patches (idempotent markers `agentkit-platform: begin` … `end`):

| Target | Content |
|--------|---------|
| `web/index.html` | WebMCP generated JS script tag |
| `android/app/build.gradle.kts` | `preBuild` → `codegen sync --platform android` |
| `android/.../AndroidManifest.xml` | `android.app.shortcuts` meta-data |
| `ios/agentkit_codegen.sh` / `macos/agentkit_codegen.sh` | Shell script for Xcode Run Script |
| Xcode `project.pbxproj` | Manual Run Script phase (see script file) if not auto-injected |

## Pub resolution

`mcp_toolkit` pulls platform emitters; dogfood adds `agentkit_platform` for `AgentkitInvokeLinkListener` (`app_links`).

```yaml
# Root pubspec.yaml applies dependency_overrides to agentkit workspace:
dependency_overrides:
  agentkit_core:
    path: ../agentkit/packages/agentkit_core
  agentkit_schema:
    path: ../agentkit/packages/agentkit_schema
```

## Manifest workflow

Canonical descriptor list: `web/agent_manifest.json` (project root copy also accepted).

Regenerate artifacts:

```bash
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart codegen sync \
  --platform web,android,ios,macos,linux,windows \
  --project-dir flutter_test_app
```

`generateWebAgentManifest` in `agentkit_platform` is available for tooling; this app maintains `web/agent_manifest.json` by hand and runs `codegen sync` (see `PlatformSync.readManifest` errors).

## Web invoke

- **WebMCP + Dart bootstrap:** `web/index.html` loads `agentkit_webmcp.generated.js` for early discovery; `mcp_toolkit` calls `registerAgentWebMcpFromEntries` after `addEntries`, installing `globalThis.__agentkitWebMcpDartExecute` so JS-registered tools invoke `AgentCallEntry.invokeDirect` (full schema validation) even when Dart `registerTool` loses the duplicate-name race. JS `execute` runs `validateInput` (required, `additionalProperties: false`, primitive types, min/max) before fetch fallback; nested objects are not recursively validated in JS.
- **WebMcpPublishAdapter dogfood:** `lib/agent_web_mcp_dogfood.dart` attaches registry hot-sync for dogfood entries on web.
- **macOS validate-runtime:** `make showcase` then `make macos-validate-runtime` with `MACOS_WS_URI` set.
- **Enable WebMCP on Chrome (repeatable):** `make web-showcase` or `dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart webmcp chrome-args` then `webmcp verify --web-port 8080`. See [WebMCP verification](../docs/superpowers/evals/2026-05-26-webmcp-verification.md).
- **PWA `/agent/invoke`:** emitted in manifest/JS; no Flutter route required ([ADR 0008](../decisions/0008_web_agent_invoke_js_only.mdx)).

## Native invoke (dogfood)

`AgentkitInvokeLinkListener` in `lib/main.dart` logs `agentkit://invoke/<qualifiedName>` via `app_links` (Android/iOS/desktop).

## CLI exec vs MCP tool names

`flutter-mcp-toolkit exec` accepts **bare** catalog names and **`fmt_`-prefixed** aliases (e.g. `get_recent_logs` and `fmt_get_recent_logs` both work). MCP wire tools and MCP clients (Cursor, Claude, etc.) use the **`fmt_` prefix** on host/catalog tools.

| Exec (`exec --name …`) | MCP / `tools/call` name |
|------------------------|-------------------------|
| `get_recent_logs` | `fmt_get_recent_logs` |
| `semantic_snapshot` | `fmt_semantic_snapshot` |
| `tap_widget` | `fmt_tap_widget` |
| `capture_ui_snapshot` | `fmt_capture_ui_snapshot` |
| `get_screenshots` | `fmt_get_screenshots` |
| `list_client_tools_and_resources` | `fmt_list_client_tools_and_resources` |
| `client_tool` | `fmt_client_tool` |

App-registered dynamic tools (from `AgentCallEntry` via `addEntries`) are listed by **`fmt_list_client_tools_and_resources`** and invoked with **`fmt_client_tool`** using the **`name` field** from the listing (e.g. `dogfood_ping`, not `app_dogfood_ping`). The qualified descriptor is `{namespace}_{name}` for docs/registry; the VM extension is `ext.mcp.toolkit.<name>`.

**Inspection tools — app dynamic name vs host catalog (`exec` / `fmt_*`):** Flutter toolkit entries in `flutter_mcp_toolkit.dart` keep legacy VM extension short names; CLI catalog and MCP host tools use `get_*` prefixes. Schemas are the same (`getAppErrorsInputSchema`, `getViewDetailsInputSchema`, `getScreenshotsInputSchema` in `interaction_input_schemas.dart`).

| App dynamic / `fmt_client_tool` `name` | VM extension suffix | CLI `exec` / schema router | MCP / `fmt_*` |
|----------------------------------------|---------------------|----------------------------|---------------|
| `app_errors` | `app_errors` | `get_app_errors` | `fmt_get_app_errors` |
| `view_details` | `view_details` | `get_view_details` | `fmt_get_view_details` |
| `view_screenshots` | `view_screenshots` | `get_screenshots` | `fmt_get_screenshots` |

Phase C cold-path metadata (`dogfood_reconstruct_start`, job `reconstruct.start`) is **app-side only** — same pattern as `dogfood_visual_reconstruct_info`; no bundled `fmt_*` tool in `mcp_server_dart`. See [deconstruct verification](../../docs/superpowers/evals/2026-05-26-deconstruct-verification.md).

**Schema validation (by path):**

| Path | When args are validated | Schema source |
|------|-------------------------|---------------|
| **`fmt_client_tool`** | Before VM extension call | `inputSchema` from `fmt_list_client_tools_and_resources` (app `registerDynamics`) |
| **CLI `exec`** (catalog commands) | In `CommandCatalog.buildCommand` before `spec.build` (coerce + Tier A via `validationFailureForInteractionCatalogCommand`) | Shared factories in `interaction_input_schemas.dart` for [tier A exec catalog commands](#tier-a-exec-catalog-22-tools) (22: 18 core + 4 inspection) plus two capture tools on the same router (24 total in `interactionCatalogInputSchemaFor`); other catalog commands use catalog `inputSchema` (unknown keys only unless schema is strict) |
| **MCP `fmt_*` interaction tools** | `RegisteredAgentIntent.validate` (Tier A) on `tools/call` before handler; no `coerceArgumentsForSchema` on this path (MCP args are already JSON) | Same shared factories as `exec` for those commands; handlers may still apply optional-field defaults after validate (`handler_helpers.dart`) — unlike **`fmt_client_tool` / registry** which coerce wire-shaped args before Tier A |

`exec --args` rejects wrong keys, missing `required` fields, and extra properties when `additionalProperties: false` for interaction catalog commands (e.g. `tap_widget` without `ref` fails before execute). Using an MCP-prefixed name on exec (e.g. `fmt_get_recent_logs` as `--name`) still resolves to the bare catalog name when supported. For end-to-end contract regressions (authoring → discovery → validation → execute, dual `fmt_*` vs app dynamic paths), use skill **`flutter-mcp-boundary-audit`** (`plugin/skills/flutter-mcp-boundary-audit/`).

**Dynamic vs `fmt_*` schema parity:** The **core interaction catalog** (18 tools below) plus **host inspection/capture** tools share canonical JSON Schema factories in `packages/core/lib/src/tools/interaction_input_schemas.dart` (`interactionCatalogInputSchemaFor` — 24 command names; see `coreInteractionCatalogCommandNames`, `tierAExecCatalogCommandNames`, `captureTierAExecCommandNames` in that file). Factories are used by `mcp_toolkit` app dynamic entries (`interaction_toolkit.dart` → `registerDynamics` where registered), `server_capability_core` catalog tools (`fmt_*`), and CLI `exec` fail-closed validation. All include `connection` override where applicable and set `additionalProperties: false`.

### Core interaction catalog (18 tools)

| App / `exec` name | Schema factory | MCP / `fmt_*` |
|-------------------|------------------|---------------|
| `tap_widget` | `tapWidgetInputSchema` | `fmt_tap_widget` |
| `semantic_snapshot` | `semanticSnapshotInputSchema` | `fmt_semantic_snapshot` |
| `wait_for` | `waitForInputSchema` | `fmt_wait_for` |
| `enter_text` | `enterTextInputSchema` | `fmt_enter_text` |
| `scroll` | `scrollInputSchema` | `fmt_scroll` |
| `long_press` | `longPressInputSchema` | `fmt_long_press` |
| `swipe` | `swipeInputSchema` | `fmt_swipe` |
| `drag` | `dragInputSchema` | `fmt_drag` |
| `hover` | `hoverInputSchema` | `fmt_hover` |
| `press_key` | `pressKeyInputSchema` | `fmt_press_key` |
| `get_recent_logs` | `getRecentLogsInputSchema` | `fmt_get_recent_logs` |
| `handle_dialog` | `handleDialogInputSchema` | `fmt_handle_dialog` |
| `navigate` | `navigateInputSchema` | `fmt_navigate` |
| `fill_form` | `fillFormInputSchema` | `fmt_fill_form` |
| `evaluate_dart_expression` | `evaluateDartExpressionInputSchema` | `fmt_evaluate_dart_expression` |
| `hot_reload_flutter` | `hotReloadFlutterInputSchema` | `fmt_hot_reload_flutter` |
| `hot_restart_flutter` | `hotRestartFlutterInputSchema` | `fmt_hot_restart_flutter` |
| `hot_reload_and_capture` | `hotReloadAndCaptureInputSchema` | `fmt_hot_reload_and_capture` |

### Tier A exec catalog (22 tools)

Eighteen core tools above plus four inspection commands on the host `fmt_*` / CLI `exec` router (`interactionCatalogInputSchemaFor`). Three are also **app-dynamic** under legacy VM extension names (alias table above): `app_errors`, `view_details`, `view_screenshots`. `inspect_widget_at_point` is registered on **both** paths under the same name. `focus_window` is **host-catalog only** (no `AgentCallEntry` / `registerDynamics` twin).

| App dynamic / `fmt_client_tool` `name` | CLI `exec` / schema router | Schema factory | MCP / `fmt_*` |
|----------------------------------------|----------------------------|----------------|---------------|
| `app_errors` | `get_app_errors` | `getAppErrorsInputSchema` | `fmt_get_app_errors` |
| `view_details` | `get_view_details` | `getViewDetailsInputSchema` | `fmt_get_view_details` |
| `inspect_widget_at_point` | `inspect_widget_at_point` | `inspectWidgetAtPointInputSchema` | `fmt_inspect_widget_at_point` |
| `select_widget_at_point` | — (app dynamic only) | `selectWidgetAtPointInputSchema` | — |
| — | `focus_window` | `focusWindowInputSchema` | `fmt_focus_window` |

**`select_widget_at_point` vs `inspect_widget_at_point`:** Both are app-dynamic (`getFlutterMcpToolkitEntries` / `registerDynamics`). `inspect_widget_at_point` is also on the host `fmt_*` / CLI `exec` router (tier A exec). `select_widget_at_point` is **app-only** — same `x`/`y`/`viewId`/`connection` base as inspect, plus optional live-edit fields (`sessionId`, `selectionPolicy`, `targetDomain`); not in `interactionCatalogInputSchemaFor`. Prefer `inspect_widget_at_point` / `fmt_inspect_widget_at_point` from the host; use `select_widget_at_point` via `fmt_client_tool` when live-edit selection is required.

Two additional capture commands use the same `interactionCatalogInputSchemaFor` router (24 total) but are not part of the 22-tool tier A exec set:

| App dynamic / `fmt_client_tool` `name` | CLI `exec` / schema router | Schema factory | MCP / `fmt_*` |
|----------------------------------------|----------------------------|----------------|---------------|
| `view_screenshots` | `get_screenshots` | `getScreenshotsInputSchema` | `fmt_get_screenshots` |
| — | `capture_ui_snapshot` | `captureUiSnapshotInputSchema` | `fmt_capture_ui_snapshot` |

Parity regressions: `mcp_toolkit/test/interaction_toolkit_schema_parity_test.dart` (13 interaction app-dynamic twins), `mcp_toolkit/test/flutter_mcp_toolkit_schema_parity_test.dart` (inspection app-dynamic twins including `select_widget_at_point`), `mcp_toolkit/test/inspection_toolkit_schema_parity_test.dart` (`app_errors`, `view_details`, `view_screenshots`, `inspect_widget_at_point`), `packages/server_capability_core/test/tools/interaction_input_schemas_test.dart` (18 core + tier A / router counts), `mcp_server_dart/test/interaction_catalog_validation_test.dart` (exec Tier A).

**Server catalog only (not app-dynamic):** `fill_form`, `hot_reload_flutter`, `hot_restart_flutter`, `evaluate_dart_expression`, `hot_reload_and_capture`, and `focus_window` are registered on the host `fmt_*` path (`interaction_tools.dart`, `flutter_inspector_tools.dart`, etc.) and CLI `exec`, but not in `interaction_toolkit` / `registerDynamics`. They still use the shared `interaction_input_schemas.dart` factories for Tier A parity between MCP and CLI.

## Validation tiers

Boundaries stack **different validators** on the same logical tool. Agents should assume the **strictest tier on their path** applies; do not infer permissive behavior from a weaker tier (e.g. JS `required`-only checks).

### Tier A — `validateAgainstSchema` (agentkit_schema)

Shared Dart validator used anywhere arguments are already a JSON object (`Map<String, Object?>`):

| Check | Behavior |
|-------|----------|
| Root | Must be `type: object` |
| `required` | Each listed key must be present |
| `additionalProperties: false` | Rejects unknown top-level keys |
| Property `type` | `string`, `integer`, `number`, `boolean`, `object`, `array` |
| `enum` | On `string` properties when the schema includes a JSON `enum` array (e.g. scroll `direction`, screenshot `mode`) |
| `minimum` / `maximum` | On `integer` and `number` only |
| Array `items` | When `items` is `type: object` with `required` / `properties`, each element is validated (same object rules as root) |
| Nested `object` properties | Presence/type only; no recursive validation of `properties` on plain object-typed fields |

**Not validated today:** `pattern`, `format`, nested object property validation (except array `items` object elements above), `oneOf` / `anyOf`, type coercion (use `coerceArgumentsForSchema` before Tier A on wire paths). Properties without a `type` are skipped. Catalog-only `inputSchema` fields without a Tier A shared factory are not enum-checked on CLI `exec` (Tier C). See dartdoc on `validateAgainstSchema` in `agentkit_schema`.

**Call sites:** `AgentCallEntry.invokeDirect` → coerce then `validate`; `RegisteredAgentIntent.validate` (MCP `fmt_*` catalog, no wire coerce); `DynamicRegistry.forwardToolCall` → coerce then `validate`; `VmExtensionDynamicGateway` → `validationFailureForDynamicSchema` (coerce + Tier A) before VM service extension calls; CLI `exec` interaction catalog → same helper as gateway.

### Tier B — Dynamic listing (`fmt_list_client_tools_and_resources` → `fmt_client_tool`)

App isolate advertises tools through `registerDynamics` (full `descriptor.inputSchema` per entry). Host path:

1. **Discovery** — `fmt_list_client_tools_and_resources` / registry stores each tool’s `inputSchema` (`inputSchemaFromMcpTool` fails closed if missing).
2. **MCP / `fmt_client_tool`** — `forwardToolCall` coerces then runs Tier A on the **inner** `arguments` object for the listed tool name (bare `name` from listing, not `app_*` qualified prefix).
3. **VM gateway** — `VmExtensionDynamicGateway` coerces then runs Tier A via `validationFailureForDynamicSchema` before `ext.mcp.toolkit.<name>`.
4. **App VM callback** — `mcp_toolkit_extensions` `registerServiceExtension` coerces wire args then validates before the entry handler.

Wire note: VM service extensions use string-key maps on the wire. **App** paths (`registerServiceExtension`, `invokeDirect`) and **host** paths (`forwardToolCall`, `VmExtensionDynamicGateway`) all run `coerceArgumentsForSchema` before Tier A. Outbound bridge encoding uses `_wireArgForServiceExtension` in `agent_entry_helpers.dart`.

### Tier C — CLI `exec` catalog (`CommandCatalog`)

Host `exec` runs through `CommandCatalog.buildCommand` (`commands_catalog.dart`):

| Step | Behavior |
|------|----------|
| Name resolution | `resolveExecCommandName` accepts bare catalog names and `fmt_*` aliases (see table above) |
| Unknown keys | `_validateUnknownKeys` before interaction validation: rejects keys outside catalog `inputSchema.properties` unless `additionalProperties: true`; accepts camelCase / kebab-case aliases of declared keys |
| Tier A exec + capture (24 tools in `interactionCatalogInputSchemaFor`; 22 documented tier A exec = 18 core + 4 inspection) | `validationFailureForInteractionCatalogCommand` → `interactionCatalogInputSchemaFor` → **coerce + Tier A** (`validationFailureForDynamicSchema` in `interaction_catalog_validation.dart`) before `spec.build` |
| Other catalog commands | `_validateUnknownKeys` only (unless catalog `inputSchema` is strict); no `interactionCatalogInputSchemaFor` entry |
| Build | `spec.build` parses typed fields (strict — string-encoded numbers fail; see `flutter_mcp_toolkit_test` “exec rejects string-encoded integers”) |

`fmt_client_tool`’s catalog schema only validates `{ toolName, arguments }`; the **nested** tool args are validated at Tier B/A when forwarded to the app.

### Tier D — WebMCP (generated JS vs Dart hook)

| Layer | Validation |
|-------|------------|
| **JS** (`agentkit_webmcp.generated.js`) | `validateInput`: required, unknown keys when `additionalProperties: false`, top-level primitive types and min/max |
| **Dart hook** | If `globalThis.__agentkitWebMcpDartExecute` is set (`registerAgentWebMcpFromEntries`), JS delegates to `AgentCallEntry.invokeDirect` → **Tier A** |
| **Fallback** | `fetch('/agent/invoke?…')` — no Tier A in JS; dogfood PWA route is JS-only per [ADR 0008](../decisions/0008_web_agent_invoke_js_only.mdx) (typically 404; prefer Dart hook) |

Duplicate `registerTool` races: JS may register first; Dart bootstrap skips re-register and relies on the hook for full validation (`isAgentWebMcpToolRegistered` in dogfood).

Example:

```bash
# CLI exec — use global --vm-service-uri (not exec --target)
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart \
  --vm-service-uri ws://127.0.0.1:8181/<token>/ws \
  exec --name get_recent_logs --args '{}'

# MCP client — fmt_ prefix
# tools/call name: fmt_get_recent_logs
```
