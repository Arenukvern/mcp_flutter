---
name: flutter-mcp-e2e-harness
description: Use this skill when writing or running repeatable E2E scenarios for Flutter apps as checked-in Dart with the `flutter_mcp_harness` package (`packages/harness`) — build/launch the app, attach to its VM service, drive widgets (snapshot/tap/enter text) and assert without MCP; also covers the repo showcase launcher (`make showcase`, `--web`, `--stop`) and multi-instance desktop compositions. For interactive assistant-driven debugging through MCP `fmt_*` tools, use `flutter-mcp` instead.
---

<!-- @FMT_MODE_PRELUDE -->

# Flutter MCP E2E Harness

Golden path for **programmatic** E2E over the toolkit: `packages/harness`
(`flutter_mcp_harness`) owns the whole lifecycle — build the app, launch the
process, attach to its Dart VM service, and only then drive/assert. It speaks
the same `ext.mcp.toolkit.*` service extensions as the MCP server, as plain
Dart. ADR: `decisions/0015_flutter_mcp_harness_extraction.mdx`.

The driving layer speaks the universal `AutomationDriver` contract
(ADR-0038, `universal_automation_interface`): `ToolkitDriver` exposes the
observe/act/verify loop (`snapshot` → semantic `AxNode` tree with refs and
bounds; `perform` click/type/key/named-route-navigate/evaluate; `screenshot`
PNG), so the same agent vocabulary drives Flutter apps, browsers
(`CdpDriver`), and OS-native targets. `IntentDriverRouter` additionally
routes an intent's `automation` hint (transport + verb + locator) onto the
bound driver. Frame pipelines are deliberately NOT a harness dependency —
they are composition-level (`showcase/drivers`, which also holds the live
end-to-end drives: `make drive-flutter` / `drive-flutter-chrome` /
`drive-web`).

App-specific verbs use the invoke tier (ADR-0017): the app's intent
registry IS the action catalog — `driver.actions()` lists it, and
`InvokeAction(name, args)` dispatches to a registered entry with
schema-validated arguments (custom `IntentAutomationAction.custom` hints
route the same way). Web surfaces without a VM service (Jaspr, plain JS)
compose identically over `CdpDriver` via the `window.__mcpActions` page
registry.

| Need | Use |
|---|---|
| Repeatable scenario as code, CI-friendly exit codes | this skill (`flutter_mcp_harness`) |
| One-off interactive debugging from chat/editor | `flutter-mcp` (MCP `fmt_*` tools) |
| Browser/WebMCP dogfood of the web showcase | `flutter-mcp-toolkit-maintain-web` |
| Live end-to-end showcase drives (both tiers) | `showcase/drivers` (`make drive-flutter` / `drive-web`) |

## Launch paths (pick by ownership)

The #1 rule: **at most one owning session per app.** A second
`flutter run`/`flutter attach` on a session someone else owns is the
ADR-0014 failure mode (the second attach can kill the first).

| Target | When | Notes |
|---|---|---|
| `FlutterRunTarget` | You want the flutter tool to own build + hot reload (`r`/`R`/`q` via stdin). The showcase launch path. | `device` (`macos`, `chrome`, …), `extraArgs`, `onLine` tee for long cold builds; VM URI scraped from the tool's own announcement. |
| `BinaryAppTarget` / `MacosAppTarget` / `WindowsAppTarget` | Fresh full `flutter build <os> --debug` → launch the binary directly. No compile channel afterwards. | Pass `launch(build: false)` to reuse an existing binary. Never opens an owning session. |
| External runner (e.g. `oka dev`) owns the app | Construct `LaunchedApp` directly around the owning process and read the VM URI from the runner-session contract, not stdout. | This package never imports the runner; callers wire it (`LaunchedApp(name:, process:, stdout:, vmUri:)`). |

`FlutterRunTarget.launch(build:)` ignores the flag — `flutter run` always
builds. A failed bring-up reaps the session (SIGTERM → child-reaping pkill →
SIGKILL) before rethrowing.

## Scenario anatomy

```dart
final scenario = Scenario('checkout E2E', steps: [
  ('launch app', (context) async {
    final app = await MacosAppTarget(projectDir: appDir, binaryPath: binary)
        .launch(build: build);
    launched = app;                       // for finally-stop
    await app.stdout.waitFor('app ready'); // no sleeps — wait on logs
    context.bag['app'] = app;             // hand values between steps
  }),
  ('drive + assert', (context) async {
    final driver = WidgetDriver(await context.take<LaunchedApp>('app').vm());
    final ref = await driver.findRef('checkout');
    if (ref == null) return context.report.fail('no checkout button');
    await driver.tap(ref);
    final total = await driver.findValue((v) => v.startsWith(r'$'));
    total != null
        ? context.report.pass('total rendered: $total')
        : context.report.fail('no total in snapshot');
  }),
]);

var passed = false;
try {
  passed = await scenario.run();
  scenario.report.printSummary();
} finally {
  await launched?.stop();                 // cleanup always runs
}
exit(passed ? 0 : 1);
```

