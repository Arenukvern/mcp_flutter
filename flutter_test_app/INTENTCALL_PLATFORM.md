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

Normal repo state resolves hosted `intentcall_* ^0.6.0` packages from pub.dev. Local path overrides to `/Users/anton/mcp/agentkit/packages/intentcall_*` are local-development-only and should not be committed for hosted consumer integration.

## Manifest and platform sync

Regenerate platform artifacts from the app manifest:

```bash
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart codegen sync \
  --platform web,android,ios,macos,linux,windows \
  --project-dir flutter_test_app
```

Use `--check` in CI or pre-merge drift checks. The app keeps `web/agent_manifest.json` as the consumer manifest fixture.

## Apple AppIntentsTesting scaffold

Generate an XCTest UI-test scaffold from the same manifest and dogfood fixtures:

```bash
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart \
  codegen appintents-testing generate \
  --project-dir flutter_test_app \
  --bundle-id com.example.testApp \
  --sample-arguments tool/intentcall/appintents_testing_samples.json \
  --entity-fixtures tool/intentcall/appintents_testing_entities.json \
  --output macos/RunnerTests/IntentCallAppIntentsLiveInvocationTests.swift
```

The output path above is a maintainer handoff location, not a proof claim by
itself. Add the generated Swift file to a signed XCTest UI-test target and run
`xcodebuild test` through full Xcode before claiming AppIntentsTesting runtime
proof. Without that run, the strongest claim is generated scaffold proof.
Entity-query and Spotlight scaffold checks are generated only for entity types
that have explicit `--entity-fixtures`; they remain generated scaffold proof
until a signed XCTest UI-test target executes them.

## Web and native dogfood

| Path | Consumer proof |
|------|----------------|
| WebMCP | `web/index.html` loads generated WebMCP JS for early discovery; Flutter bootstrap starts `IntentCallFlutterHost` with WebMCP registration enabled to prove Dart registry execution with `app_intentcall_bridge_ping`. |
| VM service | App dynamic tools are listed through `fmt_list_client_tools_and_resources` and invoked through `fmt_client_tool`. |
| CLI / MCP host | Host tools keep `exec` and `fmt_*` naming parity through shared toolkit schemas and tests. |
| Native invoke | `IntentCallFlutterHost` drains generated-wrapper envelopes on startup/resume and listens for app-owned deep links through the `mcpfluttertest` scheme. Generated Apple intents use foreground/open-app handoff for `app_intentcall_bridge_ping`, `app_set_greeting`, and `app_enable_switch`. |
| Apple entities | `web/agent_manifest.json` declares the `app_screen` entity type, generated Swift projects it as `AppEntity, IndexedEntity`, and Dart seeds native entity snapshots for Spotlight/App Intents query/cache proof. This is not live Spotlight/Siri discovery proof until a signed installed app is exercised through the OS. |
| AppIntentsTesting | `tool/intentcall/appintents_testing_samples.json` supplies primitive tool arguments for generated XCTest scaffolds. This is not runtime proof until a signed UI-test target runs the generated source. |

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

# Generate AppIntentsTesting scaffold only
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart \
  codegen appintents-testing generate \
  --project-dir flutter_test_app \
  --bundle-id com.example.testApp \
  --sample-arguments tool/intentcall/appintents_testing_samples.json \
  --entity-fixtures tool/intentcall/appintents_testing_entities.json
```
