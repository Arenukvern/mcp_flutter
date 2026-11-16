---
name: flutter-mcp
description: Use this skill whenever inspecting, interacting with, or live-editing a running Flutter app via the Flutter MCP toolkit server (`mcpServers` key **`flutter-mcp-toolkit`**). Covers preflight, snapshot/tap/enter/scroll loop, hot-reload validation, and error envelope parsing.
---

<!-- @FMT_MODE_PRELUDE -->

# Flutter MCP

Golden path for agents driving a live Flutter app via the **`flutter-mcp-toolkit`** MCP server entry (`flutter-mcp-toolkit-server` on stdio).

## When to use

- User references a running Flutter app (debug mode) and wants to inspect, screenshot, interact with, or hot-reload it.
- User pastes a VM service URI (`ws://127.0.0.1:8181/.../ws`) or mentions port 8181.
- You need runtime proof (before/after screenshots) that a code edit took effect.

## Preflight (always first)

Before any VM-dependent call:

1. Ensure the app is running in **debug** mode with `mcp_toolkit` bootstrap (see `flutter-mcp-toolkit codegen-init`).
2. Call **`fmt_discover_debug_apps`** or **`fmt_connect_debug_app`** (use `connection.uri` when multiple targets exist).
3. Optionally run **`fmt_get_extension_rpcs`** to confirm `ext.mcp.toolkit.*` extensions exist.

## Core loop

1. **`fmt_semantic_snapshot`** — read UI structure and refs.
2. **`fmt_tap_widget`** / **`fmt_enter_text`** / **`fmt_scroll`** — act on refs from the snapshot.
3. **`fmt_hot_reload_flutter`** or **`fmt_hot_reload_and_capture`** — apply code changes.
4. **`fmt_wait_for`** with `{kind: stable, stableWindowMs: 300}` then re-snapshot.

## Screenshots

Prefer **`fmt_get_screenshots`** (Flutter render pipeline over VM service). They work when the app window is in the background. Use **`fmt_capture_ui_snapshot`** when you need a single PNG path on disk without the batch screenshot helper.

## Errors

Parse structured JSON envelopes (`ok`, `errorCode`). See skill **`flutter-mcp-toolkit-debug`** for recovery playbooks.