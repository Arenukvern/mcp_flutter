# Boundary audit — reference

Progressive disclosure for `flutter-mcp-boundary-audit`. The main [SKILL.md](SKILL.md) is repository-neutral; this file adds depth and a **reference implementation** for the mcp_flutter monorepo.

---

## Reference implementation (mcp_flutter)

Use this section when auditing **this** repository. Map the generic roles from SKILL.md to these paths.

### Role → file map

| Concern | Primary files |
|---------|----------------|
| Wire coercion (pre–Tier A, app paths) | `agentkit/packages/agentkit_schema/lib/src/schema_coercion.dart` |
| Entry model | `agentkit/packages/agentkit_core/lib/src/authoring/agent_call_entry.dart` |
| Toolkit bridge / VM registration | `mcp_toolkit/lib/src/mcp_toolkit_extensions.dart`, `agent_entry_helpers.dart` |
| App interaction tools | `mcp_toolkit/lib/src/toolkits/interaction_toolkit.dart` |
| Shared interaction schemas | `packages/core/lib/src/tools/interaction_input_schemas.dart` |
| Server fmt tools | `packages/server_capability_core/lib/src/tools/interaction_tools.dart`, `semantic_tools.dart`, `wait_tools.dart` |
| Dynamic registry | `mcp_server_dart/lib/src/capabilities/dynamic_registry/` — grep `forwardToolCall` |
| VM gateway | `mcp_server_dart` — `VmExtensionDynamicGateway` / `dynamic_gateway.dart` |
| Migrator | `agentkit/packages/agentkit_core/lib/src/migrate_agent_entries.dart` |
| WebMCP | `agentkit` web bootstrap, `flutter_test_app/web/agentkit_webmcp.generated.js` |
| Platform contract doc | `flutter_test_app/AGENTKIT_PLATFORM.md` |
| Registration doc | `mcp_server_dart/docs/SIMPLIFIED_DYNAMIC_REGISTRATION.md` |

### Gateway flow (mcp_flutter)

```text
AgentCallEntry (authoring)
    ├─► registerDynamics ──► VM ext callback ──► handler
    ├─► WebMCP registerTool / invokeDirect
    └─► fmt_list_* ──► fmt_client_tool ──► VmExtensionDynamicGateway ──► VM ext
```

| Gateway | Must validate before | Fail if schema missing? |
|---------|----------------------|-------------------------|
| App VM ext callback (`mcp_toolkit_extensions.dart`) | handler | yes |
| `forwardToolCall` / dynamic registry | `intent.execute` | yes |
| `VmExtensionDynamicGateway` | VM service extension call | yes |
| `AgentCallEntry.invokeDirect` | `execute` | yes |
| `fmt_client_tool` | forward to app | yes |
| CLI `exec` | command dispatch | yes |

### VM wire coercion (repo state)

VM service extensions deliver string-key maps on the wire. **`coerceArgumentsForSchema`** (`agentkit_schema`) runs **before** Tier A on app paths that see wire-shaped args:

| Path | Coerce before validate? |
|------|-------------------------|
| App `registerServiceExtension` callback | yes — coerce → validate → handler |
| `AgentCallEntry.invokeDirect` (WebMCP Dart hook) | yes |
| `DynamicRegistry.forwardToolCall` (Tier B inner `arguments`) | yes — `coerceArgumentsForSchema` then `entry.intent.validate` (`dynamic_registry.dart`) |
| `VmExtensionDynamicGateway` (before VM ext) | yes — `validationFailureForDynamicSchema` (coerce + Tier A; `dynamic_gateway.dart`) |

| Mechanism | Role |
|-----------|------|
| `coerceArgumentsForSchema` | Wire string → typed properties before `validateAgainstSchema` |
| `AgentWireArgs` | Optional handler-side parsers for raw wire maps |
| `_wireArgForServiceExtension` | Outbound handler args → VM ext strings |

