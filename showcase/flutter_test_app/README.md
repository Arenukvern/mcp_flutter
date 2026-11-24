# flutter_test_app — canonical fmtk showcase (ADR-0024)

Product-facing demo for **flutter-mcp-toolkit**: default route is a
**shipments** flow (form validation, async create, list updates). Maintainer
interaction fixtures live under **`/qa`** (formerly the home kitchen-sink).
Dogfood visual fixture: `/visual-reconstruct` via `DOGFOOD_VISUAL`.

## Launch

```bash
# macOS interactive (repo root)
dart run packages/harness/tool/showcase.dart

# Chrome
dart run packages/harness/tool/showcase.dart --web
```

VM URI: `showcase/flutter_test_app/.flutter_mcp/runner-session.json` →
`vm_service_uri` (not log grep).

## Validation

| Goal | Command |
|------|---------|
| Interactive dev + exec sweep | `dart run packages/harness/tool/showcase.dart --web`, then `dart run packages/harness/tool/exec_sweep.dart` (PLATFORM=web) |
| One-shot web battery | `dart run packages/harness/tool/web_showcase_tests.dart` |

Artifacts: `.showcase/tool_verify/web/`.

## Custom tools

Teaching example: [`mcp_toolkit/example/fibonacci_tool_example.dart`](../../mcp_toolkit/example/fibonacci_tool_example.dart). This app registers `buildCalculateFibonacciTool()` for integration/catalog tests only.

## Examples map

[`docs/contributing/examples_map.md`](../../docs/contributing/examples_map.md)