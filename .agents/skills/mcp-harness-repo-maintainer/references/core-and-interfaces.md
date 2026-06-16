# Core vs interfaces (reference)

**Canonical pattern for the `<workspace>/` sibling family:** MCP and CLI are **thin agent-facing interfaces** (APIs). **Core** holds domain logic, schemas, and orchestration. Adapters translate; they do not own business rules.

## Layer diagram

```text
                    ┌─────────────────────────────────────┐
  Human / CI        │  CLI (thin)                         │
  ───────────────►  │  doctor, validate, init, exec, …    │
                    └──────────────┬──────────────────────┘
                                   │ same catalog / schemas
                    ┌──────────────▼──────────────────────┐
  Agent in chat     │  MCP (thin)                         │
  ───────────────►  │  tools, resources, prompts          │
                    └──────────────┬──────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────┐
                    │  Core (thick)                       │
                    │  • domain logic & invariants        │
                    │  • schema / contract validation     │
                    │  • registries (tools, capabilities) │
                    │  • shared models & platform libs    │
                    └──────────────┬──────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────┐
                    │  Runtime / IO                       │
                    │  VM Service, FS, HTTP, subprocess, …  │
                    └─────────────────────────────────────┘
```

## Responsibilities

| Layer | Responsibility | Must not |
|-------|----------------|----------|
| **CLI** | Parse argv; stable flags; `--json` for agents/CI; exit codes; call core | Embed domain rules only here |
| **MCP** | Map tool/resource names to core; structured errors; auth at transport | Duplicate logic missing from CLI path |
| **Core** | Single implementation of each capability; testable without MCP or TTY | Know about Cursor vs Codex UI |
| **Runtime** | IO and process boundaries | Leak into tool descriptions |

## Parity rule

> If a capability exists for agents (MCP tool), CI and scripts must reach the **same core entrypoint** via CLI (or a shared library called by both).

Divergence is a **bug**. New feature workflow:

1. Implement in **core** (with unit tests).
2. Expose **CLI** subcommand (for validation tasks, doctor, CI).
3. Register **MCP** tool (or resource) with identical semantics and error shapes.
4. Document once in skills/docs; reference both surfaces.

## Example Sibling Repo Layout Mapping

| Archetype Role | Repo Folder | CLI (thin) | MCP (thin) | Core (thick) |
|----------------|-------------|------------|------------|--------------|
| **Plugin/MCP** | `<plugin_repo>` | `toolkit-cli doctor` / `run` | `capability_tools` | `core` library & capability modules |
| **Library** | `<library_repo>` | library CLI wrapper | wire protocol adapter module | platform API logic and validations |
| **Harness/CLI** | `<harness_repo>` | runner CLI | (none—by design) | harness engine and app registry |
| **Visual Sidecar**| `<visual_sidecar>` | diff / comparison CLI | (none—by design) | visual verdict/profile pipeline |
| **Meta/Governance** | `<meta_governance_repo>` | validator CLI | (optional index tool) | validator rules package |

Repos without MCP still use the **CLI → core** split; MCP is optional second adapter.

## Platform SDK / Library pattern

```text
[platform]_schema   → contracts / schema validation
[platform]_core     → registry, invocation, domain types
[platform]_mcp      → MCP wire adapter only
CLI                 → command router / catalog → [platform]_core
```

## Anti-patterns

- Fat MCP tool handler with 200 lines and no shared core function
- CLI `doctor` that checks different things than MCP equivalent tool
- Copy-paste between CLI entrypoint scripts (e.g. `bin/main.js` or `bin/*.dart`) and MCP server code instead of one `core` call
- Putting “how to fix” strings only in MCP JSON—not in CLI stderr for CI

## Guild (meta)

Guild’s **product** is skills/docs, not a domain core—but the same shape applies:

- **Core:** validation rules (e.g., steward CLI validator, schemas)
- **CLI:** validator CLI wrapper commands (e.g. `steward validate`)
- **MCP:** future skill-index server—thin over same validators

Do not put marketplace or harness **philosophy** in CLI code; keep it in skills and ADRs.
