# flutter-mcp-toolkit Plugin & Skill Bundle — Design

- **Status:** Draft (runtime-validation §3.6 + MCP key policy updated 2026-05-05)
- **Date:** 2026-04-29
- **Owner:** @arenukvern
- **Targets release:** v3.0.0
- **Related:** [ADR 0001 (capability kernel)](../../decisions/), [ADR 0002 (Playwright parity)](../../decisions/)

## 1. Problem

`mcp_flutter` v3.0.0 has the technical surface ready (27 MCP tools, capability kernel, Playwright parity P0-P2) but onboarding is the release blocker:

- **7 manual steps** from `git clone` to first AI tool call.
- **4 separate doc paths** for Cursor / Codex / Claude / Cline, each maintained independently.
- **Branding drift**: `mcp_flutter`, `mcp_toolkit`, `flutter_inspector_mcp`, `flutter_mcp_cli` (legacy CLI name, now `flutter-mcp-toolkit`) appear interchangeably.
- **No source-of-truth for AI-agent guidance** — `docs/ai_agents/` is markdown that agents only read if a human points them at it.
- **CLI vs MCP** is a forked path the user must understand and configure manually.

This design proposes the AI-agent entry point and distribution mechanism that closes those gaps for v3.0.0.

## 2. Goals & Non-Goals

### Goals

1. One canonical AI-agent surface (`flutter-mcp-toolkit` plugin) that ships skills for all four supported agents (Claude Code, Cursor, Codex, Cline).
2. ≤ 4 manual steps from a fresh Flutter project to a working AI loop.
3. Single source of truth for skill bodies — no per-platform skill duplication.
4. CLI vs MCP transparent to the agent: skill body is mode-agnostic; mode is a 5-line prelude generated at install.
5. v3.0.0 releases with the rebranded surface (`flutter-mcp-toolkit-*` everywhere; MCP tool prefix `fmt_`).

### Non-Goals

- Per-tool name normalization (verb-tense consistency). Separate spec.
- Live-edit reintegration; P3 network introspection. Already deferred.
- Public marketplace listings (Cursor / Codex directories). Post-3.0.0.
- Windows `install.sh`. macOS + Linux only.
- Telemetry, auto-update, multi-app session management.
- Pub-distributed skills package. Skills ship in the CLI binary.

## 3. Architecture

### 3.1 Skill Bundle (5 skills)

| Skill ID | Purpose | Loaded by |
|---|---|---|
| `flutter-mcp-toolkit-guide` | Entry / router. Tool taxonomy, when-to-use map, links to other skills. | Default — every session. |
| `flutter-mcp-toolkit-setup` | Install verification, `doctor` preflight, troubleshooting. Includes CLI surface beyond `exec`. | First-time use OR when guide detects a setup issue. |
| `flutter-mcp-toolkit-inspect` | Read-only state: `semantic_snapshot`, `get_view_details`, `get_app_errors`, `get_screenshots`, `get_vm`, `get_extension_rpcs`, `discover_debug_apps`, `inspect_widget_at_point`, `capture_ui_snapshot`. | When the agent's intent is to read state. |
| `flutter-mcp-toolkit-control` | Interaction: `tap_widget`, `long_press`, `enter_text`, `fill_form`, `scroll`, `swipe`, `drag`, `hover`, `press_key`, `wait_for`, `navigate`, `handle_dialog`, `hot_reload_*`, `hot_restart_flutter`, `hot_reload_and_capture`. | When the agent's intent is to drive the app. |
| `flutter-mcp-toolkit-debug` | `get_recent_logs`, `evaluate_dart_expression`, error-envelope playbook (every error code → recovery), `connect_debug_app`. | When something is broken. |

Target sizes: guide ~80 lines, others 150-250 lines. Typical session loads `guide + 1 task skill` ≈ 350 lines of context.

### 3.2 Multi-Target Distribution

