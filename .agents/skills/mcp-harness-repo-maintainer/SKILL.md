---
name: mcp-harness-repo-maintainer
description: Maintains MCP-and-harness repositories where CLI and MCP are thin agent-facing interfaces and core libraries hold domain logic. Develops agent-first engineering culture via shared contracts, mechanical gates, and in-repo docs. Use when refactoring adapters, enforcing CLI/MCP/core parity, building agentic tooling, or maintaining sibling repo layout.
license: MIT
type: governance
metadata:
  author: skill-steward
  version: "1.2.0"
  category: harness
paths:
  - "AGENTS.md"
  - "docs/**"
  - "plugin/**"
  - "packages/**"
  - "src/**"
  - "mcp_server_*/**"
  - "Makefile"
  - "makefile"
  - "Justfile"
  - "justfile"
  - "package.json"
  - "Cargo.toml"
  - "pyproject.toml"
  - "pubspec.yaml"
  - "**/mcp.json"
  - "**/mcp*.json"
  - ".github/workflows/**"
  - "tool/**"
  - "scripts/**"
---

# MCP & Harness Repo Maintainer (Architecture & Culture)

Build and maintain **agent-first repos** where agents execute and humans steer. Avoid copying the wrong shape into the wrong repo.

## Core principle (all archetypes)

**MCP and CLI are thin interfaces—APIs for agents and CI.** **Core** contains the real logic, schemas, and registries. Adapters parse wire format (argv, MCP JSON-RPC); they delegate immediately.

```text
Agents / CI  →  CLI ──┐
                      ├──► Core (logic, contracts, tests)
Agents / chat →  MCP ──┘
```

Full layering: [core-and-interfaces.md](references/core-and-interfaces.md). **Parity:** every MCP tool must call the same core entrypoint as its CLI twin.

## Core Beliefs & Culture

1. **Missing capability → harness gap** — When an agent fails, ask what is not *legible* or *enforceable*, then add CLI command, MCP tool, linter, or skill.
2. **Ambiguous design → decision checkpoint** — Before coding a fork, use `adr-records` layer 0; record `accepted` ADR after agreement.
3. **Mechanical enforcement** — Linters, validate commands, schema validation at boundaries—error messages teach the agent how to fix. Use structured parsing (YAML, JSON, or AST).
4. **Progressive disclosure** — Router → ADR / DESIGN_FAQ (why) → DX_FAQ (how) → skills (procedures) → code (behavior SSOT).

## Harness Layers to Build

```text
Human intent (prompt, plan, review)
        │
        ▼
┌───────────────────┐
│ Skills + AGENTS   │  Map & procedures (when to do what)
└─────────┬─────────┘
          ▼
┌───────────────────┐
│ CLI               │  doctor, exec, validate, contracts (deterministic)
└─────────┬─────────┘
          ▼
┌───────────────────┐
│ MCP server        │  fmt_* / tools for chat agents (same schemas)
└─────────┬─────────┘
          ▼
┌───────────────────┐
│ App / runtime     │  Legible UI, logs, metrics per worktree (optional)
└───────────────────┘
```

## Mixture of experts (pick one lead)

Route by **primary artifact**:

| Expert lens | Repo examples | Owns | Does not own |
|-------------|---------------|------|----------------|
| **A — Product MCP** | `<custom_mcp>` | `plugin/mcp.json`, tool prefixing, init utility | Harness scripts, visual comparisons |
| **B — Platform libs** | `<platform_libs>` | Platform packages/modules, adapters | Shippable plugin tree, dogfood apps |
| **C — CLI harness** | `<cli_harness>` | Harness engine, app registry, fixture lint | MCP server binary, marketplace manifests |
| **D — Visual sidecar** | `<visual_sidecar>` | Profile configs, compare/deconstruct CLI | VM/MCP, dynamic registry |
| **E — Meta steward** | `skill_steward` | `skills/`, `plugins/`, validator CLI, docs | Product MCP, domain tools |
| **F — Security/Ops** | all remotes | OAuth gateway, token brokering | Feature code |

## Universal maintainer spine (every archetype)

1. **Charter & Archetype** — `docs/NORTH_STAR.mdx` (or root pointer); `AGENTS.md` = map only.
2. **Behavior SSOT** — code + schemas; docs hold **why** and **how**.
3. **Thin adapters, thick core** — implement once in core; CLI + MCP are wrappers.
4. **Mechanical gates** — contract checks / validate commands / unit tests before merge.
5. **Plan hygiene** — extract to ADR/FAQ/code/skill then **delete** plan files.
6. **Version honesty** — single `VERSION` or release-please manifest.
7. **Distribution** — document per channel: `npx skills`, `init <agent>`, git marketplace.

## Workflow: Add Agent-First Capability

1. **Specify intent** — One sentence outcome + acceptance check.
2. **Choose surface**
   - CI / script / gate → **CLI** first
   - Conversational debug loop → **MCP tool** (reuse CLI core)
   - One-off guidance → **skill** in `skills/`
   - Event enforcement → **plugin** hook
3. **Make legible** — JSON schema, `--json` output, stable error codes; document in DX_FAQ.
4. **Document why** — ADR or DESIGN_FAQ Q&A.
5. **Wire map** — `AGENTS.md` / `docs_map` row.
6. **Validate** — `pnpm run validate` or project contract tests.
7. **Human collab** — PR describes harness change.

## Archetypes Details

- **Archetype A (Product MCP):** `plugin/` is SSOT. Ship a **custom** server, do not patch community servers for product logic.
- **Archetype B (Platform Libs):** Core modules + wire protocol adapters only; no domain forks.
- **Archetype C (CLI Harness):** No MCP. Depends on product MCP core modules.
- **Archetype D (Visual sidecar):** No MCP. SSOT: `profiles/*.yaml`.
- **Archetype E (Meta Steward):** Core validators, thin CLI check. No `mcp.json`.
- **Archetype F (Production MCP):** Resources for read-only; tools for mutation. Return job IDs for long tasks. Use OAuth.

## Sibling layout

```text
<workspace>/
  <product_mcp>/               # A — toolkit + MCP + init
  <platform_libs>/             # B — SDK platform
  <cli_harness>/               # C — CLI/Harness runner
  <visual_sidecar>/            # D — comparison sidecar
  <meta_steward>/              # E — meta skills & validation
```

## Checklist before claiming “harness ready”

- [ ] Agent can discover what to run from in-repo docs alone
- [ ] CLI command exists for CI/gates (or documented why not)
- [ ] MCP tool shares schema/validation with CLI
- [ ] Failure messages say how to remediate
- [ ] Design forks were checkpointed (`adr-records`)
- [ ] Contract gate (validation scripts) pass

## Install

```bash
npx skills add arenukvern/skill_steward --skill mcp-harness-repo-maintainer
```

## References

- [core-and-interfaces.md](references/core-and-interfaces.md)
- [repo-archetypes.md](references/repo-archetypes.md)
- [maintainer-checklists.md](references/maintainer-checklists.md)
- [mcp-production-practices.md](references/mcp-production-practices.md)
- [sibling-layout.md](references/sibling-layout.md)
- [harness-principles.md](references/harness-principles.md)
- [cli-mcp-pattern.md](references/cli-mcp-pattern.md)
- [steward-composition.md](references/steward-composition.md)
- [preferred-tooling.md](references/preferred-tooling.md)

## Sources

See [references/sources.md](references/sources.md). When researching, follow `skill-source-citations`.
