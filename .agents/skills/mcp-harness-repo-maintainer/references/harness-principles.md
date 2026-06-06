# Harness engineering — distilled principles

Source: [Harness engineering: leveraging Codex in an agent-first world](https://openai.com/index/harness-engineering/) (OpenAI, Feb 2026).

## Human vs agent roles

- **Humans:** environments, intent, feedback loops, review harness shape
- **Agents:** implementation, tests, CI config, docs, tooling—inside enforced boundaries

## When agents fail

Ask: *What capability is missing, and how do we make it legible and enforceable?*  
Not: assign blame or add vague prompt text.

## Documentation

- `AGENTS.md` = **map** (~100 lines), pointers to `docs/`
- Structured `docs/`: design index, architecture map, quality grades; **plans are ephemeral** (any tool)—extract to ADRs/FAQs/code, then remove
- Mechanical doc hygiene: linters, doc-gardening agents, cross-links
- **Agent legibility:** if it is not in the repo, it does not exist for the agent

## Architecture

- Strict layers and dependency rules; enforced by generated/custom linters
- Taste invariants (logging shape, file size, naming) in lint messages → remediation hints for agents
- Boundaries central; freedom local within layers

## Runtime legibility (product repos)

- Per-worktree app instances
- DOM/screenshots via CDP skills
- Ephemeral observability (logs/metrics) queryable by agent (LogQL/PromQL-style)

## Implication for Guild

Skill Steward ships **meta-harness** (skills, validation, doc patterns)—not product CLIs. Product harnesses and SDKs live in their respective repositories; this skill teaches how to build and document them.
