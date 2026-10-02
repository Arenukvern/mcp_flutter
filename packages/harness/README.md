# flutter_mcp_harness

Programmatic E2E harness for Flutter apps: **own the whole lifecycle** —
build the app, launch the process, attach to its Dart VM service, and only
then drive/assert. The driving layer speaks the same `ext.mcp.toolkit.*`
service extensions the MCP server exposes — as a plain Dart API, no MCP
transport required.

This is the client-side counterpart of `mcp_toolkit`, extracted from a
production E2E loop (see [ADR-0015](../../decisions/0015_flutter_mcp_harness_extraction.mdx)).
A guided tour lives in the
[E2E scenarios guide](../../docs/guides/e2e_scenarios.mdx).

## Quick start

```dart
import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';

LaunchedApp? app;
var passed = false;
try {
  final scenario = Scenario('smoke', steps: [
    ('launch', (context) async {
      app = await MacosAppTarget(
        projectDir: 'my_app',
        binaryPath: 'my_app/build/macos/Build/Products/Debug/My App.app/Contents/MacOS/My App',
      ).launch(); // full `flutter build macos --debug`, then run the binary
      await app!.stdout.waitFor('app ready'); // wait on logs, never sleep
      context.report.pass('attached at ${app!.vmUri}');
    }),
    ('drive + assert', (context) async {
      final driver = WidgetDriver(await app!.vm());
      final ref = await driver.findRef('login');
      if (ref == null) return context.report.fail('no login button');
      await driver.enterText(await driver.findRef('email'), 'me@example.com');
      await driver.tap(ref);
      final banner = await driver.findValue((v) => v.contains('Welcome'));
      banner != null
          ? context.report.pass('login confirmed')
          : context.report.fail('no welcome banner');
    }),
  ]);
  passed = await scenario.run();
  scenario.report.printSummary();
} finally {
  await app?.stop(); // cleanup always runs
}
exit(passed ? 0 : 1);
```

Full two-instance composition root (host + controller pairing):
[`example/desktop_pair.dart`](example/desktop_pair.dart).

## Why this shape

An earlier harness attempt was a declarative YAML runner on top of the MCP
server — and never owned the hard parts. The valuable 80% is the boring 20%:

1. **Own the build.** Run `flutter build <os> --debug` yourself, then launch
   the binary directly. No `flutter run`, whose incremental-kernel and
   tool-respawn behavior is flaky under automation.
2. **Own the VM.** Scrape the VM service URI from the child's own stdout and
   connect over the `vm_service` package ([VmClient]). From there: list
   extensions, call toolkit extensions directly (semantic snapshot, tap,
   enter text), evaluate, hot-reload — no subprocess, no JSON parsing, no
   sticky state files.
3. **Own the process lifecycle.** [LaunchedApp] keeps the `Process`, a
   broadcast [LogTap] on its stdout, and the [VmClient]. Scenarios stop what
   they started, in `finally`.

Only on top of those is a [Scenario] worth anything: named steps over a
HarnessContext (a report + a bag for passing values between steps), first
failure aborts, cleanup still runs, exit code reflects the result.

## API map

