# flutter-mcp-toolkit (plugin)

Single source of truth for the shippable plugin: **Cursor**, **Codex**, and **Claude Code** marketplace layouts, MCP registration, skills, and the optional installer.

## What this plugin ships

Three layers (not “MCP server only”):

```text
AI agent
    │
    ├─► flutter-mcp-toolkit-server (30 fmt_* tools: inspect, control, debug)
    │
    └─► fmt_list_client_tools_and_resources / fmt_client_tool / fmt_client_resource
              │
              ▼ VM Service extensions (ext.mcp.toolkit.*)
        Flutter app (debug) + mcp_toolkit
              │
              └─► AgentCallEntry.tool / .resource registered via addMcpTool
```

- **Static tools** — semantic snapshot, tap, scroll, hot-reload, errors, etc.
- **Dynamic registry** — your app or game defines custom tools/resources at runtime; see [Dynamic tool registry](../docs/core/dynamic_tools_registry.mdx) and [Creating dynamic tools](../docs/guides/creating_dynamic_tools.mdx).
- **`plugin/mcp.json`** passes `--dynamics` so the server bridges the in-app registry.

## End-user install

1. **`flutter-mcp-toolkit init <agent>`** — skills + MCP config (recommended)
2. **`npx skills add Arenukvern/mcp_flutter`** — skills only ([open skills ecosystem](https://skills.sh)); see [docs/ai_agents/overview.mdx](../docs/ai_agents/overview.mdx)
3. **Claude git marketplace** — `/plugin marketplace add Arenukvern/mcp_flutter`
4. **Codex git marketplace** — `codex plugin marketplace add Arenukvern/mcp_flutter`

All paths materialize from the embedded skill bundle generated from this directory (`make sync-skills`).

## Bundled skills (14)

| Skill | Purpose |
|-------|---------|
| `flutter-mcp-toolkit-guide` | Entry router |
| `flutter-mcp-toolkit-setup` | Install / doctor |
| `flutter-mcp-toolkit-inspect` | Read app state |
| `flutter-mcp-toolkit-control` | Drive UI |
| `flutter-mcp-toolkit-debug` | Diagnose failures |
| **`flutter-mcp-toolkit-custom-tools`** | **Register dynamic MCP tools/resources in the app** |
| `flutter-mcp-boundary-audit` | Contract/schema boundary audit for tool registration, dynamic registry, CLI/MCP parity, migrators, and platform docs |
| `flutter-mcp` | Golden-path runtime loop |
| `flutter-mcp-cli-runtime-validation` | CLI `validate-runtime` |
| `flutter-mcp-toolkit-intentcall-migration` | Legacy call-entry to `AgentCallEntry` migration |
| `flutter-mcp-toolkit-maintain-web` | `flutter_test_app` web / WebMCP maintenance |
| `flutter-mcp-toolkit-maintain-macos` | `flutter_test_app` macOS native / IntentCall maintenance |
| `flutter-mcp-toolkit-dogfood-iterations` | Dogfood iteration scoring and artifact routing |
| `flutter-mcp-toolkit-repo-maintainer` | Release / repo maintenance |

Harness and video-production skills live in their owner repositories. This
plugin only ships the Flutter MCP Toolkit runtime, maintenance, migration, and
boundary-audit skills listed above.

Store listing copy: [docs/ai_agents/marketplace_copy.yaml](../docs/ai_agents/marketplace_copy.yaml).

## Layout

- `.cursor-plugin/plugin.json` — Cursor plugin manifest
- `hyperframes-cursor-plugin/plugin.json` — optional promo-only Cursor plugin (still requires `heygen-com/hyperframes` skills)
- `.codex-plugin/plugin.json` — Codex plugin manifest (+ `interface` for directory)
- `.claude-plugin/plugin.json` — Claude Code plugin manifest
- `mcp.json` — MCP server (`${FLUTTER_MCP_BIN:-flutter-mcp-toolkit-server}`, `--dynamics`)
- `install.sh` — prerequisite check (Dart, server binary version pin)
- `EXPECTED_SERVER_VERSION` — must match repo root `VERSION`
- `agents/flutter-mcp-toolkit-runtime.md` — Claude specialist agent
- `assets/` — store icons/screenshots (see [assets/README.md](assets/README.md))
- `skills/` — skill bodies; repo root [`skills/`](../skills) symlinks here for `npx skills`

## Editing skills

Edit any `skills/<id>/SKILL.md`, then run `make sync-skills` from the repo root. CI fails if `mcp_server_dart/lib/src/skill_assets.g.dart` is out of sync.

## Claude Code marketplace

Repo [`.claude-plugin/marketplace.json`](../.claude-plugin/marketplace.json) points `source` at `./plugin`. After `make build`, put `mcp_server_dart/build/flutter-mcp-toolkit-server` on `PATH` or set `FLUTTER_MCP_BIN`, then:

```bash
bash plugin/install.sh
```

Instrument the target Flutter app with `mcp_toolkit` (debug only) and run with VM service enabled as described in the main repo README.

Maintainers: [marketplace submission runbook](../docs/contributing/marketplace_submission_runbook.mdx).
