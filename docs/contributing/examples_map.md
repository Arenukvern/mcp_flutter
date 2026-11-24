# Examples map (fmtk monorepo)

Canonical index of runnable samples. ADR: [0025](../decisions/0025_canonical_showcase_and_demo_pipeline.mdx).

## Top-level map

| You want… | Start here |
| --- | --- |
| **Product demo app** | [`showcase/flutter_test_app`](../../showcase/flutter_test_app/README.md) → `dart run packages/harness/tool/showcase.dart` |
| **CDP browser tier** | [`showcase/web_demo`](../../showcase/web_demo/) |
| **Custom MCP tool in Flutter** | [`mcp_toolkit/example/fibonacci_tool_example.dart`](../../mcp_toolkit/example/fibonacci_tool_example.dart) |
| **Checked-in E2E drive** | [`showcase/drivers/bin/drive_flutter.dart`](../../showcase/drivers/bin/drive_flutter.dart) |
| **AgentCallEntry snippet** | [`mcp_toolkit/example/agent_call_entry_starter.dart`](../../mcp_toolkit/example/agent_call_entry_starter.dart) |
| **Harness two-instance pattern** | [`packages/harness/example/desktop_pair.dart`](../../packages/harness/example/desktop_pair.dart) |
| **Maintainer CLI tools** | [`packages/harness/tool/`](../../packages/harness/README.md#showcase) |

## Inventory

### Showcase (`showcase/`)

| Path | Audience | Runs today | Duplication / notes |
| --- | --- | --- | --- |
| `flutter_test_app` | Agent user, integration CI | Yes (gates, drives, macOS) | **Canonical**; `/` = shipments; `/qa` = interaction lab + `drive_flutter`; `/profile` = driver named-route |
| `web_demo` | Maintainer, CDP | Yes (`drive_web`) | Static HTML counter/profile |
| `drivers` | Maintainer | Yes | Composition over harness + screencast |
| `fixtures/native_layer_capture_fixture` | CI only | Yes (contract gates) | Android capture fixture — **not** a demo |

### Published package `example/`

| Package | Path | Audience | Compiles | Quality |
| --- | --- | --- | --- | --- |
| `mcp_toolkit` | `example/fibonacci_tool_example.dart` | pub.dev consumer | Yes | **Canonical custom tool** runnable app |
| `mcp_toolkit` | `example/agent_call_entry_starter.dart` | pub.dev consumer | Snippet | Hand-written entry pattern |
| `mcp_toolkit` | `lib/examples/fibonacci.dart` | Apps + integration | Yes | Demo helper `buildCalculateFibonacciTool()` (not barrel-exported; no API guarantee) |
| `flutter_mcp_toolkit_core` | `example/main.dart` | pub.dev consumer | Yes | Prints version + `ToolkitExtensionNames` |
| `flutter_mcp_toolkit_capability_core` | `example/main.dart` | pub.dev consumer | Yes | Capability type anchor |
| `flutter_mcp_toolkit_capability_kernel` | `example/main.dart` | pub.dev consumer | Yes | Kernel contract pointer |
| `flutter_mcp_harness` | `example/desktop_pair.dart` | Maintainer | Needs macOS app | Two-instance template |

### Harness tools (`packages/harness/tool/`)

| Tool | Audience | Replaces |
| --- | --- | --- |
| `showcase.dart` | Maintainer / docs | `scripts/run_*showcase*.sh` |
| `exec_sweep.dart` | CI, maintainer | `scripts/run_exec_sweep.sh` |
| `web_showcase_tests.dart` | CI web battery | `scripts/run_web_showcase_tests.sh` |
| `shot.dart`, `intentcall_session.dart`, … | Maintainer | — |

### Docs snippets (`docs/**/*.mdx`)

| Area | Source of truth today | Drift risk |
| --- | --- | --- |
| E2E `dart run showcase/drivers/…` | `tool/docs/example_snippets.yaml` + `dart run tool/docs/check_example_snippets.dart` | **Gated** — `<!-- example-snippet: id -->` fences |
| Quickstart `main()` bootstrap | Generated / hand-maintained in quickstart | Medium |
| Custom tools inline Dart | Partial duplicate of `mcp_toolkit` example | **Deduped** — link to fibonacci example |
| Tool list | `docs/reference/tools.mdx` | Generated via `make docs-reference` |

**Convention:** add an entry to `tool/docs/example_snippets.yaml`, a matching HTML comment before the fenced block in the doc, and (for commands) start/end sentinel comments in the driver source (`example-snippet` / `example-snippet-end`). CI **Docs contracts** job runs `dart run tool/docs/check_example_snippets.dart` and `dart run tool/docs/check_example_snippets_mutations.dart` (`make check-contracts` includes both).

### Skills (`skills/`, synced to plugin)

Sample code is procedural (Dart entrypoints). Link to this map for runnable paths.

### `mcp_server_dart`

No `example/` dir. Integration proof: `test/flutter_cli_example_app_integration_test.dart` + live `flutter_test_app`.

## Enforced convention

1. **`showcase/flutter_test_app`** — only app we show in marketplace hero / agent GIFs.
2. **`mcp_toolkit/example/fibonacci_tool_example.dart`** — only narrated custom-tool walkthrough in docs.
3. **`showcase/drivers`** — only narrated code-first E2E in docs (not `make`).
4. **One meaningful pub.dev `example/` per published package** — no trivial stubs.

## Toolkit parity (`flutter_test_app` vs `main` home)

**Before (main):** `ShowcaseScreen` was route **`/`**. **Now:** product journey on **`/`** + **`/shipments/new`**; **full toolkit lab** on **`/qa`**; dogfood visual on **`/visual-reconstruct`**.

### Automation that must reach `/qa`

| Runner | `/qa` navigation |
| --- | --- |
| `packages/harness/tool/exec_sweep.dart` | `navigate` push `/qa` before widget sweeps |
| `tool/evals/run_runtime_enter_text_greeting.dart` | `navigate` push `/qa` before `greeting_input_field` |
| `mcp_server_dart/test/flutter_*_example_app_integration_test.dart` | `navigate` push `/qa` before snapshot/capture |
| `showcase_reactivity_test.dart` | pumps `ShowcaseScreen` directly (no route) |
| `drive_flutter` | `NavigateAction` → `/qa` at start of scenario |
| `drive_web` | `showcase/web_demo` (CDP tier; unchanged) |

### Sections on `/qa` (parity with former main home)

Capture (platform view) · Visual reconstruct link · Tap/counter (+ `Count:` label for drives) · Type/greeting (`Name` label) · Toggle · Slider · Scroll · Iterate/hot reload · Inspect/logs/dialog · **Open profile** → `/profile`.

## Deferred

- Merge harness exec tools into a single documented index page with tier tags (roadmap).
