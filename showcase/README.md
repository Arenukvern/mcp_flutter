# Showcase

Examples that test the whole stack — the Flutter MCP toolkit, the
harness, and the `universal_automation_*` driver family — composed the
way Flutter and oka compose things: small declarative pieces, one
contract each, validated before anything runs.

Every example proves the same claim at a different tier: **one
`AutomationDriver` observe/act/verify loop, three ways in.**

| Tier | Target | Driver | Transport |
|---|---|---|---|
| Instrumented | [`flutter_demo/`](flutter_demo/) (Flutter app) | `ToolkitDriver` (`packages/harness`) | Dart VM service (`ext.mcp.toolkit.*`) |
| Browser | [`web_demo/`](web_demo/) (static page in Chrome) | `CdpDriver` (`universal_browser_cdp`) | Chrome DevTools Protocol |
| OS-native | *(no example needed — the machine itself)* | `CaptureKit*` (`universal_capture_macos`) | Swift bridge via Dart native assets |

## Examples

### `flutter_demo/` — the instrumented tier

A deliberately small Flutter app bound to `MCPToolkitBinding`: a counter
button, a text field, and a named `/profile` route. Every control has a
plain text label so a `ToolkitDriver` can resolve it from a semantic
snapshot by name — exactly how the toolkit's MCP tools resolve widgets.

Driven end-to-end by:

```bash
make drive-flutter            # macOS (first build takes minutes)
make drive-flutter-chrome     # Flutter web
```

or directly:

```bash
dart run packages/harness/tool/drive_flutter_demo.dart
```

The drive tool: observes the semantic tree → taps `Increment` ×3 →
types `Ada` into `Name` → verifies `Count: 3` → captures a PNG →
streams PNG frames from the app through the `universal_screencast`
pipeline into a file recorder → pushes the `/profile` route and verifies
the greeting. Artifacts land in `.showcase/`.

### `web_demo/` — the browser tier

A dependency-free static page (counter, input, profile section) served
by `serve.dart` and driven in Chrome:

```bash
make drive-web                # headless Chrome
make drive-web VISIBLE=1      # watch it
```

or directly:

```bash
dart run packages/harness/tool/drive_web_demo.dart
```

Same loop, different transport: the CDP accessibility tree for
observation, `Input.dispatchMouseEvent`/`insertText` for action, the
page's own screencast domain for frames.

### The macOS tier

No app to write — the OS-native tier observes apps that never opted
into any protocol. Try it from the family repo:

```bash
cd ../../../xs/storage_problem/dart_flutter_packages
dart test pkgs/universal_capture_macos   # screenshots + ScreenCaptureKit stream
```

## Why these demos exist

1. **Compositional proof.** The harness target brings up the app, the
   driver speaks one contract, the screencast pipeline accepts any
   frame source and any sink — the pieces interlock without adapters
   because they were designed to (`universal_automation_interface`).
2. **Conformance, not vibes.** `ToolkitDriver` and
   `ToolkitFrameSource` both pass the family's conformance suites
   (`universal_automation_conformance`) in unit tests; these demos are
   the live end-to-end pass.
3. **An OSS on-ramp.** Each demo is a page or ~100-line app: the
   smallest honest thing that exercises the real surfaces.

## Layout

```
showcase/
├── README.md              ← you are here
├── flutter_demo/          ← instrumented Flutter target (mcp_toolkit bound)
└── web_demo/              ← static page + serve.dart (CDP target)
```

Drive programs live next to the harness they drive:
`packages/harness/tool/drive_flutter_demo.dart` and
`drive_web_demo.dart`.
