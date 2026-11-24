# Showcase

Examples that test the whole stack — the Flutter MCP toolkit, the
harness, and the `universal_automation_*` driver family — composed the
way Flutter and oka compose things: small declarative pieces, one
contract each, validated before anything runs.

Every example proves the same claim at a different tier: **one
`AutomationDriver` observe/act/verify loop, three ways in.**

| Tier | Target | Driver | Transport |
|---|---|---|---|
| Instrumented | [`flutter_test_app/`](flutter_test_app/) (canonical Flutter app) | `ToolkitDriver` (`packages/harness`) | Dart VM service (`ext.mcp.toolkit.*`) |
| Browser | [`web_demo/`](web_demo/) (static page in Chrome) | `CdpDriver` (`universal_browser_cdp`) | Chrome DevTools Protocol |
| OS-native | *(no example needed — the machine itself)* | `CaptureKit*` (`universal_capture_macos`) | Swift bridge via Dart native assets |

## Examples

### `flutter_test_app/` — canonical instrumented + product tier

The **product** surface (`/` shipments journey) and the **maintainer lab** (`/qa`)
share one instrumented app. End-to-end driver programs target the lab route
(counter, name field, `/profile`) while exec sweep and integration gates
exercise the same semantics.

```bash
make drive-flutter            # macOS (first build takes minutes)
make drive-flutter-chrome     # Flutter web
```

Recording: [E2E scenarios — instrumented tier](../docs/use-cases/e2e-scenarios.mdx).

```bash
dart run showcase/drivers/bin/drive_flutter.dart
```

The drive tool: navigates to `/qa` → observes the semantic tree → taps
`Increment` ×3 → types `Ada` into `Name` → verifies `Count: 3` → captures
a PNG → streams frames through `universal_screencast` → routes hints through
`IntentDriverRouter` → pushes `/profile` and verifies the greeting. Artifacts
land in `.showcase/`.

### `web_demo/` — the browser tier

A dependency-free static page (counter, input, profile section) served
by `serve.dart` and driven in Chrome:

```bash
make drive-web                # headless Chrome
make drive-web VISIBLE=1      # watch it
```

```bash
dart run showcase/drivers/bin/drive_web.dart
```

Same loop, different transport: the CDP accessibility tree for
observation, `Input.dispatchMouseEvent`/`insertText` for action, the
page's own screencast domain for frames.

## Layout

```
showcase/
├── README.md                    ← you are here
├── flutter_test_app/            ← canonical product + `/qa` maintainer lab (ADR-0025)
├── drivers/                     ← composition: drive programs + FlutterAppFrames
├── web_demo/                    ← static HTML + serve.dart (CDP tier)
└── fixtures/
    └── native_layer_capture_fixture/  ← CI capture tests only
```

### Examples index

| Goal | Path |
| --- | --- |
| Run the canonical app | `dart run packages/harness/tool/showcase.dart` |
| Custom tool sample | [`mcp_toolkit/example/fibonacci_tool_example.dart`](../mcp_toolkit/example/fibonacci_tool_example.dart) |
| Code-first drive | [`drivers/bin/drive_flutter.dart`](drivers/bin/drive_flutter.dart) |
| Full map | [`docs/contributing/examples_map.md`](../docs/contributing/examples_map.md) |

Session discovery: `showcase/flutter_test_app/.flutter_mcp/runner-session.json` (not log grep).

`flutter_test_app` exercises every product hook; `web_demo` is the smallest
honest CDP target the `drivers/` programs can drive in headless Chrome.

#### Dependency inversion

Drive programs live in `showcase/drivers`: composition depends on the harness
and `universal_screencast` without dragging screencast into `flutter_mcp_harness`.
[`FlutterAppFrames`](drivers/lib/flutter_app_frames.dart) is the seam over the
harness `VmClient`, owned by the composition that needs it.