**Tier B contract:** `flutter_test_app/AGENTKIT_PLATFORM.md` — discovery stores per-tool `inputSchema`; `fmt_client_tool` / `forwardToolCall` and `VmExtensionDynamicGateway` coerce then validate inner args before the app sees them (same as app VM callback). MCP `fmt_*` catalog tools skip wire coerce (args are already JSON).

Re-audit host vs app paths only if coercion is added on **one** side without the other.

### Dual-path parity (mcp_flutter)

| Path | Location | Listing / invoke |
|------|----------|------------------|
| App dynamic | `interaction_toolkit.dart` | `registerDynamics`, `ext.mcp.toolkit.<name>` |
| Server `fmt_*` | `packages/server_capability_core/lib/src/tools/` | MCP `tools/call`, CLI `exec` aliases |

**Counts** (`interaction_input_schemas.dart`):

| Set | Count | Constant |
|-----|-------|----------|
| Core interaction catalog | 18 | `coreInteractionCatalogCommandNames` |
| Tier A exec (core + inspection) | 22 | `tierAExecCatalogCommandNames` |
| `interactionCatalogInputSchemaFor` router | 24 | `interactionCatalogInputSchemaForCommandNames` (= 22 + 2 capture) |

| App dynamic (`interaction_toolkit.dart` → `registerDynamics`) | Server catalog only (`fmt_*` + CLI `exec`, no app twin) |
|---------------------------------------------------------------|--------------------------------------------------------|
| `tap_widget`, `semantic_snapshot`, `wait_for`, `enter_text`, `scroll`, `long_press`, `swipe`, `drag`, `hover`, `press_key`, `get_recent_logs`, `handle_dialog`, `navigate` | `fill_form`, `hot_reload_flutter`, `hot_restart_flutter`, `evaluate_dart_expression`, `hot_reload_and_capture` |

**Host-only beyond core 18:** `get_view_details`, `inspect_widget_at_point`, `get_app_errors`, `focus_window` (inspection; part of 22-tool tier A exec). **`get_screenshots`**, **`capture_ui_snapshot`** use the same schema router (24 total) but are capture, not in the 22-tool tier A exec set.

**CLI `exec`:** commands with `interactionCatalogInputSchemaFor` entries get Tier A in `CommandCatalog.buildCommand` via `validationFailureForInteractionCatalogCommand` (not catalog-only unknown-key checks). Other catalog commands rely on `_validateUnknownKeys` + `spec.build` unless their catalog schema is strict.

**Server-only registration:** `fill_form` / hot-reload tools in `interaction_tools.dart` / `flutter_inspector_tools.dart`; `evaluate_dart_expression` and `hot_reload_and_capture` in `interaction_tools.dart`.

**Parity tests:** `mcp_toolkit/test/interaction_toolkit_schema_parity_test.dart`, `packages/server_capability_core/test/tools/interaction_input_schemas_test.dart`.

Document intentional deltas in `flutter_test_app/AGENTKIT_PLATFORM.md`.

### mcp_flutter red-flag grep

From repo root:

```bash
rg "inputSchema:\s*const\s*\{\s*'type':\s*'object'" --glob "*.dart" -g '!test/fixtures/**' -g '!**/after_*.dart'
rg "_emptyObjectSchema|additionalProperties:\s*true" --glob "*.dart" mcp_toolkit agentkit mcp_server_dart packages
rg "\.execute\(" --glob "*.dart" agentkit mcp_toolkit mcp_server_dart packages | rg -v "validate|test/"
rg "invokeDirect" --glob "*.dart" agentkit mcp_toolkit
rg "inputSchemaFromMcpTool|_emptyObjectSchema|placeholder" --glob "*.dart" mcp_server_dart packages/server_capability_core
rg "inputSchema" --glob "*migrate*" agentkit mcp_server_dart
rg "registerTool" --glob "*.dart" agentkit mcp_toolkit flutter_test_app/web
rg -i "permissive|additionalProperties:\s*true|no validation" --glob "*.md" mcp_server_dart docs flutter_test_app
rg "jsonEncode|JSON\.encode" --glob "*agent_entry*" agentkit mcp_toolkit
```

