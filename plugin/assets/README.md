# Plugin store assets

| File | Size | Purpose |
|------|------|---------|
| `icon.png` | 256×256 | Codex `interface.composerIcon` |
| `logo.png` | 512×512 | Codex `interface.logo`, Cursor listing |
| `screenshot-1.png` | 1280×800 | Live `flutter_test_app` capture (`validate-runtime`, flutter_layer) |
| `screenshot-2.png` | 1280×800 | Live `fmt_list_client_tools_and_resources` output (21 tools) |

Regenerate: run `flutter_test_app` on macOS port 8181, then from `mcp_server_dart`:

```bash
dart run bin/flutter_mcp_toolkit.dart --save-images --output-dir ../plugin/assets/.capture \
  validate-runtime --target '<ws_uri>' --timeout-ms 45000

dart run bin/flutter_mcp_toolkit.dart exec \
  --name fmt_list_client_tools_and_resources --args '{}' --vm-service-uri '<ws_uri>'
```

Icons: derived from `original_logo.png` via `sips -z` (256 / 512). Keep `original_logo.png` as source of truth. The original logo was generated with Gemini (nano-banana).

## How to capture screenshots

1. Run `flutter_test_app` (or your app) in **debug** with `mcp_toolkit` initialized.
2. Register a sample tool (see [Creating dynamic tools](../../docs/guides/creating_dynamic_tools.mdx)).
3. Use `fmt_capture_ui_snapshot` or `fmt_get_screenshots` from a connected agent, or OS screenshot.
4. Prefer showing: running app UI + proof of custom tool in `fmt_list_client_tools_and_resources` output.

## Branding

- Flutter blue `#02569B` is set in `plugin/.codex-plugin/plugin.json` → `interface.brandColor`.
- Copy for listings: [docs/ai_agents/marketplace_copy.yaml](../../docs/ai_agents/marketplace_copy.yaml).

## Submission

See [Marketplace submission runbook](../../docs/contributing/marketplace_submission_runbook.mdx).
