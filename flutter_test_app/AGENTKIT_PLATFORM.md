# Agentkit platform hooks (flutter_test_app)

One-time project hooks until `flutter-mcp-toolkit init agentkit-platform` ships (Phase 7).

## Pub resolution

`mcp_toolkit` pulls `agentkit_platform` (web bootstrap). Override workspace packages in `pubspec.yaml`:

```yaml
dependency_overrides:
  agentkit_core:
    path: ../packages/agentkit_core
  agentkit_schema:
    path: ../packages/agentkit_schema
```

## Manifest

- Canonical descriptor list: `web/agent_manifest.json` (also accepted at project root).
- Regenerate web PWA + JS: from repo root:
  ```bash
  cd mcp_server_dart && dart run bin/flutter_mcp_toolkit.dart codegen sync \
    --platform web,android,ios,macos,linux,windows \
    --project-dir ../flutter_test_app
  ```
- CI drift check: add `--check` to the same command.

## Native build hooks (manual)

Copy snippets from `packages/agentkit_platform` templates (`platform_hook_templates.dart`) or from `codegen sync` JSON output:

| Platform | Inject |
|----------|--------|
| Android | Gradle `agentkit` task + `res/xml/agentkit_shortcuts.xml` manifest snippet |
| Apple (iOS/macOS) | Xcode Run Script → `dart run` / `codegen sync` |
| Linux | `linux/agentkit_protocol.desktop` |
| Windows | `windows/agentkit_protocol.reg` fragment |

## Web path C (Dart bootstrap)

`mcp_toolkit` calls `AgentWebMcpBootstrap.registerFromEntries` on web after each `addEntries` (in addition to `web/index.html` JS). `/agent/invoke` is emitted for PWA protocol handlers; full route handling is optional (JS `fetch` path in `agentkit_webmcp.generated.js`).
