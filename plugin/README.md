# flutter-mcp-toolkit (plugin)

Single source of truth for the shippable plugin: **Cursor**, **Codex**, and **Claude Code** marketplace layouts, MCP registration, skills, and the optional installer.

End users can install via:

1. **`flutter-mcp-toolkit init <agent>`** — skills + MCP config (recommended)
2. **`npx skills add Arenukvern/mcp_flutter`** — skills only ([open skills ecosystem](https://skills.sh)); see [docs/ai_agents/overview.mdx](../docs/ai_agents/overview.mdx)
3. **Claude marketplace** — `bash plugin/install.sh` after the server binary is on `PATH`

All paths materialize from the embedded skill bundle generated from this directory (`make sync-skills`).

## Layout

- `.cursor-plugin/plugin.json` — Cursor plugin manifest
- `.codex-plugin/plugin.json` — Codex plugin manifest
- `.claude-plugin/plugin.json` — Claude Code plugin manifest
- `mcp.json` — MCP server registration (`${FLUTTER_MCP_BIN:-flutter-mcp-toolkit-server}`); consumed by Cursor, Codex, and Claude-oriented flows
- `install.sh` — prerequisite check (Dart, server binary version pin, optional CLI)
- `EXPECTED_SERVER_VERSION` — must match repo root `VERSION`
- `agents/flutter-mcp-toolkit-runtime.md` — Claude specialist agent definition
- `skills/` — task skills plus `flutter-mcp` (golden-path runtime) and `flutter-mcp-cli-runtime-validation` (CLI validate-runtime). Repo root [`skills/`](../skills) is a symlink here for `npx skills` discovery.

## Editing skills

Edit any `skills/<id>/SKILL.md`, then run `make sync-skills` from the repo root. CI fails if `mcp_server_dart/lib/src/skill_assets.g.dart` is out of sync.

## Claude Code marketplace

Repo [`.claude-plugin/marketplace.json`](../.claude-plugin/marketplace.json) points `source` at `./plugin`. After `make build`, put `mcp_server_dart/build/flutter-mcp-toolkit-server` on `PATH` or set `FLUTTER_MCP_BIN`, then:

```bash
bash plugin/install.sh
```

Instrument the target Flutter app with `mcp_toolkit` and run in debug with a fixed VM service port as described in the main repo README.
