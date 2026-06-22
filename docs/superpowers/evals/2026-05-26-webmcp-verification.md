# WebMCP verification — flutter_test_app on Chrome

**Date:** 2026-05-26  
**Verdict:** **pass with tooling** — `make web-showcase` + `webmcp verify` reports `webmcp_active` (CDP `globalThis`, iteration 7). Default plain `flutter run -d chrome` still omits WebMCP flags.

## Scope

Verify **true WebMCP** (`navigator.modelContext.registerTool` / W3C CG draft) for `flutter_test_app`, distinct from VM extensions + dynamic registry dogfood.

## Code paths (verified in repo)

| Path | Role |
|------|------|
| `flutter_test_app/web/intentcall_webmcp.generated.js` | JS bootstrap from manifest; feature-detect + `registerTool` |
| `flutter_test_app/web/index.html` | Loads generated JS before Flutter |
| `/Users/anton/mcp/agentkit/packages/intentcall_platform/.../agent_web_mcp_bootstrap_web.dart` | Dart `js_interop` registration after `addEntries` (debug web) |
| `mcp_toolkit/lib/src/mcp_toolkit_extensions.dart` | Calls `AgentWebMcpBootstrap.registerFromEntries` on web |
| `/Users/anton/mcp/agentkit/packages/intentcall_webmcp/` | `WebMcpPublishAdapter` (registry hot-sync) — **not wired in flutter_test_app** |

### Detection

- **JS:** `'modelContext' in nav && typeof nav.modelContext.registerTool === 'function'`
- **Dart:** `navigator.hasProperty('modelContext')` (does not check `registerTool` is a function)

Both paths **no-op silently** when API absent.

### Generated JS vs Dart bootstrap

| | Generated JS | Dart bootstrap |
|---|--------------|----------------|
| When | Page load (`index.html`) | After `addEntries` (debug web only) |
| Tools | From `web/agent_manifest.json` (e.g. `app_demo_ping`) | All runtime `AgentCallEntry` tools |
| `execute` | `fetch('/agent/invoke?name=…')` | `entry.invokeDirect` in-process |
| Live invoke today | **404** on `/agent/invoke` ([ADR 0008](../../decisions/0008_web_agent_invoke_js_only.mdx)) | Works only if `modelContext` exists |

## Chrome requirements

- **Chrome 146+** (tested: 148.0.7778.179)
- **Secure context** (localhost OK)
- **Flag:** `chrome://flags/#enable-webmcp-testing` — required for API on current builds
- **`flutter run -d chrome` does not enable this flag** by default

## Test results

```bash
cd intentcall && dart test packages/intentcall_webmcp \
  packages/intentcall_platform/test/agent_web_mcp_bootstrap_test.dart \
  packages/intentcall_platform/test/web_emitters_test.dart
# → 9/9 passed (2026-05-26)
```

No automated browser test with real `navigator.modelContext`.

## Live verification (localhost:8080, default Flutter Chrome)

| Check | Result |
|-------|--------|
| App serving | yes |
| `intentcall_webmcp.generated.js` served | yes |
| `POST /agent/invoke?name=app_demo_ping` | **404** (expected per ADR 0008) |
| CDP: `'modelContext' in navigator` | **false** |
| VM extensions + dynamic registry | **pass** (dogfood evals 1–5) |

**Important:** Dogfood scores **do not** assert `modelContext`; they prove VM/MCP path only.

## Repeatable enablement (CLI — preferred)

Avoid per-machine `chrome://flags` drift:

```bash
# Print JSON + full flutter run recipe
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart webmcp chrome-args

# Launch dogfood app with flags (logs .showcase/web_app.log)
make web-showcase

# CDP probe after app is up
dart run mcp_server_dart/bin/flutter_mcp_toolkit.dart webmcp verify --web-port 8080
```

Dogfood battery runs `webmcp verify` automatically on full web runs (`tool/evals/run_dogfood_eval.sh`).

## Manual re-verify (when flag enabled)

1. Enable `chrome://flags/#enable-webmcp-testing` → relaunch Chrome **or** use `make web-showcase`.
2. `flutter run -d chrome --web-port=8080 --host-vmservice-port=8181` **with** `--web-browser-flag` from `webmcp chrome-args`
3. DevTools console:
   ```javascript
   'modelContext' in navigator
   typeof navigator.modelContext?.registerTool
   await navigator.modelContextTesting?.getTools()
   ```
4. Expect JS tool `app_demo_ping` + Dart-registered tools (debug builds).
5. Execute via Dart path (in-process); JS path still hits `/agent/invoke` unless route added.

## Registration dedupe (2026-05-26)

Generated JS and Dart `AgentWebMcpBootstrap` both call `registerTool`. Hot restart caused `InvalidStateError: Duplicate tool name`. **Mitigation:** try/catch in emitted JS; `_jsRegisterTool` + name cache in `agent_web_mcp_bootstrap_web.dart`.

## Gaps / false positives

1. Manifest + generated JS **look** complete but are **inert** without flag/API.
2. PWA `protocol_handlers` / JS `fetch` suggest invoke works — **404** without Flutter route.
3. `WebMcpPublishAdapter` untested in browser for this app.
4. Tool set mismatch: manifest JS registers `app_demo_ping` only; runtime tools need Dart bootstrap.
5. No repo doc for Chrome flag until this file — add to `INTENTCALL_PLATFORM.md` when flag steps confirmed.

## Conclusion

**Verified with flags:** `make web-showcase` + `webmcp verify` → `webmcp_active` (CDP `modelContext`, dogfood iterations **7** and **10**). **Default** `flutter run -d chrome` without `webmcp chrome-args` remains inactive — agents must use documented Chrome flags or `make web-showcase`.

## Related

- [tool_quality_rubric.yaml](./tool_quality_rubric.yaml) — dimension `webmcp_parity`
- [dogfood_web_eval.yaml](../../evidence/dogfood/dogfood_web_eval.yaml) — iterations 1–11 (VM + WebMCP)
