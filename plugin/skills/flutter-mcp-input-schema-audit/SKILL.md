---
name: flutter-mcp-input-schema-audit
description: Audits agentkit InputSchema vs dart_mcp ObjectSchema boundaries for dropped schemas, validation bypasses, and dynamic-registry split-brain. Use when changing AgentCallEntry, mcpToolkitTool, registerDynamics, fmt_client_tool, dynamic_registry, migrate agent-entries, or WebMCP invoke paths.
---

# Input schema & validation audit

Find bugs like **schema advertised in listing but empty/permissive on invoke**, or **validation on one gateway only**.

## Red-flag grep

Run in repo root:

```bash
rg "inputSchema:\s*const\s*\{\s*'type':\s*'object'" --glob "*.dart" -g '!test/fixtures/**' -g '!**/after_*.dart'
rg "_emptyObjectSchema|additionalProperties:\s*true" --glob "*.dart" mcp_toolkit agentkit mcp_server_dart
rg "\.execute\(" --glob "*.dart" agentkit mcp_toolkit mcp_server_dart | rg -v "validate|test/"
```

## Boundary checklist

For each change, trace **authoring → discovery → validation → execute**:

| Step | Question | Key files |
|------|----------|-----------|
| Authoring | Does `ObjectSchema` reach `AgentCallEntry.inputSchema`? | `agent_entry_helpers.dart`, `agent_call_entry.dart` |
| Discovery | Does `registerDynamics` send `descriptor.inputSchema`? | `mcp_toolkit_extensions.dart` |
| Server registry | Does `_intentForTool` use `inputSchemaFromMcpTool` (not permissive placeholder)? | `dynamic_registry.dart` |
| CLI/MCP invoke | Does `VmExtensionDynamicGateway` validate before VM ext? Fail-closed if schema missing? | `dynamic_gateway.dart` |
| Registry invoke | Does `forwardToolCall` call `validate` before `execute`? | `dynamic_registry.dart` |
| App isolate | Does VM extension callback `validate` before handler? | `mcp_toolkit_extensions.dart` |
| WebMCP | Does `invokeDirect` call `validate`? | `agent_call_entry.dart`, `agent_web_mcp_bootstrap_web.dart` |
| Migrator | Does CLI migrate preserve `inputSchema`? | `migrate_agent_entries.dart` |

## Dual-path parity

Same logical tool may exist twice:

- **App dynamic** (`tap_widget` via `registerDynamics`) — `mcp_toolkit` / `interaction_toolkit.dart`
- **Server `fmt_*`** — `packages/server_capability_core/lib/src/tools/`

Compare `required`, `connection`, `additionalProperties: false`. Dynamic path often lacks `connection`.

## E2E proof (flutter_test_app, macOS)

```bash
cd mcp_server_dart && RUN_FLUTTER_CLI_INTEGRATION=1 dart test \
  test/flutter_cli_example_app_integration_test.dart \
  --name "dynamic registry exposes inputSchema"
```

Expect: `tap_widget` listing has `required: ['ref']`; `fmt_client_tool` without `ref` → `ok: false`.

## Report template

```markdown
## Finding: [title]
- **Severity**: P0|P1|P2
- **Paths**: authoring | discovery | validate | execute
- **Files**: ...
- **Symptom**: agents see X, runtime does Y
- **Fix**: ...
```

Tracker: `docs/superpowers/tracker/input-schema-hardening.yaml`
