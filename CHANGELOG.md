# Changelog

<!-- markdownlint-disable MD052 -->
<!-- Keep a Changelog version headings use [3.0.1] brackets; MD052 treats them as reference links. -->

## [Unreleased]

### Added

- Platform-view-aware visual capture: widget-tree `captureHints` detect `AndroidView` / `UiKitView` / `AppKitView` / `HtmlElementView` / `PlatformViewLink` (and weak `Texture` hints).
- macOS showcase `AppKitView` panel (`showcase.platform.stub` native factory) for true-positive integration capture routing tests.
- `ConnectionContext.debugViewDetailsPayload` / `debugViewScreenshotsPayload` test seams for hermetic executor capture-flow tests.
- `get_screenshots` / `capture_ui_snapshot` with `mode: auto` upgrade to `desktop_window` when platform views are detected on a macOS host.
- `flutter_layer` captures attach `warnings` and `captureHints` when platform views are present.
- macOS host `desktop_window` capture for **iOS Simulator** targets (Simulator window + VM PID).
- Swift visual-capture helper `focus` command; `focus_window` MCP tool (`fmt_focus_window`).
- `validate-runtime` skips `flutter_layer` fallback when platform views are detected; executor recovery handles focus+capture retry (`capturePlatformViewsDetected`, `captureFocusAttempted`, `desktopCaptureRetried`).
- Shared [`desktop_capture_recovery`](mcp_server_dart/lib/src/capabilities/visual_capture/desktop_capture_recovery.dart) dedupes host capture retry (no duplicate `focus_window` steps in validate-runtime).

### Added

- `scripts/stop_showcase.sh` and `make showcase-stop` to tear down stray `test_app` / `flutter run` / port `8181` / MCP server processes before showcase or integration runs.
- Showcase logs and PID under `.showcase/`; `run_showcase.sh` stops previous instances on start and on exit.

### Fixed

- `get_view_details` `captureHints` use a full element-tree scan (widget-tree JSON remains depth-capped); showcase `AppKitView` is detected reliably.
- Executor `_hintsFromPayload` trusts app-embedded `captureHints` instead of re-parsing a truncated widget tree.
- Live integration tests decode MCP `CoreError`-only tool failures and assert `auto` → `desktop_window` routing when host capture is unavailable.

### Documentation

- README, debug skill, and CLI runtime-validation skill updated for platform-view capture routing.
- ADR [0006](decisions/0006_platform_view_capture_routing.mdx) (accepted), ADR [0007](decisions/0007_web_headful_tab_capture.mdx) (proposed web headful investigation).

## [3.0.7] - 2026-05-20

### Fixed

- `doctor` now honors global `--vm-service-uri` when subcommand `--target` is omitted (same resolution as `validate-runtime`).
- `vm_not_connected` responses include `stickyEndpoint`, discovery diagnostics, and `suggestedActions` for faster recovery after hot restart.
- Re-attach after a dropped VM session surfaces `meta.recovery` (`reattachedTo`, `previousEndpoint`, `decision`).

### Added

- `semantic_snapshot` returns `interactionSurface` (`flutter_widgets`, `hybrid`, `game_canvas`, `empty`) so agents know when tap-by-ref will not work.
- `evaluate_dart_expression` accepts optional `libraryUri` and returns `details.errorKind` (`compilation`, `library_not_found`, `transport`).
- `wait_for` predicate kind `noError` — waits until the app error monitor is empty.

### Documentation

- `flutter-mcp-toolkit-setup` and `flutter-mcp-toolkit-inspect` skills: doctor triage, `batch` inspect recipe, `flutter_layer` screenshots, `interactionSurface` guidance (regenerated `skill_assets.g.dart`).

## [3.0.6] - 2026-05-20

### Fixed

- Root `install.sh` supports `curl ... | bash` and installs outside a git clone: safe `BASH_SOURCE` under `set -u`, optional default version from repo `VERSION` / `runtime_version.dart`, GitHub `releases/latest` fallback, and clear usage when version cannot be resolved.

### Changed

- Release binaries: drop `darwin-x64` (Intel Mac). macOS releases are Apple Silicon (`darwin-arm64`) only; `linux-x64` unchanged.

## [3.0.5](https://github.com/Arenukvern/mcp_flutter/compare/v3.0.4...v3.0.5) (2026-05-19)

### Bug Fixes