### mcp_flutter E2E proof

```bash
cd mcp_server_dart && RUN_FLUTTER_CLI_INTEGRATION=1 dart test \
  test/flutter_cli_example_app_integration_test.dart \
  --name "dynamic registry exposes inputSchema"
```

Expect: `tap_widget` listing has `required: ['ref']`; invalid `fmt_client_tool` args → `ok: false`.

Unit parity (no device):

```bash
dart test mcp_toolkit/test/interaction_toolkit_schema_parity_test.dart
dart test packages/server_capability_core/test/tools/interaction_input_schemas_test.dart
```

### Historical P0/P1 patterns (regression watch)

From `docs/superpowers/tracker/mcp-boundary-hardening.yaml` — re-audit if touching these areas:

| Pattern | Risk |
|---------|------|
| `invokeDirect` without `validate` | WebMCP accepts invalid args |
| VM ext callback calls handler directly | App isolate bypass |
| `inputSchemaFromMcpToolDefinition` silent empty schema | Registry advertises permissive contract |
| `VmExtensionDynamicGateway` missing schema → invoke anyway | Host bypass |
| Migrator drops `ObjectSchema` fields | CLI/codegen drift |
| `forwardResourceRead` without validate | Resource path bypass |
| `ToolRegistration` default handler skips validate | Bridge bypass |
| Non-scalar bridge args not JSON-encoded | Legacy handler mis-parse |
| Duplicate `registerTool` (JS + Dart) | WebMCP double registration |
| `runClientResource` without validate | Gateway bypass |
| Host validates wire strings without coerce | Tier A on typed JSON only on host |
| Resource listing omits `inputSchema` | Discovery permissive `{type:object}` |
| `inputSchemaFromMcpTool` silent copy | Should fail-closed when Tool.inputSchema missing |
| registerDynamics failure leaves stale tools | `registry_discovery_service` must `unregisterApp` on failure |

### CLI vs MCP naming (mcp_flutter)

`exec` accepts bare and `fmt_` aliases; MCP wire uses `fmt_` prefix. Dynamic app tools: listed by `fmt_list_client_tools_and_resources`, invoked via `fmt_client_tool` with **bare** `name` from listing.

See `flutter_test_app/AGENTKIT_PLATFORM.md` § CLI exec vs MCP tool names.

### ADRs / evals (mcp_flutter)

- `decisions/0008_web_agent_invoke_js_only.mdx` — JS `/agent/invoke` 404; Dart `invokeDirect` in-process
- `docs/superpowers/evals/2026-05-26-webmcp-verification.md`
- `docs/superpowers/evals/2026-05-26-deconstruct-verification.md`

### Tracker (mcp_flutter)

Completed hardening: `docs/superpowers/tracker/mcp-boundary-hardening.yaml`

---

## Example (other stacks)

<details>
<summary>Non-MCP: OpenAPI + plugin host</summary>

- **Authoring:** `openapi.yaml` components/schemas
- **Discovery:** Plugin manifest `input_schema` JSON
- **Host gateway:** API gateway validates request body before RPC to plugin
- **Runtime:** Plugin may skip validation if host already validated — document single owner
- **Dual path:** REST catalog vs gRPC `InvokeTool` — compare `required` on both

</details>

<details>
<summary>Generic JSON-RPC dynamic tools</summary>

- Listing via `tools/list` must include same `inputSchema` as `tools/call` enforcement
- Red flag: `inputSchema: { "type": "object" }` with no `properties` / `required` in production registry
- Grep: `tools/call` handler, `validate`, `ajv`, `jsonschema`, before `dispatch`

</details>
