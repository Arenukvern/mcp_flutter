# MCP Flutter Quick Start

This repository now uses audience-first docs.

## Choose Your Path

- One-command binary install (macOS/Linux): `curl -fsSL https://raw.githubusercontent.com/Arenukvern/mcp_flutter/main/install.sh | bash`
- Human setup (manual): [docs/getting_started/manual_installation.mdx](docs/getting_started/manual_installation.mdx)
- Human client config: [docs/getting_started/manual_client_setup.mdx](docs/getting_started/manual_client_setup.mdx)
- AI-assisted setup: [docs/getting_started/llm_install_files.mdx](docs/getting_started/llm_install_files.mdx)
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

- Run preflight before VM-dependent automation: `flutter_mcp_cli doctor --json`.
- Update parsers to read error descriptor fields from `error.descriptor`.
- Use safe write flags (`--check --diff --backup --no-overwrite`) for snapshot/bundle flows.
