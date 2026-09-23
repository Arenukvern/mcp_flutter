---
name: flutter-mcp-toolkit-maintain-web
description: Maintains flutter_test_app and intentcall web targets (Chrome, web codegen, WebMCP bootstrap, web-showcase, webmcp verify, Chrome DevTools MCP). Use when editing web/index.html, agent_manifest.json, intentcall_webmcp.generated.js, web platform sync, Chrome dogfood, WebMCP modelContext, or agent WebMCP list/execute.
---

<!-- @FMT_MODE_PRELUDE -->

# Maintain Web (Chrome + WebMCP)

Dogfood app: `flutter_test_app`. Canonical platform doc: `flutter_test_app/INTENTCALL_PLATFORM.md`.

## WebMCP vs VM MCP

| Path | Proves |
|------|--------|
| VM extensions + `fmt_*` tools | MCP toolkit dogfood (always) |
| `navigator.modelContext` / `document.modelContext` | True WebMCP (Chrome flags / `--web-browser-flag`) |

ADR: `decisions/0008_web_agent_invoke_js_only.mdx` — JS `fetch('/agent/invoke')` **404** by design; Dart `invokeDirect` works when `modelContext` exists.

## Launch (repeatable WebMCP)

```bash
make web-showcase
# WS_URI from .showcase/web_app.log (re-grep after hot reload)
grep -Eo 'ws://127\.0\.0\.1:[0-9]+/[A-Za-z0-9_=-]+/ws' .showcase/web_app.log | tail -1
```

```bash
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart webmcp chrome-args
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart webmcp verify --web-port 8080
```

Stop: `make showcase-stop`.

**Do not** rely on `chrome://flags` alone across machines — use CLI flags / `make web-showcase` / VS Code launch args.

### VS Code / Cursor launch

Use config **`flutter_test_app Chrome + WebMCP`** in `.vscode/launch.json`:

- `--web-browser-flag=--user-data-dir=${workspaceFolder}/.showcase/chrome-webmcp-profile` — **persistent profile** so `chrome://flags` survive stop/start (Flutter default is a temp profile every run).
- `--web-browser-flag=--enable-features=WebMCPTesting,WebModelContext,DevToolsWebMCPSupport`
- `--web-browser-flag=--enable-experimental-web-platform-features`

Path must **not** include literal quotes in the value (avoids a dir named `"./…"`).

Chrome **149+** Application → **WebMCP** pane also needs `#devtools-webmcp-support` / feature `DevToolsWebMCPSupport` (API alone is not enough for that UI).

## Agent WebMCP (Chrome DevTools MCP) — preferred for live invoke

Prefer **`chrome-devtools` MCP** (`list_webmcp_tools`, `execute_webmcp_tool`) over `flutter_mcp_toolkit webmcp verify --tool-name` when an agent should drive page tools.

### Install (once)

**Grok** (`~/.grok/config.toml`):

```toml
[mcp_servers.chrome-devtools]
command = "npx"
args = [
  "-y",
  "chrome-devtools-mcp@latest",
  "--categoryExperimentalWebmcp",
  "--chromeArg=--enable-features=WebMCP,WebModelContext,DevToolsWebMCPSupport,WebMCPTesting",
  "--chromeArg=--enable-experimental-web-platform-features",
  "--userDataDir=/Users/YOU/.cache/chrome-devtools-mcp/chrome-profile-webmcp",
  "--no-usage-statistics",
]
enabled = true
startup_timeout_sec = 90
```

Or: `grok mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest --categoryExperimentalWebmcp ...`

**Cursor** — same `command`/`args` under `mcpServers.chrome-devtools` in `~/.cursor/mcp.json`.

Restart the agent session after install. Doctor: `grok mcp doctor chrome-devtools`.

### Live flow

1. App must serve (e.g. `make web-showcase` or VS Code Chrome + WebMCP on `:8080`).
2. `list_pages` — chrome-devtools may start its **own** browser (`about:blank`).
3. `navigate_page` → `http://localhost:8080/` (or your app URL).
4. Wait for Flutter/Dart bootstrap (first `list_webmcp_tools` can be empty).
5. `list_webmcp_tools` — expect IntentCall tools + often `mcp_*` toolkit tools registered on `modelContext`.
6. `execute_webmcp_tool` with `toolName` + JSON-string `input` when required.

Example IntentCall tools: `app_enable_switch` (no args), `app_set_greeting` (`{"text":"…"}`), `app_intentcall_bridge_ping` (`{"echo":"…"}`), `app_get_agent_showcase_state`.

```text
execute_webmcp_tool
  toolName: app_enable_switch
  input: {}
```

### Fallback (CLI, no chrome-devtools MCP)

```bash
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart webmcp verify --web-port 8080 \
  --tool-name app_enable_switch --tool-args '{}'
```

## Codegen & hooks

```bash
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart codegen sync \
  --platform web,android,ios,macos,linux,windows \
  --project-dir flutter_test_app

dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart init intentcall-platform \
  --project-dir flutter_test_app --check
```

| Artifact | Source |
|----------|--------|
| `web/intentcall_webmcp.generated.js` | `codegen sync` from `web/agent_manifest.json` |
| `web/index.html` | `init intentcall-platform` script tag |
| Dart bootstrap | `registerAgentWebMcpFromEntries` in `mcp_toolkit_extensions.dart` (debug web, after `addEntries`; `intentcall_platform`) |

## Runtime validate

```bash
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart --save-images \
  --output-dir .showcase/web_iter validate-runtime \
  --target "$WS_URI" \
  --flutter-device chrome \
  --timeout-ms 45000
```

Pass `--web-browser-debugging-port <cdp>` if CDP discovery fails.

## Known issues

1. **Duplicate tool name** — generated JS + `registerAgentWebMcpFromEntries` both call `registerTool`; dedupe or gate one path (`agent_web_mcp_bootstrap_web.dart` name cache).
2. **CDP probe** — `webmcp verify` may report `webmcp_active_log_evidence` while CDP `hasModelContext` is false (Flutter execution context).
3. **Stale WS_URI** — always grep fresh token after hot restart before eval/validate.
4. **Empty WebMCP list right after navigate** — wait until Dart hook / registration finishes, then list again.
5. **Temp Chrome profile** — without `--user-data-dir`, Flutter wipes `chrome://flags` every stop/start.
6. **Two browsers** — chrome-devtools MCP profile ≠ Flutter-launched Chrome unless you attach with `--browser-url=http://127.0.0.1:<cdpPort>`.

## Related

- `docs/superpowers/evals/2026-05-26-webmcp-verification.md`
- `flutter-mcp-cli-runtime-validation` — validate-runtime details
- `flutter-mcp-toolkit-dogfood-iterations` — scored iterations
- Chrome DevTools MCP: https://github.com/ChromeDevTools/chrome-devtools-mcp (WebMCP tools need `--categoryExperimentalWebmcp` + Chrome 149+)
