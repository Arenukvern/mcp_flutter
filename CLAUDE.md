# mcp_flutter — Claude Code Context

MCP server + Flutter toolkit that lets AI assistants inspect and interact with
Flutter apps via the Dart VM Service. Dart-based server with dynamic tools
registration from the Flutter app side.

See `ARCHITECTURE.md` for the full system overview and `docs/ai_agents/execution_playbook.mdx`
for the AI-agent runbook.

## Repository Layout (monorepo)

- `mcp_server_dart/` — MCP server + `flutter_mcp_cli` binary. Primary build target.
- `mcp_toolkit/mcp_toolkit/` — Dart package integrated into Flutter apps; registers
  VM service extensions (`ext.mcp.toolkit.*`) and supports dynamic tool registration.
- `flutter_test_app/` — Showcase/example Flutter app used for e2e testing.
- `flutter_live_edit/` — Live-edit overlay toolkit + `live_edit_tooling_ui_kit`
  app for iterating on bubble/panel/chip widgets in isolation.
- `maestro/`, `tool/contracts/`, `tool/release/` — test flows, contract checks, release scripts.
- `docs/` — audience-first MDX docs (humans + AI agents).

## Commands

```bash
make install              # cd mcp_server_dart && make setup (pub get + deps)
make build                # compile mcp_server_dart binaries to build/
make showcase             # run flutter_test_app on macOS, print VM URI (blocks)
make check-contracts      # SDK parity + error code + docs drift checks
make inspect              # launch MCP inspector against built server
```

Per-package: `cd mcp_server_dart && make compile` produces
`build/flutter_inspector_mcp` and `build/flutter_mcp_cli`.

## v3.0 Gotchas (non-obvious)

- **Preflight first**: run `flutter_mcp_cli doctor --json` before any VM-dependent
  automation — parses env, ports, and app reachability. Binary is
  `mcp_server_dart/build/flutter_mcp_cli` after `make build`.
- **Safe-write flags** on snapshot/bundle commands: `--check --diff --backup --no-overwrite`
  (atomic write/publish). Don't skip these in automation.
- **Error envelope contract**: errors are `{code, message, details, descriptor, recovery}`.
  Read `error.descriptor` (not top-level) when parsing.
- **Strict schemas**: `additionalProperties: false` by default — unknown params reject.
- **Dump RPCs disabled** by default (token cost); opt in with `--dumps`.

## Connection model

- VM Service port defaults to **8181** (override: `--dart-vm-port`).
- MCP transport is **stdio** — no inbound network port.
- Target app must run in **debug mode**; `mcp_toolkit` must be initialized.

## Live-edit UI iteration

To refine bubble/panel/chip widgets without a full connect cycle, run the
`live_edit_tooling_ui_kit` app — it renders the tool layer with prefilled data.
Main hit-testing domain is `appScene` (see ARCHITECTURE.md "Live Edit Overlay").

## Conventions

- Dart formatting via `dart format`; analysis via per-package `analysis_options.yaml`.
- Commit style: imperative mood (see `git log`).
- Don't edit `dist/` or `build/` — generated.
- `.clinerules` is for Cline's memory bank workflow; not authoritative for Claude.
