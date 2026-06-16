# test_app

Example Flutter app for **mcp_toolkit** (semantic snapshot, dynamic tools, MCP extensions).

## Showcase (capture routing)

The **Capture** section embeds `showcase.platform.stub`:

| Target | Widget            | Registration                                 |
| ------ | ----------------- | -------------------------------------------- |
| macOS  | `AppKitView`      | `ShowcasePlatformViewFactory.swift`          |
| Web    | `HtmlElementView` | `registerShowcasePlatformView()` in `main()` |

Implementation uses conditional imports: `lib/platform_view_showcase_{stub,macos,web}.dart`.

**macOS (repo root):** `make showcase-stop && make showcase` — prints VM `wsUri`.

### Web showcase testing

| Goal | Command |
|------|---------|
| **Interactive dev** — keep Chrome running, run tools manually | `make web-showcase` (terminal 1), then `export WS_URI=…` and `make exec-sweep-web` (terminal 2) |
| **CI / one-shot battery** — launch, doctor, validate-runtime, webmcp, enter-text proof, exec sweep, teardown | `make web-showcase-tests` |

Scripts: `scripts/run_web_showcase.sh` (launch), `scripts/run_exec_sweep.sh` (per-tool exec), `scripts/run_web_showcase_tests.sh` (all-in-one). Artifacts land in `.showcase/tool_verify/web/`.

**macOS exec sweep** (showcase already running):

```bash
export WS_URI="$(grep -Eo 'ws://127\.0\.0\.1:[0-9]+/[A-Za-z0-9_=-]+/ws' .showcase/flutter_app.log | tail -1)"
make exec-sweep
```

**Web exec sweep only** (after `make web-showcase`):

```bash
export WS_URI="$(grep -Eo 'ws://127\.0\.0\.1:[0-9]+/[A-Za-z0-9_=-]+/ws' .showcase/web_app.log | tail -1)"
make exec-sweep-web
```

For scored dogfood iterations and harness compare, use `bash tool/evals/run_dogfood_eval.sh` instead.

**Chrome (web CDP smoke):**

```bash
flutter run -d chrome --web-port=8080 --host-vmservice-port=8181
# Optional if CDP discovery fails:
# flutter-mcp-toolkit --web-browser-debugging-port <port> --flutter-device chrome ...
```

## MCP smoke (CLI)

1. From this directory, run on a device (macOS or Chrome example):

   ```bash
   flutter run --debug --machine --host-vmservice-port=8181 -d macos
   # or: -d chrome --web-port=8080
   ```

   Or use `make run`. Copy **`wsUri`** from the `app.debugPort` line in the machine output.

2. From **`mcp_server_dart`**, validate runtime and optional screenshots:

   ```bash
   dart run bin/flutter_mcp_toolkit.dart --flutter-device chrome \
     --web-browser-debugging-port <chrome-remote-debugging-port> \
     --save-images --output-dir ../.flutter_mcp/smoke validate-runtime \
     --target 'ws://127.0.0.1:8181/<token>/ws' \
     --timeout-ms 30000
   ```

   You can pass the same URI as global `--vm-service-uri` instead of `--target`.

3. **iOS Simulator:** if Xcode reports a Podfile.lock mismatch, run `cd ios && pod install`, then `flutter run` with the same VM flags.

## Getting Started

This project is a starting point for a Flutter application.

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/).
