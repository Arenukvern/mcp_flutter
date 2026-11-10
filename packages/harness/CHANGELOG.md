# Changelog

All notable changes to this package are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),

## [Unreleased]

### Changed

- `universal_automation_interface` moves to `^0.4.0`; `universal_browser_cdp`
  to `^0.5.0`. Dev `universal_automation_conformance` is pinned from git until
  pub.dev republishes with the interface `0.4` train floor (hosted `0.3.1`
  still constrains `^0.3.0`).

### Fixed

- `ToolkitDriver` tap/enter_text now surface the app-side refusal
  (`success: false` — ref not found, stale ref, disabled control,
  `target_outside_viewport` with its reveal hint) as `ProtocolException`
  instead of reporting a silent ok. Mirrors the live-proven fix in
  `universal_driver_flutter` 0.1.1.
