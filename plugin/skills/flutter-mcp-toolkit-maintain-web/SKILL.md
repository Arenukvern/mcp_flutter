---
name: flutter-mcp-toolkit-maintain-web
description: Maintains flutter_test_app and intentcall web targets (Chrome, web codegen, WebMCP bootstrap, web-showcase, webmcp verify). Use when editing web/index.html, agent_manifest.json, intentcall_webmcp.generated.js, web platform sync, Chrome dogfood, or WebMCP modelContext.
---

<!-- @FMT_MODE_PRELUDE -->

# Maintain Web (Chrome + WebMCP)

Dogfood app: `flutter_test_app`. Canonical platform doc: `flutter_test_app/INTENTCALL_PLATFORM.md`.

## WebMCP vs VM MCP

| Path | Proves |
|------|--------|
| VM extensions + `fmt_*` tools | MCP toolkit dogfood (always) |
| `document.modelContext` | True WebMCP (Chrome flag / `--web-browser-flag`) |

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

**Do not** rely on `chrome://flags` alone across machines — use `webmcp chrome-args` / `make web-showcase`.

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

## Related

- `docs/superpowers/evals/2026-05-26-webmcp-verification.md`
- `flutter-mcp-cli-runtime-validation` — validate-runtime details
- `flutter-mcp-toolkit-dogfood-iterations` — scored iterations
