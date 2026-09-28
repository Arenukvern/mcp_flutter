# Changelog

All notable changes to this package are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `ToolkitExtensions` values now derive from
  `flutter_mcp_toolkit_core`'s `ToolkitExtensionNames` (single source of
  truth; harness `flutter_mcp_toolkit_core` dependency added).
- `ToolkitDriver.perform` handles `ScrollAction`: direction + distance
  route through `ext.mcp.toolkit.scroll`; in-band refusals surface as
  `ProtocolException` with the app's error and hint.

### Added

- `ToolkitDriver` (`toolkit_driver.dart`): the toolkit's
  `AutomationDriver` implementation over the `ext.mcp.toolkit.*`
  extensions — semantic `AxNode` snapshots with bounds and refs, click /
  type / key-press / named-route navigate / evaluate actions, PNG
  screenshots via `view_screenshots` — passing the
  `universal_automation_conformance` driver suite (ADR-0038 adoption).
- `ToolkitExtensions.viewScreenshots` constant (`ext.mcp.toolkit.view_screenshots`).
- `IntentDriverRouter` (`intent_driver_router.dart`): ADR-0038
  driver-routed invocation — resolves an intent's `IntentAutomationHint`
  (transport + verb + locator, plus invocation operands) into a
  `AutomationAction` on the bound driver. `showcase/drivers/bin/
  drive_flutter.dart` proves it live (routed click/type/navigate against
  the demo app).
- `intentcall_core` dependency for the hint types.
- Showcase drive programs (`showcase/drivers/bin/drive_flutter.dart` +
  `drive_web.dart`, in the `showcase/drivers` composition package): one
  driver contract across the instrumented Flutter and browser tiers,
  with screencast receipts via `universal_screencast` — the Flutter side
  through the composition-owned `FlutterAppFrames` adapter over this
  package's `VmClient`, the browser side through
  `CdpScreencastFrameSource`.

### Changed

- BREAKING (dependency hygiene): `universal_screencast` and
  `universal_capture_flutter` are no longer dependencies — the harness
  library never imported them; the showcase drive programs moved to the
  `showcase/drivers` composition package, which owns the pipeline policy
  (dependency inversion: composition wires, libraries don't).
- `ChromeAppTarget.launch` polls the CDP endpoint (250 ms interval, 30 s
  deadline) instead of probing once — a single probe loses the race
  against Chrome's DevTools-socket boot on cold starts; launches pass
  `--force-renderer-accessibility` so headless pages expose their full
  accessibility tree.

- `tool/intentcall_session.dart`: the IntentCall showcase doors (link
  discover, bridge ping, MCP serve) as a checked-in Dart composition root.
  Resolves the target VM from `--vm-service-uri` or the freshest
  announcement in the showcase log, and the IntentCall CLI from
  `INTENTCALL_ROOT`, sibling checkouts, or `PATH`.
- `vm_service_uri.dart`: `canonicalVmServiceWsUri` (shared http→ws
  conversion, now also used by `VmClient.connect` and the showcase),
  `lastVmServiceUriIn`, and `lastVmServiceWsUriIn` (freshest-announcement
  log scraping).
- `FlutterRunTarget` (ADR-0015): the owning interactive `flutter run`
  session (device + extra args), scraping the VM service announcement from
  the tool's own output — the lifecycle mode behind the showcase launch
  (`tool/showcase.dart`), complementary to the fresh-binary
  `BinaryAppTarget`. Used by the Dart rewrite of the former
  `scripts/run_showcase.sh`, `run_web_showcase.sh`, and
  `stop_showcase.sh`.
- `LogTap.stream` for live tailing; `vm_service_uri.dart` exports the
  shared VM-URI patterns (including the web `ws://` form).
- Environment layering fix in all process targets: an empty `environment`
  map now inherits the parent environment unchanged instead of wiping it.

### Changed

- `scripts/run_showcase.sh`, `run_web_showcase.sh`, `stop_showcase.sh`
  became deprecated wrappers around `dart run
  packages/harness/tool/showcase.dart` (macOS / `--web` / `--stop`).

### Removed

- Runtime generation of `.showcase/intentcall_examples.sh` by the showcase
  launcher (generated shell scripts were an unreliable pattern). The same
  doors are the checked-in `tool/intentcall_session.dart`.

### Added (initial extraction)

- Initial extraction of the lifecycle-owning E2E harness core (ADR-0015),
  proven in production in the vosges project's `vosges_harness` package:
  `LogTap` (log buffer with `waitFor`), `Scenario`/`Check`/`HarnessContext`
  (composable steps with recorded assertions), `VmClient` (VM service
  attach, extension calls, evaluate, hot reload), `WidgetDriver`
  (snapshot/tap/enterText/findValue over the `ext.mcp.toolkit.*` service
  extensions), `BinaryAppTarget`/`LaunchedApp` with `MacosAppTarget` and
  `WindowsAppTarget` presets, and `ToolkitExtensions` (the extension verb
  name list).
