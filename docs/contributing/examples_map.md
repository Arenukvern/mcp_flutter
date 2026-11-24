# Examples map (fmtk monorepo)

Canonical index of runnable samples. ADR: [0025](../decisions/0025_canonical_showcase_and_demo_pipeline.mdx).

## Top-level map

| You want… | Start here |
| --- | --- |
| **Product demo app** | [`showcase/flutter_test_app`](../../showcase/flutter_test_app/README.md) → `dart run packages/harness/tool/showcase.dart` |
| **Minimal harness target** | [`showcase/flutter_demo`](../../showcase/flutter_demo/README.md) |
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
| `flutter_test_app` | Agent user, integration CI | Yes (gates, optional macOS integration) | **Canonical product**; `/` = shipments; `/qa` = interaction lab; `/visual-reconstruct` = dogfood visual |
| `flutter_demo` | Maintainer, harness GIF prebuild | Yes (`drive_flutter`) | Counter/profile toy — **not** the public app |
| `web_demo` | Maintainer, CDP | Yes (`drive_web`) | Mirrors flutter_demo semantics in HTML |
| `drivers` | Maintainer | Yes | Composition over harness + screencast |
| `native_layer_capture_fixture` | CI only | Yes (contract gates) | Android capture fixture — **not** a demo |

### Published package `example/`

| Package | Path | Audience | Compiles | Quality |
| --- | --- | --- | --- | --- |
| `mcp_toolkit` | `example/fibonacci_tool_example.dart` | pub.dev consumer | Yes | **Canonical custom tool** runnable app |
| `mcp_toolkit` | `example/agent_call_entry_starter.dart` | pub.dev consumer | Snippet | Hand-written entry pattern |
| `mcp_toolkit` | `lib/example_fibonacci.dart` | Apps + integration | Yes | Shared `buildCalculateFibonacciTool()` |
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
| Quickstart `main()` bootstrap | Generated / hand-maintained in quickstart | Medium |
| Custom tools inline Dart | Partial duplicate of `mcp_toolkit` example | **Deduped** — link to fibonacci example |
| E2E `make` commands | Should cite `dart run showcase/drivers/…` | Fixed in ADR/tapes |
| Tool list | `docs/reference/tools.mdx` | Generated via `make docs-reference` |

### Skills (`skills/`, synced to plugin)

Sample code is procedural (shell). **Phase 1:** remove `grep WS_URI`; use runner-session. **Phase 3:** link to `examples_map.md`.

### `mcp_server_dart`

No `example/` dir. Integration proof: `test/flutter_cli_example_app_integration_test.dart` + live `flutter_test_app`.

## Proposed convention

1. **`showcase/flutter_test_app`** — only app we show in marketplace hero / agent GIFs (phase 2).
2. **`mcp_toolkit/example/fibonacci_tool_example.dart`** — only narrated custom-tool walkthrough in docs.
3. **`showcase/drivers`** — only narrated code-first E2E in docs (not `make`).
4. **One meaningful pub.dev `example/` per published package** — no trivial stubs.
5. **Phase 3:** `tool/contracts/check_docs_example_snippets.sh` comparing selected `docs/` fences to `example/` files (proposal — not in P1).

## Toolkit parity (`flutter_test_app` vs `main` home)

**Before (main):** `ShowcaseScreen` was route **`/`**. **Now:** product journey on **`/`** + **`/shipments/new`**; **full toolkit lab unchanged** on **`/qa`**; dogfood visual unchanged on **`/visual-reconstruct`** (`DOGFOOD_VISUAL=1`).

### Routes

| Main (`/`) | Current location | Notes |
| --- | --- | --- |
| `ShowcaseScreen` (kitchen-sink) | **`/qa`** | Same widget file; semantics unchanged |
| — | **`/`** | `ShipmentsHomeScreen` (product demo; new semantics) |
| — | **`/shipments/new`** | Form validation / async submit demo |
| `/visual-reconstruct` | **`/visual-reconstruct`** | Unchanged |

