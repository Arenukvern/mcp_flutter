# Configuration (Entry)

This root file is now a short entry point.

Canonical configuration docs live in MDX:

- Full MCP + CLI flags and connection contracts: [docs/core/mcp_configuration.mdx](docs/core/mcp_configuration.mdx)
- Error envelope + code contract: [docs/core/error_code_playbook.mdx](docs/core/error_code_playbook.mdx)
- CLI vs MCP decision guide: [docs/start_here/cli_vs_mcp.mdx](docs/start_here/cli_vs_mcp.mdx)
- CLI command recipes (CI + local): [docs/start_here/cli_quick_recipes.mdx](docs/start_here/cli_quick_recipes.mdx)
- AI-agent setup flow: [docs/ai_agents/execution_playbook.mdx](docs/ai_agents/execution_playbook.mdx)

## Why this changed

Configuration content was moved to audience-first docs to avoid duplication and keep one source of truth.

For v3 automation safety:

- Run `flutter_mcp_cli doctor --json` before VM-dependent workflows.
- Use safe write flags on snapshot/bundle commands:
  `--check`, `--diff`, `--backup`, `--no-overwrite`.
