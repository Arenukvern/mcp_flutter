# IntentCall platform hooks in flutter_test_app

`flutter_test_app` is the dogfood app for Flutter MCP Toolkit's IntentCall platform hooks. Canonical IntentCall architecture lives in `/Users/anton/mcp/agentkit`; this file documents only this app's consumer setup and proof path.

## One-time hook install

From the `mcp_flutter` repo root:

```bash
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart init intentcall-platform \
  --project-dir flutter_test_app
```

Drift check:

```bash
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart init intentcall-platform \
  --project-dir flutter_test_app --check
```

The hook installer manages idempotent markers for WebMCP script tags, Android shortcut metadata, and Apple run-script helpers where supported.

## Dependency policy

Normal repo state resolves hosted `intentcall_* ^0.3.0` packages from pub.dev. Local path overrides to `/Users/anton/mcp/agentkit/packages/intentcall_*` are local-development-only and should not be committed for hosted consumer integration.

## Manifest and platform sync

Regenerate platform artifacts from the app manifest:

```bash
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart codegen sync \
  --platform web,android,ios,macos,linux,windows \
  --project-dir flutter_test_app
```

Use `--check` in CI or pre-merge drift checks. The app keeps `web/agent_manifest.json` as the consumer manifest fixture.

## Web and native dogfood

| Path | Consumer proof |
|------|----------------|
| WebMCP | `web/index.html` loads generated WebMCP JS for early discovery; Flutter bootstrap installs the Dart execute hook and `registerAgentWebMcpFromRegistry` proves Dart registry execution with `app_intentcall_bridge_ping`. |
| VM service | App dynamic tools are listed through `fmt_list_client_tools_and_resources` and invoked through `fmt_client_tool`. |
| CLI / MCP host | Host tools keep `exec` and `fmt_*` naming parity through shared toolkit schemas and tests. |
| Native invoke | `IntentCallPendingInvocations.takePending()` drains generated-wrapper envelopes and dispatches them through Dart; `IntentCallInvokeLinkListener` remains fallback logging/dispatch only. |

For schema parity, `fmt_*`, CLI `exec`, app-dynamic tool names, and fail-closed validation troubleshooting, use `plugin/skills/flutter-mcp-boundary-audit/`. Keep canonical schema and platform-projection policy in `/Users/anton/mcp/agentkit`.

## Useful commands

```bash
# Web dogfood
make web-showcase

# Verify WebMCP browser setup
flutter-mcp-toolkit webmcp verify --web-port 8080
flutter-mcp-toolkit webmcp verify --web-port 8080 \
  --tool-name app_intentcall_bridge_ping \
  --tool-args '{"echo":"webmcp-proof"}' \
  --expect-result-field source \
  --expect-result-value dart_registry

# macOS runtime proof after showcase launch
make macos-validate-runtime

# Consumer integration gate
make check-intentcall-integration
```
