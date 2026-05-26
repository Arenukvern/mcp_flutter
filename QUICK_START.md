# MCP Flutter Quick Start

This repository now uses audience-first docs.

## Choose Your Path

- One-command binary install (macOS/Linux): `curl -fsSL https://raw.githubusercontent.com/Arenukvern/mcp_flutter/main/install.sh | bash`
- Human setup (manual): [docs/ai_agents/execution_playbook.mdx](docs/ai_agents/execution_playbook.mdx)
- Human client config: [docs/ai_agents/execution_playbook.mdx](docs/ai_agents/execution_playbook.mdx)
- AI-assisted setup: [docs/ai_agents/overview.mdx](docs/ai_agents/overview.mdx) (`flutter-mcp-toolkit init` or `npx skills add Arenukvern/mcp_flutter`)
- AI agent runbook: [docs/ai_agents/execution_playbook.mdx](docs/ai_agents/execution_playbook.mdx)

## Understand The Architecture First

- Why this repo matters: [docs/start_here/why_this_repo_matters.mdx](docs/start_here/why_this_repo_matters.mdx)
- Feature map: [docs/start_here/feature_map.mdx](docs/start_here/feature_map.mdx)
- CLI vs MCP (what to use when): [docs/start_here/cli_vs_mcp.mdx](docs/start_here/cli_vs_mcp.mdx)

## Video Walkthroughs

- Dynamic tools registration: [https://www.youtube.com/watch?v=Qog3x2VcO98](https://www.youtube.com/watch?v=Qog3x2VcO98)
- Cursor setup walkthrough: [https://www.youtube.com/watch?v=pyDHaI81uts](https://www.youtube.com/watch?v=pyDHaI81uts)

## Legacy Notes

The old long-form quick-start content was intentionally split into focused docs pages to reduce duplication and make onboarding clearer for both humans and AI agents.

## v2.x to v3.0.0 Hard Cut

- **Migration guide:** [docs/start_here/migration_v2_to_v3.mdx](docs/start_here/migration_v2_to_v3.mdx) — `fmt_*` MCP tools, **`flutter-mcp-toolkit-server`**, **`mcpServers` key `flutter-mcp-toolkit`**, `validate-runtime` targeting.
- **Agentkit Phase 6:** [docs/start_here/migration_agentkit_phase6.md](docs/start_here/migration_agentkit_phase6.md) — `AgentCallEntry`, platform `codegen sync`, `init agentkit-platform`.
- Run preflight before VM-dependent automation: `flutter-mcp-toolkit doctor --json`.
- Update parsers to read error descriptor fields from `error.descriptor`.
- Use safe write flags (`--check --diff --backup --no-overwrite`) for snapshot/bundle flows.
