# Changelog

All notable changes to this package are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial extraction of the lifecycle-owning E2E harness core (ADR-0015),
  proven in production in the vosges project's `vosges_harness` package:
  `LogTap` (log buffer with `waitFor`), `Scenario`/`Check`/`HarnessContext`
  (composable steps with recorded assertions), `VmClient` (VM service
  attach, extension calls, evaluate, hot reload), `WidgetDriver`
  (snapshot/tap/enterText/findValue over the `ext.mcp.toolkit.*` service
  extensions), `BinaryAppTarget`/`LaunchedApp` with `MacosAppTarget` and
  `WindowsAppTarget` presets, and `ToolkitExtensions` (the extension verb
  name list).
