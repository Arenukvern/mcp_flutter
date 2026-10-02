# Changelog

All notable changes to this package are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `bin/drive_flutter.dart` + `bin/drive_web.dart`: live end-to-end drives
  for `showcase/flutter_demo` and `showcase/web_demo` — one
  `AutomationDriver` contract across the instrumented and browser tiers
  (`make drive-flutter` / `drive-flutter-chrome` / `drive-web`), with
  screencast receipts under `.showcase/` and hint-routed invocation via
  `IntentDriverRouter`.
- `FlutterAppFrames` (`lib/flutter_app_frames.dart`): the composition-owned
  `FrameSource` over the harness's `VmClient` — the dependency-inversion
  seam that keeps `flutter_mcp_harness` free of pipeline dependencies.
