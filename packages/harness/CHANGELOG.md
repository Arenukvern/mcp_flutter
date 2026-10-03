# Changelog

All notable changes to this package are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [7.0.0] - 2026-10-03

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit 7.0.0 release.

## [6.0.0] - 2026-10-03

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit 6.0.0 release. The package now shares the toolkit train version (0.2.1 had identical content; the 0.x line was the pre-train history).

### Breaking (ADR-0019 — layering: targets, session, driver, scenario)

- **`WidgetDriver` removed.** One driver per wire: use `attachDriver(app)`
  + `ToolkitDriver.perform(...)` with the family actions
  (`ClickAction(name: 'connect')`, `TypeAction`, …). `findRef` →
  locators, `tapUntil` → a retry loop over `perform` + your condition,
  `findValue` → a `snapshot()` scan of `node.value`.
- New session layer, promoted from the showcase drives:
  `attachDriver(LaunchedApp)` and the observe helpers
  `labelContaining` / `expectLabel` (retry-until-rendered, with the
  surface dump in the failure).
- `HarnessContext.take<T>` fails with a named `StateError` (bag keys
  listed) instead of a raw `TypeError`.
- The package re-exports `universal_automation_interface` — one import
  drives the whole family contract.

## [0.2.1] - 2026-10-02

### Fixed

- Floors follow the 6.0.0 train: `flutter_mcp_toolkit_core` ^6.0.0 (the
  0.2.0 artifact on pub.dev pinned ^5.1.0 and cannot resolve next to
  mcp_toolkit 6.x) and `intentcall_core` ^1.1.0 (the `custom`
  automation action this package's router switches on shipped in
  intentcall_core 1.1.0 — a consumer resolving 1.0.0 compiled fine and
  failed at build).

## [0.2.0] - 2026-10-02

### Added

- **Invoke tier (ADR-0017)**: surface actions, registry-native.
  `ToolkitDriver` now implements `AutomationActionCatalog` — `actions()`
  lists the app's agent-call registry (the single action source) via the
  new `agent_catalog` wire verb, and `InvokeAction(name, args)` dispatches
  through `agent_invoke`, validating arguments against the registered
  JSON schema (`intentcall_schema`) before the wire.
- `IntentDriverRouter` routes `IntentAutomationAction.custom` hints to
  `InvokeAction` (catalog name under `locator['name']`; invocation
  arguments pass through as the action args).
- Requires `universal_automation_interface` ^0.2.0 (the `InvokeAction`
  sealed case is a breaking addition for exhaustive switches).

## [0.1.1] - 2026-10-01

### Changed

- `intentcall_core` (and dev `intentcall_schema`) now pin `^1.0.0` — the
  train that carries the stable projection API. This package is published
  to pub.dev and its hosted consumers (oka) resolve these on pub.dev, so
  the published surface pins a real floor instead of an unconstrained
  range. In-repo proof consumers remain version-free per
  `docs/intentcall/README.md`; the consumer gate exempts this file.

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
