# Reproducible CLI demo GIFs (vhs)

Terminal recordings for docs quickstart / CI pages. Sources are [Charmbracelet vhs](https://github.com/charmbracelet/vhs) `.tape` files; GIFs are committed so docs render without running vhs locally.

## Regenerate

Prereqs: `vhs`, `ttyd`, `ffmpeg`, `flutter` (3.47.5+), release `flutter-mcp-toolkit` on `PATH`, Chrome (for harness/exec demos on Linux).

```bash
# Install vhs (example: Linux amd64 deb from GitHub releases)
# export PATH="$HOME/.local/bin:$HOME/flutter/bin:$PATH"
# export DISPLAY=:0  # or your X11 display; Xvfb works headless

bash docs/assets/gifs/regenerate_cli_gifs.sh
# or per file:
vhs docs/assets/gifs/cli-doctor.tape
vhs docs/assets/gifs/cli-exec.tape
vhs docs/assets/gifs/harness.tape
```

Set `HARNESS_GIF_DEVICE=linux` to attempt a GTK desktop run of `showcase/native_layer_capture_fixture` (needs `ninja`, `cmake`, `libgtk-3-dev`, and a working `clang++` + `libstdc++` toolchain). Default is **`chrome`** headless on Linux, which drives the same fixture with `mcp_toolkit` extensions attached.

## Size budget

| Asset | Target | Hard cap |
| --- | --- | --- |
| Duration | 8–15s playback | — |
| Width | 800–1000px (tapes use **1008px**) | — |
| File size | ≤2MB | **5MB** (`regenerate_cli_gifs.sh` fails above cap) |
| Theme | GitHub Dark, font **14px** | — |

After recording, `regenerate_cli_gifs.sh` writes probe PNG/text under `frames/` (gitignored locally; CI workflow uploads GIFs only).

## Tapes in this folder

| Tape | GIF | Content |
| --- | --- | --- |
| `cli-doctor.tape` | `cli-doctor.gif` | `warm_fixture` (hide) → `doctor --help` → `doctor_demo_display` (`criticalFailures=0`) |
| `cli-exec.tape` | `cli-exec.gif` | `warm_fixture` (hide) → `exec_demo_display` + `get_extension_rpcs` JSON preview |
| `harness.tape` | `harness.gif` | `scenarios/harness_counter_smoke.dart` scenario, passes, summary |

Supporting scripts live under `scenarios/` (not committed lockfile noise: run `dart pub get` there before harness recording).

## Recorded vs shot-list only

**Recorded in this repo (Linux agent VM):**

- All three GIFs above with **real** CLI and harness output (no faked JSON).
- Harness / exec demos use **`native_layer_capture_fixture`** via **headless Chrome** (`HARNESS_GIF_DEVICE=chrome`) because the snapshot VM lacked a working Flutter **Linux GTK** link (`clang++` could not link `libstdc++`). CI/workflow can retry with `HARNESS_GIF_DEVICE=linux` on a full desktop runner.

**Shot-list only (Anton / Mac manual — IDE + window visible):**

| Flow | What to capture |
| --- | --- |
| See the UI | MCP client open beside **macOS** `showcase/flutter_test_app`; `fmt_get_screenshots` / semantic snapshot in chat |
| Drive the UI | Terminal + app window; agent taps via `fmt_tap` / harness `ToolkitDriver` |
| Debug | Errors + stack in client; hot reload proof (`r` in `flutter run` or harness) |
| Custom tools | Dynamic tool list in client after app registers tools (`fmt_list_client_tools_and_resources`) |
| Hot reload | Side-by-side editor, terminal `flutter run`, before/after screenshot |
| MCP server connect | `flutter-mcp-toolkit init cursor` + Cursor MCP panel connected |
| **Harness (macOS / iOS sim)** | Terminal running `dart run packages/harness/tool/showcase.dart` or a `Scenario` file **with the app window visible beside the terminal** — pair with `example/desktop_pair.dart` on macOS; on iOS sim, show Simulator + `flutter run` attach line |
| **Harness (proof output)** | Same layout: scroll to `ALL PASS` / `FAILURES` summary and any evidence paths the scenario prints |

Suggested Mac harness layout: **60% terminal / 40% app window**, full screen recording trimmed to 8–15s, then `ffmpeg`/`gifsicle` downscale to 960px wide to match CLI GIFs.