### Semantics identifiers (main home → today)

All former home identifiers live on **`/qa`** (`ShowcaseScreen`), except the new product identifiers on **`/`** / **`/shipments/new`**.

| Identifier | Main route | Now |
| --- | --- | --- |
| `app_title_text`, `about_demo_heading` | `/` | `/qa` |
| `capture_section_heading`, `platform_view_demo_panel` | `/` | `/qa` |
| `visual_reconstruct_section_heading`, `visual_reconstruct_open` | `/` | `/qa` |
| `counter_demo_heading`, `counter_demo_icon`, `stateful_counter_increment_button`, `counter_value_display` | `/` | `/qa` |
| `type_section_heading`, `greeting_input_field`, `greeting_echo` | `/` | `/qa` |
| `toggle_section_heading`, `feature_toggle_switch` | `/` | `/qa` |
| `slide_section_heading`, `brightness_slider` | `/` | `/qa` |
| `scroll_section_heading`, `scroll_demo_list` | `/` | `/qa` |
| `iterate_section_heading`, `hot_reload_marker` | `/` | `/qa` |
| `inspect_section_heading`, `emit_log_button`, `trigger_error_button`, `show_test_dialog_button`, `last_log_display` | `/` | `/qa` |
| `live_edit_test_target` | `/` | `/qa` |
| `visual_reconstruct_root`, `visual_reconstruct_marker` | `/visual-reconstruct` | unchanged |
| `shipment_*` (list, form, items) | — | **`/`**, **`/shipments/new`** (additive) |

IntentCall entity semantics (`greeting_form`, `feature_switch`, `counter_demo`) still map to **`/qa`** UI.

### MCP / IntentCall registrations (unchanged set; same `main()`)

| Registration | Delayed? | Location |
| --- | --- | --- |
| `calculate_fibonacci` | initial | `mcp_toolkit/lib/example_fibonacci.dart` (`buildCalculateFibonacciTool()`) |
| `app_state` resource | initial | `main.dart` |
| `get_agent_showcase_state` | initial | `main.dart` |
| `intentcall_bridge_ping`, `set_greeting`, `enable_switch` | initial | `intentcall_showcase_entries.dart` |
| `dogfood_reconstruct_start`, `dogfood_visual_reconstruct_info`, `dogfood_ping` | initial | `agent_dogfood_entries.dart` |
| `get_user_preferences` | **+2s delayed** | `main.dart` |
| WebMCP projection + dogfood adapter | initial | `intentcall_showcase_bootstrap.dart`, `agent_web_mcp_dogfood*.dart` |

### Automation that must reach `/qa`

| Runner | `/qa` navigation |
| --- | --- |
| `packages/harness/tool/exec_sweep.dart` | `navigate` push `/qa` before widget sweeps |
| `tool/evals/run_runtime_enter_text_greeting.sh` | `navigate` push `/qa` before `greeting_input_field` |
| `mcp_server_dart/test/flutter_*_example_app_integration_test.dart` | `navigate` push `/qa` before snapshot/capture |
| `showcase_reactivity_test.dart` | pumps `ShowcaseScreen` directly (no route) |
| `drive_flutter` / `drive_web` | **`showcase/flutter_demo`** (not `flutter_test_app`) — unchanged |

### Sections on `/qa` (parity with main home scroll)

Capture (platform view) · Visual reconstruct link · Tap/counter · Type/greeting · Toggle · Slider · Scroll · Iterate/hot reload · Inspect/logs/dialog.

## Deferred (Anton)

- Delete `flutter_demo` after canonical drives switch target (breaking for minimal harness).
- Move `native_layer_capture_fixture` under `showcase/fixtures/`.
- Merge harness exec tools into a single documented index page with tier tags (tool-count-allow: deferred roadmap item, not a live count).