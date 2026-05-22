# P3 — Network introspection design

> **Status:** deferred. Design approved 2026-04-28; spec is fully concrete and
> implementation-ready. When resumed, feed this file into
> `superpowers:writing-plans` directly. Branch off whichever line is current
> at resume.
>
> **Why deferred:** the audit ([ADR 0002](../decisions/0002_v3_scope_and_consolidation_deferrals.mdx))
> kept v3.0.0 to Playwright-parity P0–P2 + the capability kernel. Network
> introspection didn't make the cut; nothing about the design has changed.

## Goal

Give MCP-driven agents Playwright-style visibility into a Flutter app's HTTP traffic in debug, so they can confirm requests, inspect responses, and diagnose backend issues without bouncing to a separate proxy or DevTools network tab.

## Non-goals

- Flutter web (`BrowserClient` bypasses `dart:io HttpClient`).
- `dio` apps that swap `HttpClientAdapter` for a custom non-`dart:io` adapter.
- Persistence across hot restart (the buffer is in-memory, cleared per process).
- Live push of network events to the agent (polling only).
- Content-type-aware body decoding (raw bytes → UTF-8 with replacement; binary blobs are agent's problem).
- Modifying responses, mocking, or replaying — capture only.

## Public API (host-app surface)

The capture is **opt-in by addition** — host apps that want it call a factory and append the returned entries to `bootstrapFlutter(additionalEntries: ...)` (or `addEntries(...)`). Apps that don't add the entries pay zero cost: no `HttpOverrides` install, no buffer, no extra service.

```dart
// New file: mcp_toolkit/.../toolkits/network_capture_toolkit.dart
Set<MCPCallEntry> getNetworkCaptureEntries({
  int maxRequests = 100,
  int maxBodyBytes = 4096,
  Set<String> extraRedactedHeaders = const {},
}) {
  NetworkCaptureService.install(
    maxRequests: maxRequests,
    maxBodyBytes: maxBodyBytes,
    extraRedactedHeaders: extraRedactedHeaders,
  );
  return {
    OnGetNetworkRequestsEntry(),
    OnClearNetworkRequestsEntry(),
  };
}
```

Calling the factory installs `HttpOverrides` as a side effect; the call is idempotent (subsequent calls reconfigure the buffer/cap and re-assert the override).

## Capture pipeline

### HTTP hook

Install a custom `HttpOverrides` that wraps the previously-installed override (if any). Pattern:

```dart
final previous = HttpOverrides.current;
HttpOverrides.global = _CapturingHttpOverrides(previous);
```

`_CapturingHttpOverrides.createHttpClient(SecurityContext?)` calls `previous?.createHttpClient(context) ?? HttpClient(context: context)` and wraps the returned client with capture instrumentation. This preserves cert pinning, debug-proxy setup, and any other host-app `HttpOverrides` work.

If `HttpOverrides.current` is replaced *after* our install (e.g. another package's late init), log a one-shot warning via `debugPrint` on first capture attempt that detects the divergence; do not attempt to reinstall.

### Storage

In-memory ring buffer of the most recent `maxRequests` completed records. New entries displace the oldest. The service exposes synchronous `recent({count, filter})` and `clear()` operations. Records are immutable post-capture.

### Per-record shape

```dart
{
  'method': 'POST',
  'url': 'https://api.example.com/v1/widgets',
  'status': 201,                  // null if request errored before headers
  'requestHeaders': {...},          // post-redaction
  'responseHeaders': {...},         // post-redaction
  'requestBody': '...',             // truncated; UTF-8 with replacement chars
  'requestBodyTruncated': false,
  'requestBodyTotalBytes': 312,
  'responseBody': '...',            // truncated
  'responseBodyTruncated': true,
  'responseBodyTotalBytes': 18432,
  'startedAtMs': 1745868420123,    // wall-clock epoch ms at request start
  'durationMs': 87,
  'error': null,                    // string description if threw
}
```

### Streaming, WebSockets, large bodies

- Records are appended only on **request completion** (success or error). Streaming responses don't appear until the consumer drains them, which matches what the developer expects to "see in the network tab".
- WebSocket upgrade requests appear with `status: 101`, no body, `responseBodyTotalBytes: 0`. Frame traffic is *not* captured (out of scope; would need a separate channel hook).
- Bodies past `maxBodyBytes` are truncated. `*BodyTotalBytes` records the full size; `*BodyTruncated` is `true`. The truncation point is at the byte boundary; the captured prefix is decoded as UTF-8 with replacement characters so a partial multi-byte sequence at the cut is non-fatal.

### Privacy contract

Default redacted headers (case-insensitive): `Authorization`, `Cookie`, `Set-Cookie`, `Proxy-Authorization`. Header value is replaced with `<redacted>`. `extraRedactedHeaders` (case-insensitive) augments this set; redaction applies to both request and response headers.

URL query strings are *not* scrubbed — the host app is responsible for not embedding secrets in URLs. This is documented in the host-app entry-point doc.

Body capture limit documented as a privacy/perf knob: default 4KB per direction.

## MCP tools (server + toolkit)

### `get_network_requests`

Returns the most recent matching captured records.

Args:
- `count?: int = 20` (max 100, clamped)
- `urlContains?: string` — substring match on URL
- `method?: string` — exact match (case-insensitive normalized to upper)
- `statusGte?: int`
- `statusLte?: int`

Response (success):
```json
{
  "ok": true,
  "data": {
    "requests": [<record>, <record>, ...],
    "totalCaptured": 87,
    "filtered": 12,
    "returned": 12
  }
}
```

Response when toolkit not installed: see error codes below.

### `clear_network_requests`

No args. Returns `{ok: true, data: {cleared: <int>}}`.

## Error codes (server-side)

Two new codes added to `CoreErrorCode` and the playbook:

- **`network_capture_failed`** — execution, retryable, exit 69, http 500.
  - Recovery: `flutter-mcp-toolkit doctor --json`.
- **`network_capture_not_installed`** — validation, non-retryable, exit 64, http 400.
  - Toolkit returns a sentinel `{installed: false}` when the get/clear extension RPCs are reached but the host app never called `getNetworkCaptureEntries(...)`. Server translates to this error.
  - Recovery message: `Add getNetworkCaptureEntries() to your bootstrapFlutter(additionalEntries: ...) call to enable HTTP capture.`

## Wire registration (7-place pattern)

Per the interaction-layer project memory:

1. **Command classes** — `GetNetworkRequestsCommand`, `ClearNetworkRequestsCommand` in a new `mcp_server_dart/lib/src/shared_core/commands/network_commands.dart`.
2. **CommandSpec entries** — added to `commands_specs.dart` `_buildSpecs()` list.
3. **Extension-name constants** — `getNetworkRequests`, `clearNetworkRequests` in `mcp_toolkit_consts.dart`.
4. **Tool definitions + handler methods** — new `mcp_server_dart/lib/src/mcp_toolkit_server/handlers/network_handler.dart` exposing both tools with strict JSON schemas.
5. **Dispatch cases + executor methods** — `_getNetworkRequests`, `_clearNetworkRequests` in `command_executor.dart`. The "toolkit not installed" sentinel maps to `network_capture_not_installed`.
6. **Toolkit-side entries** — `OnGetNetworkRequestsEntry`, `OnClearNetworkRequestsEntry` extension types in `network_capture_toolkit.dart`. They call `NetworkCaptureService.recent(...)` / `.clear()`. When the service was never installed (factory not called), the entries return `{installed: false}` so the server can route to the right error.
7. **Registrations** — `flutter_inspector.dart` mixin's `initialize()` registers both tool definitions/handlers.

## Tests

### Toolkit-side (`mcp_toolkit/test/network_capture_service_test.dart`)
- Ring buffer trims to `maxRequests` (push N+1, expect N most recent).
- Default redacted headers replaced with `<redacted>`; case-insensitive matching.
- `extraRedactedHeaders` augments defaults.
- Bodies past `maxBodyBytes` truncated; `bodyTruncated: true` and `bodyTotalBytes` set.
- `HttpOverrides` install wraps a pre-existing override (delegates `createHttpClient` correctly).
- Idempotent install (factory called twice doesn't double-wrap).
- WebSocket upgrade captured with `status: 101`, no body.
- Errored request captured with `error: <description>`, `status: null`.

### Toolkit-side entry behavior (`network_capture_toolkit_test.dart`)
- `OnGetNetworkRequestsEntry` returns `{installed: false}` when service not installed.
- After install + simulated requests, the entry returns recent records honoring `count`/`urlContains`/`method`/`statusGte`/`statusLte` filters.
- `OnClearNetworkRequestsEntry` empties the buffer and reports the cleared count.

### Server-side (`mcp_server_dart/test/network_commands_test.dart`)
- `CommandCatalog` round-trips both commands with all optional args.
- Default `count` is 20 when omitted; clamps to 100 when overshooting.
- Routing: toolkit response with `installed: false` → `CoreErrorCode.networkCaptureNotInstalled` (extract a `routeNetworkRequestsResponse` helper, mirror of `routeWaitForResponse`).

### Pre-existing test failures
`core_executor_test.dart` and `preconnect_test.dart` are out of scope per repo convention.

## Concrete edits & deltas

### New files
- `mcp_toolkit/lib/src/services/network_capture_service.dart`
- `mcp_toolkit/lib/src/toolkits/network_capture_toolkit.dart`
- `mcp_toolkit/test/network_capture_service_test.dart`
- `mcp_toolkit/test/network_capture_toolkit_test.dart`
- `mcp_server_dart/lib/src/shared_core/commands/network_commands.dart`
- `mcp_server_dart/lib/src/mcp_toolkit_server/handlers/network_handler.dart`
- `mcp_server_dart/test/network_commands_test.dart`

### Modified files
- `mcp_toolkit/lib/mcp_toolkit.dart` — export the new toolkit + service.
- `mcp_server_dart/lib/src/shared_core/commands/commands_specs.dart` — two specs.
- `mcp_server_dart/lib/src/shared_core/command_executor.dart` — two dispatch cases + executor methods + `routeNetworkRequestsResponse` helper.
- `mcp_server_dart/lib/src/shared_core/types/error_codes.dart` — two codes + descriptors.
- `mcp_server_dart/lib/src/mcp_toolkit_consts.dart` — two extension-name constants.
- `mcp_server_dart/lib/src/mcp_toolkit_server/mixins/flutter_inspector.dart` — register both tools.
- `docs/ai_agents/troubleshooting.mdx` — playbook-style recovery for relevant error codes.
- `todo/playwright_parity_audit.md` — move the `network_requests` row out of "Still missing" once shipped.
- `CHANGELOG.md` — add a P3 section under the next version when shipped.

## Risks / open follow-ups

- **HttpClient instance ordering**: if a package creates an `HttpClient` before `HttpOverrides` is installed (rare but possible if the host calls `getNetworkCaptureEntries()` deep into bootstrap), that client doesn't go through our hook. Mitigation: docs example shows installing the entries before `runApp()`.
- **High-throughput apps**: 100-record buffer may roll over very fast. Tunable via `maxRequests`; not auto-scaled.
- **Body decoding**: raw bytes → UTF-8 with replacement is good enough for JSON/text. Binary payloads (images, protobuf) will look like garbage; that's acceptable for v1.
- **No frame-level WebSocket capture**: noted as out of scope; revisit if usage shows demand.

## Branch / sequencing

Stack on `live-edit-v2-plannig` (the user's chosen branch for the Playwright-parity series). After P3 lands, the audit and roadmap rows flip green.
