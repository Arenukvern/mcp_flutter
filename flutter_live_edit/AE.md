# Live Edit × Agentic Executables (AE)

[Agentic Executables](https://github.com/fluent-meaning-symbiotic/agentic_executables) turns **domain knowledge** into **deterministic workflows** (Know + Use). This repo uses it **optionally** so humans and agents share the same **Live Edit** vocabulary (tool names, user story, boundaries).

## When to refresh

See also `../../scripts/ae_live_edit_know.sh` from this folder’s parent (`mcp_flutter` root).

Re-run the know script after changing:

- `PRD.md`, `USER_STORY.md`, `CONTRACT.md`, or `BOUNDARIES.md`
- MCP tool wiring in `mcp_server_dart` that affects `LiveEditMcpToolNames`

## One-shot: build knowledge packs

From the **mcp_flutter** repo root (adjust `AE_ROOT` if your clone is not at `~/mcp/agentic_executables`):

```bash
chmod +x scripts/ae_live_edit_know.sh
AE_ROOT="${HOME}/mcp/agentic_executables" ./scripts/ae_live_edit_know.sh
```

The script uses `ae know build --path <file>` (local markdown). That flag is implemented in **this workspace’s** `agentic_executables` checkout next to `mcp_flutter`; sync or cherry-pick if you use an older upstream AE.

This creates or updates **`./.ae_hub`** under the repo root (`LIVE_EDIT_AE_HUB` overrides). The directory is **gitignored** (see root `.gitignore`).

## Inspect packs

With the AE CLI on your PATH:

```bash
cd "${AE_ROOT}/agentic_executables_cli"
dart run bin/ae.dart know list --hub "${PWD}/../../mcp_flutter/.ae_hub"
dart run bin/ae.dart know show --name live_edit_contract --hub "${PWD}/../../mcp_flutter/.ae_hub"
```

(Use your real paths.)

## Optional: generate instructions with `--know`

Use AE’s `ae generate` or `ae instructions` with `--know live_edit_contract` (or another pack name) so lifecycle output is **domain-aware** — see AE’s `README.md` and `docs_site/docs/use/index.md` in the agentic_executables repo.

## Relationship to code

- **Authoritative tool strings** remain in **`flutter_live_edit_core`** (`LiveEditMcpToolNames`, `LiveEditRuntimeToolNames`).
- AE packs are **mirrors for agents and humans**, not a second source of truth.