| You want to… | Reach for |
|---|---|
| Launch an owning interactive `flutter run` (hot reload, showcase) | `FlutterRunTarget` |
| Fresh full build → direct binary launch (no compile channel after) | `BinaryAppTarget`, `MacosAppTarget`, `WindowsAppTarget` |
| Attach to an app someone else owns (dev runner session, ADR-0014) | construct `LaunchedApp` around the owning process |
| Wait for log lines / assert on output | `LogTap.waitFor` / `firstMatch` / `count` / `tail` |
| Drive the UI | `WidgetDriver`: `snapshot`, `findRef`, `tap`, `tapUntil`, `enterText`, `scroll`, `findValue` |
| Drive the UI through the universal `AutomationDriver` contract | `ToolkitDriver`: `snapshot` (semantic `AxNode` tree), `perform` (click/type/keys/navigate/evaluate), `screenshot` |
| Stream frames from a running app / browser | frame sources + `universal_screencast` — composition-level, see `showcase/drivers` (the harness itself stays pipeline-free) |
| Structure steps, assertions, cleanup | `Scenario`, `Check`, `ScenarioReport`, `HarnessContext`, `retry` |
| Evaluate Dart / hot-reload / discover extensions in the app | `VmClient.evaluate` / `hotReload` / `extensionNames` |
| Reference the toolkit verb names | `ToolkitExtensions` (mirrors `mcp_toolkit`'s interaction toolkit) |

## Layout

- `lib/src/log_tap.dart` — line buffer + `waitFor(pattern)` (no sleeps).
- `lib/src/vm_client.dart` — WebSocket VM service connection, extension
  calls, evaluate, hot reload.
- `lib/src/flutter_app.dart` — `AppTarget`/`LaunchedApp`;
  [BinaryAppTarget] with `MacosAppTarget`/`WindowsAppTarget` presets.
  Android/iOS device bring-up belongs to the owning dev session
  (see `oka_harness`, which follows the
  [runner-session contract](../../decisions/0014_external_dev_sessions_runner_delegation.mdx)).
- `lib/src/flutter_run.dart` — [FlutterRunTarget], the owning interactive
  `flutter run` session (hot reload via stdin; the showcase launch path).
- `lib/src/widget_driver.dart` — typed snapshot/tap/enterText/findValue over
  the toolkit service extensions.
- `lib/src/toolkit_driver.dart` — the toolkit's `AutomationDriver`
  implementation (ADR-0038): one observe/act/verify vocabulary shared with
  the CDP and OS-native drivers; passes the family conformance suite
  (`universal_automation_conformance`) against the same canned-extension
  seam.
- `lib/src/toolkit_extensions.dart` — the extension verb names the driver
  calls (source of truth: `mcp_toolkit`'s interaction toolkit).
- `lib/src/scenario.dart`, `lib/src/check.dart` — steps, checks, report.
- `example/desktop_pair.dart` — a full two-instance composition root.
- `tool/showcase.dart` — this repo's showcase launcher (macOS / `--web` /
  `--stop`), the Dart rewrite of the former `scripts/*.sh` showcase.
- The end-to-end showcase drives live in
  [`showcase/drivers/`](../../showcase/drivers/) — composition roots that
  wire this package to the frame pipeline (keeps pipeline dependencies
  out of the harness pubspec).
- `tool/intentcall_session.dart` — IntentCall doors against a running
  showcase (discover / bridge ping / MCP serve), a checked-in composition
  root — nothing under `.showcase/` is generated at runtime.

## Running

```sh
cd packages/harness
dart test
dart run example/desktop_pair.dart --skip-build
```

Scenario entrypoints live in the *consuming project* (composition roots are
project knowledge, not package code).

## Showcase

The repo showcase is itself a composition root over this package
(`tool/showcase.dart`, the Dart rewrite of the former `scripts/run_showcase.sh`
family):

```sh
make showcase        # macOS showcase, interactive foreground (r/R/q relayed)
make web-showcase    # Chrome with WebMCP flags (--web --detach for CI-shaped runs)
make showcase-stop   # idempotent teardown of stray sessions and the VM port
```

Logs and pid files land under `.showcase/`; the detached web variant prints
`WS_URI=…` and exits once the VM service is reachable.

IntentCall doors against the running showcase (second terminal):

```sh
dart run packages/harness/tool/intentcall_session.dart demo         # discover + bridge ping
dart run packages/harness/tool/intentcall_session.dart serve-debug  # MCP door pinned to this VM
```

The session tool resolves the VM service URI from the freshest announcement
in the showcase log (or `--vm-service-uri`) and the IntentCall CLI from
`INTENTCALL_ROOT`, sibling checkouts, or `PATH`.

## Web targets

Chrome/Chromium scenarios run through [ChromeAppTarget]
(`lib/src/chrome_app_target.dart`): same ownership philosophy — own the
process, publish the endpoint, attach the client — but the protocol
client is `universal_browser_cdp` (CDP), not the VM service, so it
produces a [LaunchedChrome] rather than a [LaunchedApp]. The compile
step is deliberately absent: serve the web build yourself and point
`startUrl` at it. A port already answering CDP is adopted as a borrowed
session and never killed. Real-Chrome smoke: `XS_TEST_CHROME=1 dart test`.

## Automation drivers (universal_automation_* family)

[ToolkitDriver] implements the `universal_automation_interface`
`AutomationDriver` contract over the same `ext.mcp.toolkit.*` extensions
[WidgetDriver] speaks — ADR-0038's adoption of the shared automation
kernel. Agents get one observe/act/verify vocabulary across the
instrumented tier (this package), the browser tier
(`universal_browser_cdp`'s [CdpDriver]), and the OS-native tier, plus the
family conformance suite for free in tests. Locator grammar: `name`
matches snapshot labels, `role` matches semantic roles, `css` accepts a
snapshot ref (`s_12`) or a label; navigation maps to the toolkit's named
routes and refuses loudly otherwise.

## Relationship to the MCP server

The server (`mcp_server_dart`) exposes the same toolkit primitives as MCP
tools (`fmt_*`) for interactive agent sessions. This package is the
programmatic path: repeatable E2E scenarios as checked-in Dart, no MCP
client needed. It adds no toolkit verbs and never owns app compilation; when
an external dev runner owns the session, connect to its published
`vm_service_uri` directly (ADR-0014).
