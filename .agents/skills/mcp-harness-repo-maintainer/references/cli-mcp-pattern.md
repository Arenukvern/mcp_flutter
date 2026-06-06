# CLI + MCP pattern

## Thin interfaces, thick core

**CLI** and **MCP** are not where logic lives—they are **APIs for agents** (and CI). **Core** libraries implement behavior once; adapters only marshal I/O.

```text
CLI  ──┐
       ├──► Core (logic, schemas, tests)
MCP  ──┘
```

Skill Steward reference: [mcp-harness-repo-maintainer — core-and-interfaces.md](https://github.com/arenukvern/skill_steward/blob/main/skills/mcp-harness-repo-maintainer/references/core-and-interfaces.md).

## Why both surfaces

| Surface | Best for |
|---------|----------|
| **CLI** | CI, Make targets, snapshots, `doctor --json`, contract gates, non-interactive automation |
| **MCP** | Cursor, Codex, Claude—tool calls inside conversation |

Same **core entrypoints** and **schema validation**; only wire format differs.

## Platform SDK layering

```text
[platform]_schema   → wire types, validateAgainstSchema (Tier A)
[platform]_core     → entry points, registry, direct invocation
[platform]_mcp      → MCP adapter
CLI exec            → CommandCatalog + same schema factories
app dynamics        → VM extensions / WebMCP
```

**Rule:** New interaction → shared schema factory → register CLI + MCP + app path together.

## Preflight pattern

```bash
toolkit-cli doctor --json
toolkit-cli get_extension_rpcs
# then exec or MCP tools
```

Agents should run doctor-style commands before expensive debug loops.

## Guild analogue

| Product | Skill Steward meta |
|---------|------------|
| `toolkit-cli validate-runtime` | `pnpm run validate` (skills) |
| `make check-contracts` | CI `validate-skills.yml` |
| `custom_mcp` tools | `npx skills` + skills in repo |
| Platform contract tables | `docs/STANDARDS.mdx`, skill-authoring-lifecycle |

When bootstrapping a new product harness, copy the **shape**, not specific framework command names.
