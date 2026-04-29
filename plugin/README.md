# flutter-mcp-toolkit (plugin)

The shippable plugin source for `flutter-mcp-toolkit`. End users install via the
CLI (`flutter-mcp-toolkit init <agent>`); this directory is the source of truth
for skill bodies and platform manifests.

## Layout

- `.cursor-plugin/plugin.json` — Cursor plugin manifest
- `.codex-plugin/plugin.json` — Codex plugin manifest
- `mcp.json` — MCP server registration consumed by Cursor + Codex
- `skills/` — 5 task-focused skills (guide, setup, inspect, control, debug)

## Editing skills

Edit any `skills/<id>/SKILL.md`, then run `make sync-skills` from the repo
root. CI fails if the generated `skill_assets.g.dart` is out of sync.
