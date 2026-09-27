# flutter_mcp_harness

Programmatic E2E harness for Flutter apps: **own the whole lifecycle** —
build the app, launch the process, attach to its Dart VM service, and only
then drive/assert. The driving layer speaks the same `ext.mcp.toolkit.*`
service extensions the MCP server exposes — as a plain Dart API, no MCP
transport required.

This is the client-side counterpart of `mcp_toolkit`, extracted from a
production E2E loop (see [ADR-0015](../../decisions/0015_flutter_mcp_harness_extraction.mdx)).

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
- `lib/src/toolkit_extensions.dart` — the extension verb names the driver
  calls (source of truth: `mcp_toolkit`'s interaction toolkit).
- `lib/src/scenario.dart`, `lib/src/check.dart` — steps, checks, report.
- `example/desktop_pair.dart` — a full two-instance composition root.
- `tool/showcase.dart` — this repo's showcase launcher (macOS / `--web` /
  `--stop`), the Dart rewrite of the former `scripts/*.sh` showcase.

## Running

```sh
cd packages/harness
dart test
dart run example/desktop_pair.dart --skip-build
```

Scenario entrypoints live in the *consuming project* (composition roots are
project knowledge, not package code).

## Relationship to the MCP server

The server (`mcp_server_dart`) exposes the same toolkit primitives as MCP
tools (`fmt_*`) for interactive agent sessions. This package is the
programmatic path: repeatable E2E scenarios as checked-in Dart, no MCP
client needed. It adds no toolkit verbs and never owns app compilation; when
an external dev runner owns the session, connect to its published
`vm_service_uri` directly (ADR-0014).