- Steps run in order; first failure (thrown **or** `report.fail`) aborts the
  rest — cleanup still happens in the caller's `finally`.
- `HarnessContext.bag` passes values between steps; `take<T>(key)` reads them.
- `retry(action)` polls until non-null (for app-side readiness races).
- Full two-instance composition root: `packages/harness/example/desktop_pair.dart`.

## Driving widgets (`WidgetDriver`)

- `snapshot()` → `(label, ref)` pairs; `findRef(needle)` is case-insensitive
  substring + retry until timeout.
- `tap(ref)`, `tapUntil(ref, until: …)` (re-tap until a predicate fires),
  `enterText(ref, text)`, `scroll(direction:, distance:)` — off-screen
  semantics only exist once scrolled into view.
- `findValue(predicate)` reads a node's selectable-text **`value`** — the
  deterministic way to read app-rendered data (clipboards and icon-only copy
  buttons are not).
- Cold-attach race: the app may not have registered the toolkit yet when you
  attach. The driver answers RPC error `-32601` with an empty snapshot so
  `findRef`'s retry loop rides it out instead of aborting — do not treat one
  empty snapshot as proof the UI is empty.
- `VmClient` extras: `extensionNames()` (discoverability), `evaluate(expr)`,
  `hotReload()`. Raw `reloadSources` **cannot compile** without an owning
  `flutter run`/`attach` session — treat `true` as "asked", not "recompiled".

## Showcase launcher (`packages/harness/tool/showcase.dart`)

```bash
make showcase        # macOS showcase, interactive foreground (r/R/q relayed)
make web-showcase    # Chrome + WebMCP flags; WEB_PORT/VM_HOST_PORT/FLIGHT… env
make showcase-stop   # kill stray sessions, free VM port 8181 (idempotent)
```

- `--web --detach` (or `make`-less `dart run packages/harness/tool/showcase.dart --web --detach`)
  spawns headless-ish, waits for the `ws://` VM URI in `.showcase/web_app.log`,
  prints `WS_URI=…`, exits 0 — the CI-friendly variant.
- Artifacts under `.showcase/`: `flutter_app.log` / `web_app.log` (teed
  output) and `flutter.pid` / `web_flutter.pid` pid files.
- IntentCall doors (second terminal, against the running showcase):
  `dart run packages/harness/tool/intentcall_session.dart
  [demo|serve-link|serve-debug]` — resolves the VM service URI from the
  showcase log (`--vm-service-uri` pins one) and the IntentCall CLI from
  `INTENTCALL_ROOT`, sibling checkouts, or `PATH`.
- Interactive mode tees every line to the log (which `make exec-sweep` greps)
  and tears the session down on exit or Ctrl-C.
- WS URI for follow-up calls: `grep -Eo 'ws://127\.0\.0\.1:[0-9]+/[A-Za-z0-9_=-]+/ws' .showcase/flutter_app.log | tail -1`.

## Hard boundaries

- **No new toolkit verbs.** `ToolkitExtensions` mirrors
  `mcp_toolkit/lib/src/toolkits/interaction_toolkit.dart`; keep the lists in
  lockstep — drift is caught by extension calls failing at runtime today
  (shared-constants follow-up will make it a compile error).
- **No owned compile sessions** in `BinaryAppTarget` — full fresh builds only.
- **No declarative scenario documents** (YAML runners) — the external
  `flutter_harness` experiment (ADR-0012) is retired (ADR-0017).
  Composition roots are consuming-project code (see `example/`).
- Android/iOS device bring-up is delegated to the owning dev session
  (`oka_harness`, ADR-0014) — not this package.

## Verify

```bash
cd packages/harness && dart test        # unit tests (canned envelopes, fake flutter)
dart run example/desktop_pair.dart --skip-build
```

## Related

- `flutter-mcp` — the interactive MCP loop over the same extensions
- `flutter-mcp-automation-chain` — cross-tier wiring for your own app (surface picker, oka integration, runner sessions)
- `flutter-mcp-toolkit-maintain-macos` / `-maintain-web` — showcase + platform lanes
- `packages/harness/README.md`, ADR-0014 (runner delegation), ADR-0015 (extraction)
