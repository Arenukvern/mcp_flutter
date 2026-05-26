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

- **WebMCP + Dart bootstrap:** `mcp_toolkit` `AgentWebMcpBootstrap` after `addEntries`; `web/index.html` loads `agentkit_webmcp.generated.js`.
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

Phase C cold-path metadata (`dogfood_reconstruct_start`, job `reconstruct.start`) is **app-side only** — same pattern as `dogfood_visual_reconstruct_info`; no bundled `fmt_*` tool in `mcp_server_dart`. See [deconstruct verification](../../docs/superpowers/evals/2026-05-26-deconstruct-verification.md).

**Schema validation:** `exec --args` must match the tool’s JSON Schema. Wrong keys, extra properties when `additionalProperties: false`, or using an MCP-prefixed name on exec (e.g. `fmt_get_recent_logs`) fails validation or returns “Unsupported command”.

Example:

```bash
# CLI exec — use global --vm-service-uri (not exec --target)
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart \
  --vm-service-uri ws://127.0.0.1:8181/<token>/ws \
  exec --name get_recent_logs --args '{}'

# MCP client — fmt_ prefix
# tools/call name: fmt_get_recent_logs
```
