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

## Evidence boundaries (what each tier can prove)

A green tier proves only what that tier touches. When you record a
result — in a validation ledger, a gate, or a report — say which tier
it came from, and never let one tier's pass stand in for another's:

| Tier | Proves | Cannot prove |
|---|---|---|
| Model / unit tests (app package) | the gesture/decision algorithm on synthetic inputs (direction → symbol → correction) | that the app's real signal chain reaches the algorithm |
| MCP / driver UI scenarios (this harness) | controls exist, are reachable, and respond — presentation and wiring through the toolkit | anything whose input never crosses the UI (e.g. camera-delivered gestures) |
| Sensor replay (deterministic frames → the REAL pipeline) | app integration: frames → tracker/recognizer → selector → draft / undo / redo / commit with the real filters and state machines, no person needed | real-hand comfort, camera noise, latency feel |
| Live camera trial (a human hand) | the real sensor story: detection robustness, comfort, fatigue | repeatability — it is a manual trial, never a CI gate |

Worked example (vosges low-look, that repo's ADR-0008): model tests
verified the codebook; the MCP scenario verified the Settings controls;
`low_look_sensor_replay_test.dart` feeds a synthetic hand through the
real tracker and selector and asserts the committed word; only a live
trial says anything about a real hand. A scenario that only touches
the UI must not claim the writing loop works.

## The web/AOT tier (WebBuildTarget + FlutterWebCdp)

The VM-service toolkit tier exists only where a Dart VM service exists:
JIT web (DDC, `flutter run`) and debug desktop/mobile. An **AOT web
build (`flutter build web`) has no VM service — the CDP tier is not a
fallback there, it is the only tier** (tier matrix: family ADR-0045;
this repo ADR-0018):

```dart
final app = await WebBuildTarget(projectDir: '.', build: !skipBuild).launch();
final flutter = app.flutter;              // FlutterWebCdp over CdpDriver
await flutter.waitText('Settings');
await flutter.clickText('Sync between devices', expect: 'I have a pairing code');
await flutter.typeFocused('mesh-pair/v1 ...');   // bringToFront + insertText
await app.stop();
```

Measured rules encoded in `FlutterWebCdp` — do not re-learn them:

- Semantic clicks through the driver's fallback ladder work on real
  Chromium; the OLD dead path was three stacked bugs (`DOM.enable`
  missing, AX nodes resolving to TEXT nodes, `callFunctionOn` `this`
  rebinding) — fixed in `universal_browser_cdp` and guarded by the
  opt-in live fixture (`XS_TEST_CDP_LIVE=1` in the cdp package).
- Locate by text/aria-label in the LIVE `flt-semantics` DOM;
  effect-verify every click (`expect:`) and check the effect BEFORE
  re-clicking (a toggle re-clicks itself off).
- The first click after load is swallowed — `warmUpClick()` burns it.
- Typing needs `Page.bringToFront` + `Input.insertText` (background
  windows have no OS focus; per-key events land nowhere).
- Navigate in-app only (`popRoute` = `history.back()`); a reload drops
  in-memory state. Headless Chrome never runs rAF — Flutter freezes;
  `WebBuildTarget` defaults to headed Chrome for this reason.

## Failure evidence (EvidenceCollector)

Attach evidence while the scenario runs; `Scenario` dumps it under
`$TMPDIR/<scenario>/` on the first failing step: `attachCdp` buffers the
page's console + uncaught exceptions (an app-side throw renders as a
canvas error screen — invisible in the DOM — and ONLY the console names
it), `attachLines` tails app stdout, `attachFile` defers an AX/state
dump. Never let evidence production mask the failure — it is
best-effort by contract.

VM-service verbs against a booting app: use `vm.callExtensionUntil(...)`
instead of hand-rolled retry loops (it folds the -32601-before-
registration window and the isolate rebind).

## Launch paths (pick by ownership)

The #1 rule: **at most one owning session per app.** A second
`flutter run`/`flutter attach` on a session someone else owns is the
ADR-0014 failure mode (the second attach can kill the first).

| Target | When | Notes |
|---|---|---|
| `FlutterRunTarget` | You want the flutter tool to own build + hot reload (`r`/`R`/`q` via stdin). The showcase launch path. | `device` (`macos`, `chrome`, …), `extraArgs`, `onLine` tee for long cold builds; VM URI scraped from the tool's own announcement. |
| `BinaryAppTarget` / `MacosAppTarget` / `WindowsAppTarget` | Fresh full `flutter build <os> --debug` → launch the binary directly. No compile channel afterwards. | Pass `launch(build: false)` to reuse an existing binary. Never opens an owning session. |
| Same targets, `ownership: AppOwnership.attachOnly` | The app is ALREADY running and stopping it is not the harness's call (ADR-0020): discovers the pid by binary name, verifies the running executable against `binaryPath` AND the on-disk build against the process start (an optional `BuildFingerprint` pin is stronger), attaches via the explicitly named `vmServiceUri` — and `stop()` never signals the process. | Ambiguous pgrep matches are an error naming the pids. Attach never builds. Attach cannot scrape a stdout it does not own — the URI is named by the owner. |
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
    final driver = await attachDriver(context.take<LaunchedApp>('app'));
    await driver.expectLabel('checkout'); // retry-until-rendered
    await driver.perform(const ClickAction(name: 'checkout'));
    final total = (await driver.snapshot())
        .nodes
        .map((node) => node.value)
        .firstWhere(
          (value) => value != null && value.startsWith(r'$'),
          orElse: () => null,
        );
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

## Driving widgets (`ToolkitDriver`)

- `attachDriver(app)` → a `ToolkitDriver` over the app's VM service.
  `snapshot()` → the semantic `AxNode` tree (label, role, bounds, and
  the selectable-text **`value`** — the deterministic way to read
  app-rendered data; clipboards and icon-only copy buttons are not).
- Act through the family actions (ADR-0038): `driver.perform(const
  ClickAction(name: 'submit'))`, `TypeAction`, key-press, named-route
  navigate, `evaluate` — the same vocabulary the MCP server and the
  invoke tier speak; `screenshot()` for a PNG.
- Observe with `expectLabel(needle)` / `labelContaining(needle)` —
  the retry-until-rendered loop (a tap lands before the next frame
  paints; verifying immediately reads the old tree), failing with a
  dump of the surface it actually saw.
- `WidgetDriver` was removed (ADR-0019) — one driver per wire; do not
  reintroduce per-package driver shells.
- `VmClient` extras: `extensionNames()` (discoverability),
  `evaluate(expr)`, `hotReload()`, `callExtensionUntil(...)` (folds the
  -32601-before-registration window, the isolate rebind, and the
  dropped-socket reconnect). Raw `reloadSources` **cannot compile**
  without an owning `flutter run`/`attach` session — treat `true` as
  "asked", not "recompiled".

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
