---
'mcp_toolkit': major
'flutter_mcp_toolkit_core': major
'flutter_mcp_toolkit_capability_kernel': major
'flutter_mcp_toolkit_capability_core': major
'flutter_mcp_harness': major
---

### ⚠ BREAKING CHANGES

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