# Changelog

All notable changes to this package are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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
