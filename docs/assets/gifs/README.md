# Reproducible CLI demo GIFs (vhs)

Terminal recordings for docs quickstart / CI / harness pages. Sources are [Charmbracelet vhs](https://github.com/charmbracelet/vhs) `.tape` files; GIFs are committed so docs render without running vhs locally.

## Regenerate

Prereqs: `vhs`, `ttyd`, `ffmpeg`, `flutter` (3.47.5+), release `flutter-mcp-toolkit` on `PATH`, Chrome (headless `drive-web` / `drive-flutter-chrome`), X11 (`DISPLAY`).

```bash
export PATH="$HOME/.local/bin:$HOME/flutter/bin:$PATH"
export DISPLAY=:99   # Xvfb works headless

bash docs/assets/gifs/regenerate_cli_gifs.sh
```

`regenerate_cli_gifs.sh` provisions **intentcall** (`tool/ci/checkout_intentcall.sh`) and symlinks `../intentcall` so `showcase/flutter_demo` path overrides resolve — same as native-layer CI.

## Size budget

| Asset | Target | Hard cap |
| --- | --- | --- |
| Duration | 8–15s playback | — |
| Width | 800–1000px (tapes use **1008px**) | — |
| File size | ≤2MB | **5MB** (`regenerate_cli_gifs.sh` fails above cap) |
| Theme | GitHub Dark, font **14px** | — |

Probe output lands under `frames/` (gitignored).

## Tapes in this folder

| Tape | GIF | On-screen content |
| --- | --- | --- |
| `harness-flutter.tape` | `harness-flutter.gif` | Hide: `flutter build web` for `showcase/flutter_demo`. Show: `make drive-flutter-chrome` — semantic tree, Increment ×3, Name, Count: 3, OK |
| `harness-web.tape` | `harness-web.gif` | `make drive-web` — CDP tree on `showcase/web_demo`, increment/type/profile, OK |
| `cli-exec.tape` | `cli-exec.gif` | Hide: headless `flutter run` on `flutter_demo` with `--host-vmservice-port=8181` (pinned port). Show: `flutter-mcp-toolkit --vm-service-uri … exec --name semantic_snapshot --pretty` |

Harness flows mirror [`showcase/README.md`](../../showcase/README.md) and skill `flutter-mcp-e2e-harness` (`make drive-flutter-chrome`, `make drive-web`).

### Exec warm path (oka gap)

Anton’s target owner is **`oka dev` / `oka_harness`** writing `.flutter_mcp/runner-session.json` with a known VM endpoint. **Published `oka_harness` 0.9.1** in this repo only ships **Android** `AppTarget`s — no Chrome/desktop launcher in the hosted package yet. Until oka publishes a Chrome dev session target, the exec tape uses the same **pinned-port** pattern as `showcase/flutter_test_app` (`--host-vmservice-port=8181`) off-camera only; the on-camera line is first-class CLI flags (no jq/python/bash helpers).

**`cli-doctor.gif`** is deferred until doctor output is human-readable in a terminal recording (tracked separately).

## Shot-list only (macOS manual)

| Flow | What to capture |
| --- | --- |
| Instrumented harness + window | `make drive-flutter` with the `flutter_demo` window beside the terminal |
| Two-instance desktop | `dart run example/desktop_pair.dart --skip-build` from `packages/harness` (macOS) |
| See / drive / debug UI | MCP client beside `showcase/flutter_test_app`; `fmt_*` or harness `ToolkitDriver` |

Suggested layout: **60% terminal / 40% app window**, trim to 8–15s, downscale to ~960px wide to match CLI GIFs.