All four supported agents read **`SKILL.md` with `name`/`description` YAML frontmatter** — verified against [Cursor docs](https://cursor.com/docs/skills) and [Codex docs](https://developers.openai.com/codex/skills). One canonical body file works across all targets; only plugin manifests differ.

Canonical layout (in this repo). The user-facing plugin name is `flutter-mcp-toolkit`; the in-repo source dir is `plugin/` to avoid a redundant suffix in the monorepo:

```
plugin/                          # source of truth for the flutter-mcp-toolkit plugin
  .cursor-plugin/plugin.json     # Cursor manifest — name, version, description, points at ./skills
  .codex-plugin/plugin.json      # Codex manifest — kebab-case name, version, description, "skills": "./skills"
  skills/
    flutter-mcp-toolkit-guide/SKILL.md
    flutter-mcp-toolkit-setup/SKILL.md
    flutter-mcp-toolkit-inspect/SKILL.md
    flutter-mcp-toolkit-control/SKILL.md
    flutter-mcp-toolkit-debug/SKILL.md
  mcp.json                       # MCP server config (consumed by Cursor + Codex)
  README.md
```

Per-target install paths (where `init` writes):

| Target | Path | Mechanism |
|---|---|---|
| Claude Code (project) | `.claude/skills/flutter-mcp-toolkit/<id>/SKILL.md` | Copy `skills/` subtree |
| Claude Code (user) | `~/.claude/skills/flutter-mcp-toolkit/<id>/SKILL.md` | Copy `skills/` subtree |
| Cursor (local plugin) | `~/.cursor/plugins/local/flutter-mcp-toolkit/` | Copy whole plugin dir; Cursor auto-discovers via `.cursor-plugin/plugin.json` |
| Codex | `~/.codex/plugins/cache/local/flutter-mcp-toolkit/local/` | Copy whole plugin dir; register entry in `~/.agents/plugins/marketplace.json` |
| Cline | `.clinerules/flutter-mcp-toolkit-<id>.md` | Generate flat-file copies (Cline's only format) |
| Cross-platform fallback | `.agents/skills/<id>/SKILL.md` | Both Cursor and Codex docs list this as a recognized path |

### 3.3 Mode Prelude (CLI vs MCP)

Each canonical `SKILL.md` body has a single placeholder near the top:

```markdown
---
name: flutter-mcp-toolkit-control
description: Drive a running Flutter app — tap, scroll, type, hot-reload, navigate.
---

<!-- @FMT_MODE_PRELUDE -->

## When to use
…
Call `tap_widget` with `{ selector: ... }` to tap a widget.
```

`flutter-mcp-toolkit init <agent>` substitutes the marker with one of:

**MCP mode prelude:**

```markdown
> Calls in this skill are MCP tools registered by `flutter-mcp-toolkit-server`.
> Tool names match the bare name in this skill (e.g. `tap_widget` → `fmt_tap_widget`).
> Errors return the standard envelope: read `error.code` and follow `error.recovery`.
> If the tool isn't in your tool list, the MCP server isn't connected — see `flutter-mcp-toolkit-setup`.
```

**CLI mode prelude:**

```markdown
> Calls in this skill run via the `flutter-mcp-toolkit` CLI binary:
>     flutter-mcp-toolkit exec --name <tool> --args '<json>'
> Output is JSON on stdout. Errors come as `{"error":{"code":..., "message":..., "recovery":...}}`.
> Throughout this skill, calls are written as `tap_widget(selector: "...")` — translate to the CLI form.
> If the binary isn't on PATH, see `flutter-mcp-toolkit-setup`.
```

The skill body is mode-agnostic. The placeholder is a comment so unsubstituted skills still render legally.

### 3.4 Mode Detection

`detectMode()` in the `init` command:

1. If user already has the MCP server wired into the target agent's MCP config → **MCP**.
2. Else if `flutter-mcp-toolkit` is on `$PATH` → **CLI**.
3. Else → fail loud with the install command.

Override flag: `--mode mcp|cli|auto` (default `auto`).

### 3.5 Tooling — Source of Truth

Two layers:

**Build-time (contributor loop):**

- `make sync-skills` reads `plugin/` and writes to all in-repo target locations (`.claude/skills/`, `.cursor/plugins/local/`, etc.) so contributors testing skills in their own agent see them live.
- CI runs the same and **fails on drift** between source and emitted copies.

**Install-time (end-user):**

- `tool/build_skill_assets.dart` reads `plugin/` at CLI build time and bakes contents into `lib/src/skill_assets.g.dart` as Dart string constants.
- `flutter-mcp-toolkit init <agent>` substitutes the prelude into bundled bodies and writes to the target's expected path. Single binary, works offline, no network fetch, version-locked to the binary.

### 3.6 Runtime validation CLI (`validate-runtime`)

The `flutter-mcp-toolkit validate-runtime` subcommand is the preferred one-shot smoke test (toolkit extensions, capture, view details, app errors; optional post–hot-reload capture) instead of hand-rolled `exec` sequences.

**Target resolution (implementation contract):**

- Effective VM websocket URI = `validate-runtime --target <ws_uri>` when set; otherwise global **`--vm-service-uri <ws_uri>`** when set (same string shape as `app.debugPort.wsUri` from `flutter run --machine`).
- If **both** `--target` and `--vm-service-uri` are set and **differ**, **`--target` wins** and the CLI emits a **stderr warning** that `--vm-service-uri` was ignored.

**Visual capture gate:**

1. **Primary:** `capture_ui_snapshot` with `screenshotMode: auto`, `permissionPolicy: auto_request_once`, with view-details and errors omitted for the gate step only.
2. **Fallback:** If that step fails with `get_screenshots_failed`, the descriptor is **retryable**, and the failure is classified as host **`desktop_window`** capture (message substring and/or `permission.actualMode` / `requestedMode` in error `details`), run **`capture_ui_snapshot_flutter_layer`** once with `screenshotMode: flutter_layer`, same permission policy.
3. **Post-reload:** With `--after-reload`, the same **auto then `flutter_layer` fallback** applies to **`capture_ui_snapshot_after_reload`** / **`capture_ui_snapshot_after_reload_flutter_layer`**, in addition to existing transient **post-reload** retries (`_shouldRetryPostReloadCapture`).

**Success envelope:**

- `data.summary.captureFallbackUsed` is **`true`** when a `*_flutter_layer` step completed successfully after the primary capture step failed.
- `data.summary.captureMode`, `captureBackend`, and `screenshotFiles` reflect the **winning** attempt (successful fallback overrides failed primary for summary fields).

**Doc parity:** `mcp_server_dart/README.md`, `plugin/skills/flutter-mcp-toolkit-setup/SKILL.md`, and `plugin/skills/flutter-mcp-cli-runtime-validation/SKILL.md` track this behavior.

### 3.7 MCP server registry key (`mcpServers` in client JSON)

- **Canonical** key for new configs: **`flutter-mcp-toolkit`** — matches the product / binary family and avoids confusion with the optional **`flutter-mcp-toolkit-runtime`** *agent* in Claude Code (legacy MCP key **`flutter-inspector`** is unrelated to that agent id).
- **Legacy** key **`flutter-inspector`** remains valid for existing user configs and older Cursor deeplinks; `tool/contracts/check_plugin_surfaces.sh` accepts **either** key but requires the **`command`** to reference **`flutter-mcp-toolkit-server`** (or `${FLUTTER_MCP_BIN:-flutter-mcp-toolkit-server}`).
- Shipped **`plugin/mcp.json`** uses the canonical key.

## 4. User Flows

### 4.1 Human Setup Flow (4 steps)

```bash
# 1. Install binary (auto-updates $PATH)
curl -fsSL https://raw.githubusercontent.com/Arenukvern/flutter-mcp-toolkit/main/install.sh | bash

# 2. Add toolkit to the Flutter app + generate init boilerplate
cd my-flutter-app
flutter-mcp-toolkit codegen-init   # runs `flutter pub add flutter_mcp_toolkit` + edits main.dart

# 3. Wire up the agent
flutter-mcp-toolkit init claude-code     # or: cursor | codex | cline | all

# 4. Run the app
flutter run --debug
```

No manual JSON editing, no port flag memorization, no per-agent doc reading.

### 4.2 Agent Flow (every session)

1. Agent loads `flutter-mcp-toolkit-guide` (description matches "user wants to inspect/drive a Flutter app").
2. Guide says: *Run `flutter-mcp-toolkit doctor --json` first. If green, jump to `inspect` or `control` based on intent. If red, load `setup`.*
3. Agent runs doctor, gets structured output, decides next skill.
4. Agent loads exactly one of `inspect` / `control` / `debug` and proceeds with mode-specific calls per the prelude.

## 5. Naming Alignment

Decision row: "long IDs in install/discovery surfaces, short prefix in MCP hot path".

| Surface | Value |
|---|---|
| Plugin dir / GitHub repo | `flutter-mcp-toolkit` |
| Skill IDs | `flutter-mcp-toolkit-{guide,setup,inspect,control,debug}` |
| MCP tool prefix (every call) | `fmt_` (e.g. `fmt_tap_widget`) |
| CLI binary | `flutter-mcp-toolkit` |
| Server binary | `flutter-mcp-toolkit-server` |
| MCP `mcpServers` key (client JSON) | **`flutter-mcp-toolkit`** (canonical); **`flutter-inspector`** (legacy, still accepted by contract checks) |
| Claude Code runtime subagent (`plugin/agents/…`) | **`flutter-mcp-toolkit-runtime`** (`flutter-mcp-toolkit-runtime.md`) |
| Pub package | `flutter_mcp_toolkit` (snake_case Pub norm) |

## 6. Migration

### 6.1 Renames

| From | To | Mechanism |
|---|---|---|
| MCP tool prefix `core_*` | `fmt_*` | `mcp_capability_kernel` prefix constant + `tool/contracts/expected_tool_surface.txt`; snapshot test enforces |
| `flutter_inspector_mcp` (binary) | `flutter-mcp-toolkit-server` | Makefile, `bin/`, `install.sh` checksums |
| `flutter_mcp_cli` (binary, legacy) | `flutter-mcp-toolkit` | Same, plus add `codegen-init` and `init <agent>` subcommands |
| MCP key `flutter-inspector` | `flutter-mcp-toolkit` (new installs) | Shipped `plugin/mcp.json`; contract accepts both keys |
| Claude subagent `flutter-inspector` (file / id) | `flutter-mcp-toolkit-runtime` | `plugin/agents/flutter-mcp-toolkit-runtime.md`; disambiguates from legacy MCP key |
| `mcp_flutter` (GitHub repo) | `flutter-mcp-toolkit` | `gh repo rename`; auto-redirects |
| `mcp_toolkit` (Pub) | `flutter_mcp_toolkit` | New publish; old name kept as deprecated alias for one minor version |
| `CorePrefix` (capability kernel constant) | `FmtPrefix` | Kernel's existing tested rename path |

Tool *names* (`tap_widget` etc.) — kept. Per-tool normalization is a separate spec.

### 6.2 Docs Migration

| File today | Disposition |
|---|---|
| `docs/ai_agents/execution_playbook.mdx` | → `flutter-mcp-toolkit-setup/SKILL.md`. Original becomes 5-line redirect. |
| `docs/ai_agents/cursor.mdx` | DELETE — replaced by `init cursor` |
| `docs/ai_agents/codex.mdx` | DELETE — replaced by `init codex` |
| `docs/ai_agents/claude.mdx` | DELETE — replaced by `init claude-code` |
| `docs/ai_agents/cline.mdx` | DELETE — replaced by `init cline` |
| `docs/ai_agents/overview.mdx` | Shrink to point at the plugin and human start-here |
| `docs/core/built_in_tools.mdx` | → split into `inspect`, `control`, `debug` skills. Original deleted. |
| `docs/core/error_code_playbook.mdx` | → `flutter-mcp-toolkit-debug/SKILL.md`. Original deleted. |
| `docs/start_here/*.mdx` | Keep, rewrite step 1 to be the four-step install. |
| `docs/getting_started/manual_installation.mdx` | DELETE — `init` replaces manual setup |
| `docs/getting_started/manual_client_setup.mdx` | DELETE |
| `docs/getting_started/llm_install_files.mdx` | DELETE |
| `docs/troubleshooting/*` | Keep; linked from `setup` skill |
| `docs/contributing/*` | Keep; add section on editing skills + `make sync-skills` |
| `README.md` hero | Rewrite as 4 numbered install steps + "*That's it.*" |

**Net delete: 7 docs files. Net add: 5 skills.**

## 7. Implementation Order

1. Build asset pipeline (`tool/build_skill_assets.dart`) and CI drift check.
2. Skill bodies — write the 5 `SKILL.md` files, mode-agnostic, with `<!-- @FMT_MODE_PRELUDE -->` placeholder.
3. `init <agent>` command in CLI binary (substitution + per-target write logic, both Cursor + Codex manifests).
4. Tool prefix rename (`core_` → `fmt_`) in capability kernel + contracts file + snapshot test.
5. Binary renames; update `install.sh` checksums and PATH update.
6. `codegen-init` command (generate toolkit boilerplate in user's `main.dart`).
7. Docs migration (delete listed files, redirect/rewrite the rest, update `docs.json`).
8. README rewrite.
9. Repo rename (last — irreversible-ish, after tests pass).
10. Pub package rename (publish `flutter_mcp_toolkit`, deprecate `mcp_toolkit`).

Steps 1-6 unblock v3.0.0. Steps 7-10 are concurrent polish.

## 8. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Cursor/Codex skill discovery semantics drift before v3.0.0 ships | Low | Verified docs 2026-04-29; `.agents/skills/` cross-platform path is fallback |
| Pub package rename breaks downstream users | Medium | Keep `mcp_toolkit` as deprecated alias for one minor version |
| `codegen-init` AST-edit of `main.dart` corrupts user code | Medium | Default to "emit snippet to stdout" mode; only attempt edit on a recognized untouched template |
| Mode auto-detect picks wrong path on a setup with both | Low | `--mode` flag overrides; `init` prints chosen mode and the override command |
| MCP config file rewrite (`init claude-code`) clobbers user's other servers | Medium | Read-modify-write with automatic backup `.bak`, idempotent (re-running is safe), `--dry-run` flag |
| Repo rename breaks existing GitHub links | Low | GitHub auto-redirects from old name |
| Snapshot test on `core_` → `fmt_` rename is noisy | Low | Single-commit rename; snapshot updates atomically with prefix constant |

## 9. Open Questions

To resolve in the writing-plans phase, not now:

1. **Pub package rename timing**: ship 3.0.0 with old name and rename in 3.1, OR rename now? *Leaning: rename now since 3.0 is a major bump anyway.*
2. **MCP config file editing**: in-place modify vs. emit a sample for the user to merge? *Leaning: in-place modify with `.bak` backup + `--dry-run` flag.*
3. **`codegen-init` AST edit risk**: AST-edit `main.dart` (risky) or emit snippet for user to paste (safer)? *Leaning: emit snippet by default; offer to edit only on recognized template.*

## 10. References

- [Cursor plugin docs](https://cursor.com/docs/plugins) — `.cursor-plugin/plugin.json` manifest format
- [Cursor skills docs](https://cursor.com/docs/skills) — `SKILL.md` with `name`/`description` frontmatter
- [Codex plugin docs](https://developers.openai.com/codex/plugins/build) — `.codex-plugin/plugin.json` manifest format
- [Codex skills docs](https://developers.openai.com/codex/skills) — `.agents/skills/<id>/SKILL.md`
- ADR 0001 — capability kernel
- ADR 0002 — Playwright parity
- `todo/live_edit_reintegration.md` — deferred
- `todo/p3_network_introspection.md` — deferred
