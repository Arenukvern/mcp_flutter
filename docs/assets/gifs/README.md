# Reproducible CLI demo GIFs (vhs)

Terminal recordings for docs quickstart / CI / harness pages. Sources are [Charmbracelet vhs](https://github.com/charmbracelet/vhs) `.tape` files; GIFs are committed so docs render without running vhs locally.

## Regenerate

Prereqs: `vhs`, `ttyd`, `flutter` (3.47.5+), release `flutter-mcp-toolkit` on `PATH`, Chrome (headless drives), X11 (`DISPLAY`).

```bash
export PATH="$HOME/.local/bin:$HOME/flutter/bin:$PATH"
export DISPLAY=:99   # Xvfb works headless

bash docs/assets/gifs/regenerate_cli_gifs.sh
```

The script compiles the workspace **`flutter-mcp-toolkit`** (`mcp_server_dart/make compile`), provisions **intentcall** for `showcase/flutter_demo`, prebuilds web assets, and runs vhs. **No URI grep/sed** — `cli-exec` warm uses `showcase.dart --web --detach` writing `runner-session.json`; `flutter-mcp-toolkit exec` in the app directory uses runner discovery.

## Size budget

| Asset | Target | Hard cap |
| --- | --- | --- |
| Duration | 8–15s playback | — |
| Width | 800–1000px (tapes use **1008px**) | — |
| File size | ≤2MB | **5MB** (`stat` check in `regenerate_cli_gifs.sh`) |
| Theme | GitHub Dark, font **14px** | — |

## Tapes

| Tape | GIF | Content |
| --- | --- | --- |
| `harness-flutter.tape` | `harness-flutter.gif` | `make drive-flutter-chrome` — full showcase drive ending in **OK** |
| `harness-web.tape` | `harness-web.gif` | `make drive-web` — CDP tier **OK** |
| `cli-exec.tape` | `cli-exec.gif` | Hide: `WEB_HEADLESS=1 dart run packages/harness/tool/showcase.dart --web --detach`. Show: `flutter-mcp-toolkit exec --name semantic_snapshot --pretty` from `showcase/flutter_test_app` |

Harness flows mirror [`showcase/README.md`](../../showcase/README.md) (`make drive-flutter-chrome`, `make drive-web`).

### Exec warm path / oka

- **Launcher today:** `packages/harness/tool/showcase.dart --web --detach` (pinned `--host-vmservice-port`, default **8181**).
- **`oka_harness` (pub.dev 0.10.3+):** **Android-only** `AppTarget` — mobile launcher via `oka dev`, not used for these Linux Chrome recordings. No new oka wiring in this docs PR.
- **Tokenless `ws://127.0.0.1:8181/ws`:** works on **macOS/desktop** with `--disable-service-auth-codes`. **Chrome (DWDS) still uses per-session tokens**, so the exec tape uses cwd-scoped fmtk discovery after the showcase detach, not a static `/ws` path in the tape.

**`cli-doctor.gif`** remains deferred until doctor output is human-readable in a terminal recording.

## Shot-list only (macOS manual)

| Flow | What to capture |
| --- | --- |
| Instrumented harness + window | `make drive-flutter` beside the `flutter_demo` window |
| Two-instance desktop | `dart run example/desktop_pair.dart --skip-build` from `packages/harness` |
| Tokenless exec (desktop) | `flutter run --disable-service-auth-codes --host-vmservice-port=8181` + `flutter-mcp-toolkit --vm-service-uri ws://127.0.0.1:8181/ws exec …` beside the app |