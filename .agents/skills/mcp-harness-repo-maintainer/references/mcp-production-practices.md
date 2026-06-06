# MCP production practices (reference)

Synthesis from [Model Context Protocol](https://modelcontextprotocol.io/), field guides (2025–2026), and production repository operational lessons. Apply to **archetype A** and any remote HTTP MCP.

## Design

| Topic | Practice |
|-------|----------|
| **Resources vs tools** | Resources = read-only URIs; tools = actions. Do not overload one for the other. |
| **Tool catalog** | Treat schemas as a **public API**—additive changes, explicit `version`, stable names (e.g., standard tool name prefixes). |
| **Long operations** | Return job id immediately; expose progress via resource or polling tool. |
| **Community vs custom** | Generic servers (filesystem, git) for horizontal ops; **your** domain in **your** server—never patch community servers with private endpoints. |
| **CLI parity** | MCP tools call **core**; CLI subcommands call the **same core** for CI (e.g. `doctor`, `validate-runtime` on product repos; `steward validate` on Skill Steward). Adapters stay thin. |

## Transport

| Mode | Use when |
|------|----------|
| **stdio** | Local IDE agents, single-user, OS manages process lifecycle |
| **Streamable HTTP** | Remote/shared, horizontal scale, gateway in front |
| **Auth (HTTP)** | OAuth 2.1 + PKCE; Protected Resource Metadata (RFC 9728); Resource Indicators (RFC 8707) |
| **Token passthrough** | **Forbidden**—server obtains its own upstream token |

## Operations

- Structured logs: `tool_name`, `duration_ms`, `status` (stdio → stderr).
- OpenTelemetry / GenAI MCP attributes where available.
- Per-tool rate limits and timeouts at transport boundary.
- Supply chain: pin MCP server deps; review new tools like new API routes (CSA agentic MCP guidance).

## Enterprise fleet

When many MCP servers:

```text
Agent → MCP Gateway → { server A, server B, … }
         ↑ auth, audit, policy, PII filter
```

Gateway owns token brokering and namespace routing; agents see one surface.

## Agent legibility (harness)

- If it is not in git, it does not exist for the agent.
- Error messages must say **how to fix** (next command, doc link, schema field).
- Hooks/plugins for IDE events; skills for procedures—see Skill Steward ADR 0004.

## Sources (verify periodically)

- https://modelcontextprotocol.io/
- https://www.developersdigest.tech/blog/model-context-protocol-mcp-server-guide
- https://jacar.es/en/mcp-guia-completa-2026/
- https://labs.cloudsecurityalliance.org/agentic/agentic-mcp-security-best-practices-v1/
