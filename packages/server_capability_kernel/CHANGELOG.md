# Changelog

## 8.0.0

### Major Changes

- ### ⚠ BREAKING CHANGES
  
  - **cli:** Global port flags (`--dart-vm-port`, `--web-browser-debugging-port`, `--web-port`, and CDP-related CLI options) now reject leading-zero decimals (`08181`), signed (`+8181`), hex (`0x1F`), whitespace-padded, and out-of-range values with exit **64** and a JSON error envelope. **7.2.1** used `int.tryParse` and accepted those forms on every CLI port flag.
  - **core:** `parseStrictPositiveDecimalPort` rejects leading-zero decimals and other non-canonical port strings everywhere connection overrides and resource URIs are parsed.
  
  ### Features
  
  - **server:** `--idle-exit-minutes` exits idle stdio server processes after *N* minutes with no MCP traffic and no VM service connection (`0` disables; default). ([#190](https://github.com/Arenukvern/mcp_flutter/pull/190))
  - **cli:** `flutter-mcp-toolkit init zcode` targets real ZCode MCP config paths, resolves `flutter-mcp-toolkit-server` to an absolute path when the binary is on `PATH`, merges without overwriting existing servers, and vendors a curated user-facing skill set. ([#190](https://github.com/Arenukvern/mcp_flutter/pull/190))
  
  ### Bug Fixes
  
  - **Release ([#190](https://github.com/Arenukvern/mcp_flutter/pull/190)):** Shared release libs for publish, asset-conflict check, and runner-shortage retry; plan-mode contract tests call real fetch/callback chains (no production contract-env switches); clobber-safe published uploads; strict `checksums.txt` superset before clobber on published releases.
  - **ci:** Pin Flutter **3.50.1** stable, Dart **3.14.0**, and `test` **1.32.0** for SDK `test_api` **0.7.14**; refresh hosted-only root `pubspec.lock` (no `source: path` entries).
  - **ci:** Hosted **oka_harness** **0.11.0** train and consumer pin; restore **0.11.0** `AndroidAppTarget` child argv contract (`dev android --json …`).
  - **deps:** Pin hosted **`intentcall_session`** and **`intentcall_codegen`** at **^1.2.1** (resolves fj2j `jsonDecodeNullableString` clash; restore runtime codegen in `server_capability_core`).
  
  ### Documentation
  
  - Regenerated CLI and server flag reference for strict ports and `--idle-exit-minutes`.
## [8.1.0] - 2026-11-26

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit 8.1.0 release.

## [7.2.3] - 2026-11-20

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit 7.2.3 release.

## [7.2.1] - 2026-11-18

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit 7.2.1 release.

## [7.2.0] - 2026-11-17

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit 7.2.0 release.

## [7.1.1] - 2026-11-11

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit 7.1.1 release.

## [7.1.0] - 2026-11-10

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit 7.1.0 release.

## [7.0.2] - 2026-11-07

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit 7.0.2 release.

## [7.0.1] - 2026-10-17

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit 7.0.1 release.

## [7.0.0] - 2026-10-03

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit 7.0.0 release.

## [6.0.0] - 2026-10-02

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit 6.0.0 release.

## [5.1.0] - 2026-08-23

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit 5.1.0 release.

## [5.0.4] - 2026-08-23

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit 5.0.4 release.

## [5.0.3] - 2026-08-23

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit 5.0.3 release.

## [5.0.2] - 2026-08-23

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit 5.0.2 release.

## [5.0.1] - 2026-08-22

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit 5.0.1 release.

## [5.0.0] - 2026-08-22

### Changed

- Align package version and hosted sibling dependency constraints as part of the 5.0.0 release.

## [4.0.0-dev.8] - 2026-07-31

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit 4.0.0-dev train.

## [4.0.0-dev.7] - 2026-07-18

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit 4.0.0-dev train.

## [4.0.0-dev.6] - 2026-07-05

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit 4.0.0-dev train.

## [4.0.0-dev.5] - 2026-06-21

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit 4.0.0-dev train.

## [4.0.0-dev.4] - 2026-06-18

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit 4.0.0-dev train.

## [4.0.0-dev.3] - 2026-06-18

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit 4.0.0-dev train.

## [4.0.0-dev.1] - 2026-06-06

### Changed

- Align package version and hosted sibling dependency constraints with the Flutter MCP Toolkit breaking prerelease train.

## [0.1.0] - 2026-05-22

### Added

- Raised Dart SDK floor to `>=3.12.0 <4.0.0`.
- Initial pub.dev release (renamed from `mcp_capability_kernel`).
- Capability contracts, host services, tool/resource registration helpers.

