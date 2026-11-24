# Reproducible CLI demo GIFs (vhs)

Terminal recordings for docs quickstart / CI / harness pages. Sources are [Charmbracelet vhs](https://github.com/charmbracelet/vhs) `.tape` files; GIFs are committed so docs render without running vhs locally.

## Regenerate

Prereqs: `vhs`, `ttyd`, `flutter` (3.50.0+), workspace `flutter-mcp-toolkit` on `PATH`, Chrome (headless drives), X11 (`DISPLAY`).

```bash
export PATH="$HOME/.local/bin:$HOME/flutter/bin:$PATH"
export DISPLAY=:99   # Xvfb works headless

dart run docs/assets/gifs/regenerate.dart
```

`regenerate.dart` compiles the workspace CLI (`mcp_server_dart/make compile`), provisions intentcall when available (via `tool/ci/checkout_intentcall.sh` into `intentcall/`), prebuilds web assets, runs vhs, and enforces the **GIF size budget** on the three vhs GIFs (2MB warning, 5MB hard cap; a missing output fails the run). The legacy manual recording `docs/view_screenshots.gif` (~6 MB, restored in #214) is reported but not capped, because vhs cannot regenerate it; Phase 2 `view-screenshots.tape` replaces it.

If a sibling `../intentcall` checkout already exists, it must be at the commit in `tool/ci/intentcall_ref.txt` (showcase path deps resolve through that link). `regenerate.dart` exits with a clear error otherwise.

Pull requests that touch `docs/assets/gifs/**` or this workflow run **GIF regenerate preflight** only (`dart run docs/assets/gifs/regenerate.dart --preflight` — compile, PATH, tape checks; no vhs). Full vhs regeneration is **workflow_dispatch** only (artifact upload; `contents: read`, no repo writes).

Default showcase app: `showcase/flutter_test_app` (`SHOWCASE_APP_DIR` overrides).

## Size budget

| Asset | Target | Hard cap |
| --- | --- | --- |
| Duration | 8–15s playback | — |
| Width | 800–1000px (tapes use **1008px**) | — |
| File size | ≤2MB | **5MB** (`regenerate.dart`) |
| Theme | GitHub Dark, font **14px** | — |

## Tapes (first-class commands only — no `make`)

| Tape | GIF | Content |
| --- | --- | --- |
| `harness-flutter.tape` | `harness-flutter.gif` | `dart run showcase/drivers/bin/drive_flutter.dart --device chrome` |
| `harness-web.tape` | `harness-web.gif` | `dart run showcase/drivers/bin/drive_web.dart` |
| `cli-exec.tape` | `cli-exec.gif` | Hide: `dart run packages/harness/tool/showcase.dart --web --detach`. Show: `flutter-mcp-toolkit exec --name fmt_semantic_snapshot` from `showcase/flutter_test_app` |

Phase 2: `view-screenshots.tape` → replace `docs/view_screenshots.gif`.

## G1 — Agent in Cursor (manual shot list)

Record on macOS; export GIF or MP4 under budget; **not** automated in Linux CI.

1. **Setup (off-camera):** `dart run packages/harness/tool/showcase.dart` (macOS) or `--web` (Chrome); confirm MCP server in Cursor; open `showcase/flutter_test_app` if not already running.
2. **Split frame:** Cursor chat (left) + running app (right).
3. **Prompt:** “Discover my debug Flutter app, take a semantic snapshot, describe the shipments home screen.”
4. **Show tool calls:** `fmt_discover_debug_apps` → `fmt_semantic_snapshot` (refs: `shipment_create_button`, `shipment_empty_state` or list items).
5. **Act:** “Tap Create shipment, fill recipient name and email, submit, confirm the new row appears in the list.” Show `fmt_click` / `fmt_enter_text` (or `fmt_fill_form`) and app reaction.
6. **Proof:** Optional `fmt_get_screenshots` image block in chat.
7. **Duration:** 12–20s trimmed; width 1008px or 1280px; file ≤2MB preferred.

## Shot-list (macOS manual, optional)

| Flow | What to capture |
| --- | --- |
| Harness + app window | `dart run showcase/drivers/bin/drive_flutter.dart` against `flutter_test_app` |
| Two-instance desktop | `dart run example/desktop_pair.dart --skip-build` from `packages/harness` |
| Tokenless exec (desktop) | `flutter run --disable-service-auth-codes --host-vmservice-port=8181` + `flutter-mcp-toolkit exec …` beside the app |
