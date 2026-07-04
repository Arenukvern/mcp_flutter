# Flutter MCP Toolkit Quick Start

Use this page when you want the shortest route from a Flutter app to a live
agent feedback loop.

## Get Started

```bash
# 1. Install the binary and fmtk alias.
curl -fsSL https://raw.githubusercontent.com/Arenukvern/mcp_flutter/main/install.sh | bash

# 2. Add the toolkit to your Flutter app.
cd my-flutter-app
flutter-mcp-toolkit codegen-init   # adds mcp_toolkit + emits a main.dart snippet

# 3. Install skills and MCP config for your agent.
flutter-mcp-toolkit init claude-code   # or: cursor | codex | cline | agents-skills | all

# 4. Run the app in debug mode.
flutter run --debug
```

Then run `flutter-mcp-toolkit doctor --json` before VM-dependent automation.

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
- IntentCall consumer boundary: [docs/intentcall/README.md](docs/intentcall/README.md)

## Video Walkthroughs

- Dynamic tools registration: [https://www.youtube.com/watch?v=Qog3x2VcO98](https://www.youtube.com/watch?v=Qog3x2VcO98)
- Cursor setup walkthrough: [https://www.youtube.com/watch?v=pyDHaI81uts](https://www.youtube.com/watch?v=pyDHaI81uts)

## Legacy Notes

The old long-form quick-start content was intentionally split into focused docs pages to reduce duplication and make onboarding clearer for both humans and AI agents.

## v2.x to v3.0.0 Hard Cut

- **Migration guide:** [docs/start_here/migration_v2_to_v3.mdx](docs/start_here/migration_v2_to_v3.mdx) — `fmt_*` MCP tools, **`flutter-mcp-toolkit-server`**, **`mcpServers` key `flutter-mcp-toolkit`**, `validate-runtime` targeting.
- **MCPCallEntry migration:** [docs/start_here/migration_mcp_call_entry_to_agent_call_entry.md](docs/start_here/migration_mcp_call_entry_to_agent_call_entry.md) — `AgentCallEntry`, platform `codegen sync`, `init intentcall-platform`.
- **IntentCall consumer guide:** [docs/intentcall/README.md](docs/intentcall/README.md) — hosted package policy, consumer proof gates, and upstream ownership.
- Local validation gates: `steward probe --json --profile quick`, `make check-contracts`, and `make check-intentcall-hosted-consumer` for IntentCall consumption changes.
- Update parsers to read error descriptor fields from `error.descriptor`.
- Use safe write flags (`--check --diff --backup --no-overwrite`) for snapshot/bundle flows.