- readme ([b95e8b3](https://github.com/Arenukvern/mcp_flutter/commit/b95e8b3d25c5529e21c79a3b06ebd97524573671))

## [3.0.4] - 2026-05-19

### Fixed

- docs.page site configuration: logo, favicon, social preview image, Flutter brand theme (`#02569B`), header and anchor links, SEO defaults, and content settings in `docs.json` with assets under `docs/assets/`.

## [3.0.3] - 2026-05-19

### Fixed

- `flutter-mcp-toolkit init` skill writers failed when bundled skill `flutter-mcp-toolkit-repo-maintainer` lacked the required `<!-- @FMT_MODE_PRELUDE -->` marker; marker restored and `skill_assets.g.dart` regenerated.
- CLI daemon integration test forces `get_vm` to fail via an explicit invalid VM target so structured-error assertions stay deterministic when a local Flutter debug app is auto-discovered.

## [3.0.2] - 2026-05-19

### Added

- Marketplace distribution docs: [marketplace_copy.yaml](docs/ai_agents/marketplace_copy.yaml) (listing SSOT), [marketplace_distribution.mdx](docs/ai_agents/marketplace_distribution.mdx), and [marketplace_submission_runbook.mdx](docs/contributing/marketplace_submission_runbook.mdx) (Claude, Cursor, Codex, skills.sh, Smithery, MseeP).
- Plugin store assets under [plugin/assets/](plugin/assets/): `original_logo.png`, `icon.png` (256), `logo.png` (512), `screenshot-1.png`, `screenshot-2.png`, plus capture/regeneration notes in [plugin/assets/README.md](plugin/assets/README.md).
- Codex `interface` metadata in [plugin/.codex-plugin/plugin.json](plugin/.codex-plugin/plugin.json) (display copy, legal URLs, asset paths).
- CI: `check_changelog_markdown.sh` wired into `make check-contracts` (Keep a Changelog / MD052).

### Changed

- Plugin and marketplace descriptions now emphasize the **dynamic registry** (custom MCP tools/resources at runtime via `mcp_toolkit`), not only static inspect/control MCP tools.
- Claude plugin and marketplace versions included in release-please and `check_version_sync.sh` (with Cursor/Codex).
- Codex plugin `homepage` / `repository` point at `Arenukvern/mcp_flutter` (was separate `flutter-mcp-toolkit` repo URL).
- README: **Install from marketplaces** section; [plugin/README.md](plugin/README.md) documents static + dynamic architecture and all eight bundled skills.
- `check_plugin_surfaces.sh` fails if marketplace/plugin descriptions omit dynamic/custom positioning.
- MCP server instructions reference skill `flutter-mcp-toolkit-custom-tools` for dynamic tool flows.
- Maintainer skill `flutter-mcp-toolkit-repo-maintainer` documents marketplace copy, distribution, and submission runbook.

### Documentation

- [docs/ai_agents/overview.mdx](docs/ai_agents/overview.mdx): three-layer model (host MCP, in-app toolkit, dynamic registry); Cursor/Codex git marketplace install.
- [docs/start_here/docs_map.mdx](docs/start_here/docs_map.mdx) and [contribution_guide.mdx](docs/contributing/contribution_guide.mdx) link marketplace docs.

## [3.0.1] - 2026-05-19

### Added

- Open Agent Skills ecosystem: repo-root [`skills/`](skills/) symlink to [`plugin/skills/`](plugin/skills/), [`.skills.json.example`](.skills.json.example), and install docs in [docs/ai_agents/overview.mdx](docs/ai_agents/overview.mdx) (`npx skills add Arenukvern/mcp_flutter`, [skills.sh](https://skills.sh), team lockfile / CI restore).
- Claude marketplace plugin discovery: `skills` entry in [.claude-plugin/marketplace.json](.claude-plugin/marketplace.json).
- Maintainer skill `flutter-mcp-toolkit-repo-maintainer` for releases, CHANGELOG, and docs (bundled + `.cursor/skills/`).

### Documentation

- Install method matrix and per-agent paths in overview; pointers in README, QUICK_START, llm_install, plugin README, mcp_server_dart README, docs_map, cli_vs_mcp, cli_quick_recipes, contribution_guide, execution_playbook, and `flutter-mcp-toolkit-setup` skill (regenerated via `make sync-skills`).

### Changed

- Release automation: [release-please](https://github.com/googleapis/release-please) on `main` (Release PR → tag → changelog GitHub release); [`.github/workflows/release.yml`](.github/workflows/release.yml) attaches binaries only. Version sync gate: `tool/contracts/check_version_sync.sh`.

## [3.0.0]

Major release. Three pillars:

1. **Capability kernel** — the server's tool surface is now composed from
   `Capability` instances registered into an `McpHost`. The kernel applies
   the capability prefix and bridges into `dart_mcp`'s `ToolsSupport`.
2. **Playwright-style interaction layer** — 27 prefixed tools that let an
   AI agent drive a running Flutter app the way a user does, with semantic
   refs and a snapshot/staleness contract.
3. **Plugin-first install** — a Claude Code marketplace plugin bundles
   skills, agent, and MCP server into one `install.sh` step; CLI gains
   `init <agent>` for Cursor / Codex / etc.

The locked v3.0.0 surface is checked in at
[`tool/contracts/expected_tool_surface.txt`](tool/contracts/expected_tool_surface.txt)
and pinned by
[`mcp_server_dart/test/tool_surface_snapshot_test.dart`](mcp_server_dart/test/tool_surface_snapshot_test.dart).

### Plugin layout

- Renamed bundled Cursor/Codex skill **`custom-toolkit-tools`** → **`flutter-mcp-toolkit-custom-tools`** (directory `plugin/skills/…`, frontmatter `name`, and `SkillAssets` id). Update any prompts or automation that referenced the old skill id; run `make sync-skills` after pulling.
- Renamed Claude subagent file `plugin/agents/flutter-inspector.md` → `plugin/agents/flutter-mcp-toolkit-runtime.md` with `name: flutter-mcp-toolkit-runtime` so the agent aligns with `flutter-mcp-toolkit-*` surfaces and no longer shares a slug with the legacy MCP `mcpServers` key **`flutter-inspector`**.
- **Consolidated:** Claude Code marketplace, Cursor/Codex manifests, MCP config, installer, version pin, `flutter-mcp` + `flutter-mcp-cli-runtime-validation` skills, and the `flutter-mcp-toolkit-runtime` agent now live under **`plugin/`** only. [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) `source` is **`./plugin`**. Removed the duplicate **`flutter_mcp_plugin/`** tree.
- `plugin/` (Claude / Cursor / Codex marketplace): canonical **`plugin/mcp.json`** uses MCP key **`flutter-mcp-toolkit`**; `tool/contracts/check_plugin_surfaces.sh` accepts **`flutter-mcp-toolkit`** or legacy **`flutter-inspector`** and requires **`flutter-mcp-toolkit-server`** in `command`.

### Docs

- Install/migration docs (`llm_install.md`, `mcp_server_dart/README.md`, `docs/start_here/migration_v2_to_v3.mdx`), plugin spec §5–§6.1, and `plugin/skills/flutter-mcp/SKILL.md`: clarify **`flutter-inspector`** as legacy **`mcpServers`** id vs Claude subagent **`flutter-mcp-toolkit-runtime`**; regenerated `skill_assets.g.dart`.
- Plugin skills (`plugin/skills/…`): `validate-runtime` now documents `--vm-service-uri`, automatic `flutter_layer` retry after failed `desktop_window` capture, and `captureFallbackUsed`; port-conflict example uses current `flutter run` flags; covers binaries, `mcpServers` keys, `validate-runtime`, and links to canonical configs.
- [mcp_server_dart/README.md](mcp_server_dart/README.md): Cline / Cursor / Claude examples use **`flutter-mcp-toolkit`** + updated Cursor deeplink; removed stale `--no-resources` / `flutter_inspector_mcp` guidance.
- `mcp_toolkit` package README: golden-path note for `validate-runtime` targeting / fallback.

### BREAKING

#### MCP tool names are now prefixed by capability id

All MCP tools surface under the `fmt_` capability prefix (Flutter MCP
Toolkit). Calls to legacy unprefixed names return `tool_not_found`. The
CLI catalog vocabulary stays bare for intrinsic tools — `flutter-mcp-toolkit exec --name tap_widget`
still works; MCP publishes `fmt_tap_widget`. Dynamic-registry commands use
their full `fmt_*` spelling in both CLI and MCP. See
[docs/start_here/migration_v2_to_v3.mdx](docs/start_here/migration_v2_to_v3.mdx)
for the smallest-possible-diff guide.

| v2 (legacy)                             | v3 (MCP `tools/call` name)            |
| --------------------------------------- | ------------------------------------- |
| `tap_widget`                            | `fmt_tap_widget`                      |
| `enter_text`                            | `fmt_enter_text`                      |
| `scroll`                                | `fmt_scroll`                          |
| `long_press`                            | `fmt_long_press`                      |
| `swipe`                                 | `fmt_swipe`                           |
| `drag`                                  | `fmt_drag`                            |
| `hover`                                 | `fmt_hover`                           |
| `press_key`                             | `fmt_press_key`                       |
| `semantic_snapshot`                     | `fmt_semantic_snapshot`               |
| `wait_for`                              | `fmt_wait_for`                        |
| `fill_form`                             | `fmt_fill_form`                       |
| `navigate`                              | `fmt_navigate`                        |
| `handle_dialog`                         | `fmt_handle_dialog`                   |
| `connect_debug_app`                     | `fmt_connect_debug_app`               |
| `discover_debug_apps`                   | `fmt_discover_debug_apps`             |
| `get_vm`                                | `fmt_get_vm`                          |
| `get_extension_rpcs`                    | `fmt_get_extension_rpcs`              |
| `hot_reload_flutter`                    | `fmt_hot_reload_flutter`              |
| `hot_restart_flutter`                   | `fmt_hot_restart_flutter`             |
| `hot_reload_and_capture`                | `fmt_hot_reload_and_capture`          |
| `evaluate_dart_expression`              | `fmt_evaluate_dart_expression`        |
| `get_recent_logs`                       | `fmt_get_recent_logs`                 |
| `get_view_details`                      | `fmt_get_view_details`                |
| `get_app_errors`                        | `fmt_get_app_errors`                  |
| `get_screenshots`                       | `fmt_get_screenshots`                 |
| `capture_ui_snapshot`                   | `fmt_capture_ui_snapshot`             |
| `inspect_widget_at_point`               | `fmt_inspect_widget_at_point`         |
| `debug_dump_layer_tree` (`--dumps`)     | `fmt_debug_dump_layer_tree`           |
| `debug_dump_semantics_tree` (`--dumps`) | `fmt_debug_dump_semantics_tree`       |
| `debug_dump_render_tree` (`--dumps`)    | `fmt_debug_dump_render_tree`          |
| `debug_dump_focus_tree` (`--dumps`)     | `fmt_debug_dump_focus_tree`           |
| `listClientToolsAndResources`           | `fmt_list_client_tools_and_resources` |
| `runClientTool`                         | `fmt_client_tool`                     |
| `runClientResource`                     | `fmt_client_resource`                 |

The dynamic-registry host trio
(`fmt_list_client_tools_and_resources`, `fmt_client_tool`, `fmt_client_resource`)
uses the same `fmt_*` names on MCP and in `exec --name`. Resource URIs
(`visual://localhost/...`) are unchanged.

#### Server and CLI binaries renamed

- `flutter_inspector_mcp` → **`flutter-mcp-toolkit-server`** (the MCP server).
- `flutter_mcp_cli` → **`flutter-mcp-toolkit`** (the CLI).
- The MCP `serverInfo.name` advertised on initialize is now
  `flutter-mcp-toolkit-server`.

Update any `mcpServers` config entry, shell alias, Docker invocation, or
CI script that referenced the old names. The new root `install.sh`
updates `PATH` for you on first run.

#### Strict wire surface

- All MCP tool/resource errors emit a single envelope:
  `code`, `message`, `details`, `descriptor`, `recovery`. Code paths that
  parsed top-level `category` / `retryable` / `exitCode` must read
  `error.descriptor` instead.
- Typed parsing hard cut: no string-encoded object/list/bool coercions.
- Tool argument schemas default to `additionalProperties: false` unless
  explicitly opened.
- `connection.targetId` now requires full VM websocket URIs
  (`ws://.../ws`). Legacy `host:port` ids are rejected with migration
  guidance to URI ids or `connection.uri`.
- Top-level `host` / `port` / `uri` aliases on tool arguments are
  rejected; pass them inside the nested `connection` object.

### Added

#### Capability kernel

- `packages/server_capability_kernel/` — pure-Dart contracts: `Capability`,
  `CapabilityContext`, `HostService`, `CommandRunner`, prefix validators,
  and a testing library shipping `FakeCommandRunner` /
  `FakeCapabilityContext`.
- `packages/server_capability_core/` — the bundled `fmt` capability. Registers all 27
  Playwright-style tools plus 4 `--dumps` tools when
  `dumps_supported=true`. No Flutter dependency on the server side.
- `packages/core/` — pure-Dart command hierarchy
  (`CoreCommand`, `CoreResult.toErrorEnvelopeJson`) and value types
  shared between server, CLI, and capability core.
- `McpHost` registry on the server applies the `<capabilityId>_` prefix
  with collision enforcement. `DartMcpDispatchBridge` publishes prefixed
  tools into `dart_mcp`'s `ToolsSupport`.

#### Playwright-style interaction layer

- New interaction tools that let an AI agent drive a running Flutter app
  the way a user does:
  - `semantic_snapshot` returns a compact JSON accessibility tree of
    interactive widgets with stable `ref` strings (`s_0`, `s_1`, ...) and
    a monotonically incrementing `snapshot_id`.
  - `tap_widget`, `long_press`, `enter_text`, `scroll`, `swipe`, and
    `drag` target widgets by `ref`. Each tool uses a two-tier dispatch:
    semantic actions first (`SemanticsOwner.performAction`), then
    synthetic pointer events via
    `GestureBinding.instance.handlePointerEvent` when no semantic action
    is available. Responses include a `via` field
    (`semantic_action` | `pointer_events` | `editable_state` |
    `pointer_scroll_event`).
  - All interaction tools accept an optional `snapshotId`; if it doesn't
    match the current snapshot the call returns a `stale_snapshot`
    envelope with `providedSnapshotId` and `currentSnapshotId`.
  - `scroll` direction follows the Playwright convention
    (direction = which content to reveal).
  - `enter_text` falls back to
    `EditableTextState.userUpdateTextEditingValue` so
    `TextInputFormatter`s and `onChanged` fire correctly.
- `hot_reload_and_capture` fuses hot reload, screenshot, semantic
  snapshot, and app errors into a single response for the agent
  edit/preview loop.
- `evaluate_dart_expression` runs a Dart expression against the root
  library in the running isolate (e.g. `AgentState.instance.counter`)
  and returns `{result, kind, classRef}`.
- `get_recent_logs` exposes a 200-entry ring buffer of recent
  `print` / `debugPrint` output captured from the running app.

#### `flutter-mcp-toolkit init <agent>`

- New `init` subcommand auto-detects mode and writes per-target skills,
  agent files, and manifests for Claude Code, Cursor, Codex, and other
  supported agents in one call.
- `codegen-init` emits the Flutter `main.dart` snippet that bootstraps
  the toolkit on the app side (`MCPToolkitBinding.initialize() / initializeFlutterToolkit()`).
- Replaces the per-agent manual setup docs that shipped in v2.

#### Claude Code marketplace plugin (`plugin/`)

- Plugin manifests (`.claude-plugin/`, `.cursor-plugin/`, `.codex-plugin/`), `mcp.json`, `install.sh`, `EXPECTED_SERVER_VERSION`,
  and a marketplace entry under `.claude-plugin/marketplace.json`.
- Skills shipped include `flutter-mcp-toolkit-{guide,setup,inspect,control,debug}`, `flutter-mcp-toolkit-custom-tools`, `flutter-mcp`, and `flutter-mcp-cli-runtime-validation`.
- `flutter-mcp-toolkit-runtime` agent.
- Skill bodies are bundled into the server (`skill_assets.g.dart`) so
  the CLI can ship them as part of `init`. `make sync-skills`
  regenerates; CI fails PRs that don't.

#### Showcase redesign

- `flutter_test_app` rebuilt as a single-page showcase (`ShowcaseScreen`)
  where every interaction tool has a named target with a `Semantics`
  identifier (`greeting_input_field`, `feature_toggle_switch`,
  `brightness_slider`, `scroll_demo_list`, `hot_reload_marker`,
  `emit_log_button`, `trigger_error_button`, `last_log_display`, ...).
- Integration-test identifiers
  (`about_demo_heading`, `counter_demo_heading`, `counter_demo_icon`,
  `stateful_counter_increment_button`) are preserved.
- `AgentState` singleton lets agents read and mutate showcase state
  through `evaluate_dart_expression`.
- Section heading semantics are isolated for cleaner snapshots.

#### Install and release

- Root `install.sh` for one-command install/upgrade on `darwin-arm64`,
  `darwin-x64`, `linux-x64`. Updates `PATH`.
- Release artifact builder with tarball + checksum generation:
  `tool/release/build_release_artifacts.sh`.
- Tagged release workflow:
  `.github/workflows/release.yml`.

#### Contract quality gates (`make check-contracts`)

- `tool/contracts/check_sdk_parity.sh` — Docker base image vs `pubspec`.
- `tool/contracts/check_error_code_playbook.sh` — error-code surface
  coverage.
- `tool/contracts/check_docs_drift.sh` — CLI help vs docs.
- `tool/contracts/check_plugin_surfaces.sh` — plugin manifest shape.
- `tool/contracts/check_tool_prefix.sh` — single canonical prefix across
  every shipped doc; CHANGELOG migration table covers all 27 tools.
- CI: `.github/workflows/contract_gates.yml`.
- macOS integration smoke runner:
  `tool/integration/classify_macos_integration_run.sh`.

#### CLI safety + observability

- `flutter-mcp-toolkit doctor [--json] [--target <path>] [--timeout-ms <n>]`
  for CI preflight before VM-dependent operations.
- Safe-write flags for `snapshot create` and `bundle create`:
  `--check`, `--diff`, `--backup`, `--no-overwrite`. Bundle publishing
  is now staged and atomic; the destructive pre-delete is gone.
- Connection UX:
  - Startup stays non-blocking when multiple targets are present.
  - First VM-dependent call auto-attaches when target resolution is
    unambiguous; ambiguity surfaces as `connection_selection_required`
    with `availableTargets` and retry guidance.
  - Optional strict nested `connection` object across every
    VM-dependent MCP tool and dynamic-registry tool.
  - Resource URI query-based connection targeting (`targetId`, `mode`,
    `host`, `port`, `uri`, `forceReconnect`).
- Flutter web auto-discovery:
  - Machine discovery via `flutter attach --machine` with optional
    project / device context.
  - Merged machine + port-scan discovery using URI-id selection
    payloads.
- Runtime discovery flags for the CLI and MCP server:
  - `--flutter-project-dir`
  - `--flutter-device`
  - `--flutter-discovery-timeout-ms`
- CLI / daemon alignment:
  - `exec --args` and daemon `command/execute` / `watch/start` accept
    the same optional `params.args.connection`.
  - `snapshot create` supports per-step
    `args.commands[i].args.connection`.
  - Preconnect no longer returns synthetic `vm_not_connected` for
    ambiguous multi-target paths; ambiguity surfaces as
    `connection_selection_required`.
  - Explicit requested-session attach stays strict; implicit stale
    active-session attach falls back to auto target resolution.
  - `connect` and `session_start` reject mixed native selector args
    with nested `connection`.

### Changed

- The `--use-capability-kernel` flag is gone; the kernel is the only
  registration path. The legacy unprefixed registration mixin was
  deleted in T9.
- README rewritten around the four-step install
  (`install.sh` → `init <agent>` → run app → call tools).
- ARCHITECTURE.md rewritten around the capability kernel and the
  shared-core packages. New ADRs in `docs/decisions/`:
  - `0001_capability_kernel_and_tool_prefix.mdx`
  - `0002_v3_scope_and_consolidation_deferrals.mdx`
- Docs reorganized under `docs/start_here/`, `docs/decisions/`,
  `docs/ai_agents/`, `docs/superpowers/`, `docs/guides/`.
- Dockerfile pinned to `dart:3.11.0-sdk`.

### Fixed

- `resolveCenter` / `resolveBounds` return logical (not physical)
  coordinates — DPR fix that unblocked tap / long-press on high-DPI
  screens.
- `fill_form` actually stops on first toolkit-side failure.
- `wait_for` timeout payload shape pinned by tests; malformed payloads
  route correctly.
- `popUntil` guard and bad-route logging in the toolkit.
- `semantic_snapshot` surfaces scrollable nodes (widgets that advertise
  `scrollUp/Down/Left/Right`) so agents can pass an explicit `ref` to
  `scroll` for the deterministic semantic-action path.
- `scroll` direction-to-`SemanticsAction` mapping realigned with the
  Playwright "direction = reveal" convention:
  `direction: "down"` now maps to `SemanticsAction.scrollUp` (finger up,
  reveals content below), so the Tier 1 path succeeds on real Flutter
  scrollables at the top of their range.

### Flutter Web interaction support

Interaction tools are Tier 1 first on web and degrade predictably when
Tier 1 isn't available:

- `semantic_snapshot`, `evaluate_dart_expression`, `get_recent_logs`,
  `hot_reload_flutter`, and `hot_reload_and_capture` work unchanged on
  web.
- `tap_widget`, `long_press`, and `scroll` (with ref) work when the
  target node exposes the matching `SemanticsAction`. The action shows
  up in the node's `actions` array in `semantic_snapshot`.
- `enter_text` works via `SemanticsAction.setText` or the
  `EditableTextState.userUpdateTextEditingValue` fallback (both work on
  web).
- `swipe(ref, direction)` on web redirects to the matching scroll
  semantic action when `ref` is a scrollable that exposes it; success
  responses return `via: "semantic_action_fallback"` with a `note`
  field explaining the redirect.
- `scroll` without a ref walks the semantics tree for a matching
  scrollable and uses Tier 1.
- When no Tier 1 path exists (tap / long-press on nodes without the
  matching action, swipe on a non-scrollable or no-ref target, drag,
  scroll without any scrollable in tree), web returns a structured
  `web_gesture_not_supported` envelope with a `hint` pointing the agent
  at the right workaround (snapshot for a different ref, add a
  `Semantics` wrapper, or use `evaluate_dart_expression`).

### Removed

- Per-agent manual setup docs — superseded by
  `flutter-mcp-toolkit init <agent>`.
- Manual install / client-setup docs — superseded by `install.sh` +
  `init`.
- `docs/core/built_in_tools` and `docs/core/error_code_playbook` —
  migrated into the plugin's `debug` and `guide` skills.
- `docs/getting_started/` and `docs/troubleshooting/` — content moved
  under `docs/start_here/`.
- `memory-bank/` legacy AI memory directory.
- `mcp_toolkit/devtools_mcp_extension/`.

### Deferred (post-3.0.0)

- Network introspection — see
  [todo/p3_network_introspection.md](todo/p3_network_introspection.md).
- `select_option` form action.
- P4 consolidation set A / C from the audit.

### Version alignment

- `mcp_server_dart`: `3.0.0`
- `mcp_toolkit`: `3.0.0`

### Migration: v2.x → v3.0.0

- Add `fmt_` to every MCP `tools/call` name. See
  [docs/start_here/migration_v2_to_v3.mdx](docs/start_here/migration_v2_to_v3.mdx).
- Update binary names in your `mcpServers` config and any wrapper
  scripts: `flutter_inspector_mcp` → `flutter-mcp-toolkit-server`,
  `flutter_mcp_cli` → `flutter-mcp-toolkit`.
- Replace error parsing that expected top-level `category` /
  `retryable` / `exitCode` with reads against `error.descriptor`.
- Stop sending string-encoded typed values; pass real JSON types only.
- Switch any `targetId` of the form `host:port` to the full
  `ws://.../ws` URI, or pass `connection.uri`.
- Move top-level `host` / `port` / `uri` arguments into the nested
  `connection` object.
- For write-producing commands, prefer `--check --diff` first in
  automation. If overwrite must be blocked, set `--no-overwrite` and
  handle `write_blocked`.
- Use `flutter-mcp-toolkit doctor --json` in CI preflight before
  VM-dependent operations.

## 2.6.1

- old devtools extension removed

## 2.6.0

BREAKING CHANGES:

- Dart SDK updated to 3.10.0 with all dependencies updated to the latest versions

- now VM service auto-reconnect when Flutter app restarts. Huge thank you to [@jkitching](https://github.com/jkitching) for PR! https://github.com/Arenukvern/mcp_flutter/pull/73
- dockerfile for MCP Server - not tested.
  Huge thank you to [@arslanmit](https://github.com/arslanmit) for PR with Dockerfile! https://github.com/Arenukvern/mcp_flutter/pull/64

## 2.5.0

- new tool: `hot_restart_flutter` to perform VM Service Hot Restart from MCP.
- VM service integration method `hotRestart()` with namespaced service discovery fallback.

  Huge thank you to [CommentakMedia](https://github.com/CommentakMedia) for PR with Hot Restart tool and docs! https://github.com/Arenukvern/mcp_flutter/pull/67

## 2.4.0

- mcp_toolkit: ^0.3.0 with breaking changes, see [mcp_toolkit/CHANGELOG.md](https://github.com/Arenukvern/mcp_flutter/blob/main/mcp_toolkit/CHANGELOG.md)

## 2.3.1

- added new examples for MCPToolkit package dynamic tools usage see [flutter_test_app/lib/main.dart](https://github.com/Arenukvern/mcp_flutter/tree/main/flutter_test_app/lib)
- thanks for [@marwenbk](https://github.com/marwenbk) for asking [issue](https://github.com/Arenukvern/mcp_flutter/issues/56).

## 2.3.0

- perf: added more checks for `MCPCallEntry.resourceUri` for MCPToolkit package (MCPToolkit updated to v0.2.3)

## mcp_server_dart

- feat: Added support for saving captured screenshots as files instead of returning them as base64 data, with automatic cleanup of old screenshots. Use (`--save-images`) flag to enable it.

- fix: Fixed various issues with dynamic registry, made logs level error by default.

- added section for RooCode in QUICK_START.md
- disabled resources support by default for RooCode and Cline setups (for unknown reason it doesn't work)

- Huge thank you to [cosystudio](https://github.com/cosystudio) for raising, researching and [describing issues](https://github.com/Arenukvern/mcp_flutter/issues/53) with RooCode MCP server.

## 2.2.2

- Added `--await-dnd` flag to wait until DND connection is established. By default `--no-await-dnd` will be applied.
  There will be 5 seconds timeout for DND connection and then server will start without DND connection.

  This is workaround for MCP Clients which don't support tools updates.
  Important: some clients doesn't support it. Use with caution. (disable for Windsurf, works with Cursor)

Thank you [@rednikisfun](https://github.com/rednikisfun) for [raising issue for Windsurf](https://github.com/Arenukvern/mcp_flutter/issues/51).

## 2.2.1

- Added badge to install Flutter Inspector to Cursor in README.md
- Restored License file

## 2.2.0

### 🎉 Dart Server + Dynamic Tools Registration

### 🔄 BREAKING CHANGES.

- **Server Migration**: The main server is now **`mcp_server_dart`** (Dart-based), replacing the previous TypeScript server (`mcp_server`)
- **Configuration Changes**: Updated command-line arguments and removed environment variables
- **Package Version**: Updated `mcp_toolkit` to `^0.2.0`

### ✨ New Features

1. 🆕 Dynamic Tools Registration
   Flutter apps can now register custom tools at runtime.
   See [video](https://www.youtube.com/watch?v=Qog3x2VcO98) of how it works and how to use it.

2. MCP Tools for Dynamic Registry (part of Dynamic Tools Registration)

- `fmt_list_client_tools_and_resources` - Discover all dynamically registered tools and resources if they are not listed in the AI Assistant (Cursor, Cline, Copilot, Roo Code etc..)
- `fmt_client_tool` - Execute custom tools registered by Flutter applications
- `fmt_client_resource` - Read custom resources registered by Flutter applications
- `getRegistryStats` - Get statistics about the dynamic registry (debug mode only)

### 📦 Migration Guide

1. **Update AI Assistant Configuration**:

   ```json
   {
     "mcpServers": {
       "flutter-mcp-toolkit": {
         "command": "/path/to/mcp_flutter/mcp_server_dart/build/flutter-mcp-toolkit-server",
         "args": [
           "--dart-vm-host=localhost",
           "--dart-vm-port=8181",
           "--resources",
           "--images",
           "--dynamics"
         ],
         "env": {}
       }
     }
   }
   ```

2. **Update Flutter App Dependencies**:
   ```yaml
   dependencies:
     mcp_toolkit: ^0.2.0
   ```

#### For New Users

Follow the updated [Quick Start Guide](QUICK_START.md) for complete setup instructions.

### 🔧 Technical Changes

1. Command Line Interface

- Instead of environment variables, now you can use command-line flags: `--resources`, `--no-resources`, `--images`, `--dumps`, `--dynamics`
- Improved logging with `--log-level` option

2. MCPToolkit API Updates

- New `addEntries()` method to register tools and resources from Flutter app.
- New `MCPCallEntry.tool()` and `MCPCallEntry.resource()` constructors
- Improved error handling with `MCPCallResult`

### 🐛 Bug Fixes

- Fixed connection stability issues
- Improved error handling for VM service disconnections
- Enhanced port scanning reliability
- Better resource cleanup on app restart

### 🙏 Acknowledgments

Special thanks to the community for feedback and testing, and to the Flutter team for the new Dart MCP Server which made Dart MCP Server possible.

---

## Code Rabbit Poem :)

> In the warren of code, new features appear,
> Dynamic tools hop in—now discovery is clear!
> Registries and managers with event-driven flair,
> Flutter and MCP, a seamless new pair.
> With docs and examples, the future looks bright—
> This bunny approves: the registry's just right!
> 🐇✨

## 2.1.0

This release adds experimental Dart MCP Server.
In future I want to replace Typescript server with Dart one.

The reason is simple: Dart has more tooling for Flutter, and it's easier to develop with it.

The reason why I didn't do it earlier - because I started earlier and at the start there was no Dart MCP Server at all, so only when I already developed first version (with autogenerated tools based on Dart VM methods), I asked question on Flutter Discord server and got reply that there is [MCP server fo Dart tooling in development](https://discord.com/channels/608014603317936148/1159561514072690739/1362482189131841718) which sounds so amazing, so at the moment I thought that I don't need to do it myself and stop the project completely.

Then I figured out, that's it was fun time to develop it, and I would happy to try to complete at least one version.

At the same time I've tried Dart MCP Server and it was not working with Cline at all, so I decided to keep the project alive and try to fine tune it instead, while Dart MCP Server was in development.

Now Dart MCP Server mostly works, and I'm happy to migrate to it. However, in the same time, I found new idea of how MCP Server can be used - and it's not only using Dart VM methods, but just other way of thinking of MCP servers.

The current way to write MCP server tools and resources is to have to write server and all the code is on the server side.

However, I found, that it's not ideal, because if you need to secure what information is sent to the server, or just add new tools / resources for specific project it is not great way to do it.

So after experimenting with some ideas (the most of work is on branch feat/mcp-registry-try3), first:

1. Removed extension and moved all logic for tools and resources to the client. (it's released already as Dart MCPToolkit package)
2. Added ability to register new tools and resources on server from client side. (WIP).

Hopefully, the idea will work and will be useful (but maybe not:))

If you want to try dart server - please check [README](mcp_server_dart/README.md) for more details.

For dynamic registry of client tools and resources, please check [issue](https://github.com/Arenukvern/mcp_flutter/issues/32) - will update it during the work.

Have a nice day!

## 2.0.0

This release removes the forwarding server path and refactors all communication to use Dart VM.

Note that setup is changed - see new [Quick Start](QUICK_START.md) and [Configuration](CONFIGURATION.md) docs.

The major change, is that now you can control what MCP Server will receive from your Flutter app.

This is made, by introducing new package - [mcp_toolkit](https://github.com/Arenukvern/mcp_flutter/tree/main/mcp_toolkit).

This package working on the same principle as WidgetBinding - it collects information from your Flutter app and sends it to Dart VM when MCP Server requests it.

You can override or add only tools you need.

For example, if you want to add Flutter tools, you can use `initializeFlutterToolkit()` method like one below.

```dart
MCPToolkitBinding.instance
  ..initialize()
  ..initializeFlutterToolkit();
```

## Poem

Thanks Code Rabbit for poem:

> A hop, a leap, the server's gone,  
> Now all through Dart VM, requests are drawn.  
> No more forwarding, no more relay,  
> Errors and screenshots come straight our way!  
> Toolkit in the app, so neat and spry,  
> Flutter views and details—oh my!  
> 🐇✨

## 1.0.0

Stable release with forwarding server implementation.
