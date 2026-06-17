# Preferred Tooling for Agent Harnesses

This document captures the current recommended stack for building **CLI + MCP harnesses** in the `~/mcp` family of repositories (and similar agent-first tooling).

The goal is legibility for both humans and agents, strong mechanical gates, and long-term maintainability with minimal accidental complexity.

## Language Choices

| Layer                  | Preferred Choice          | Rationale / When to deviate |
|------------------------|---------------------------|-------------------------------|
| **Core domain logic**  | Language of the product (often Dart) or the strongest typed language on the team | Agents benefit enormously from static typing, good IDEs, and clear schemas. |
| **Harness CLI**        | **Dart**                  | Default for new harness CLIs. Excellent static analysis, fast startup for `doctor`/`validate` commands, great cross-platform binaries. Avoid introducing new raw Node/TypeScript/mjs CLIs for harness surfaces. |
| **MCP server**         | Same language as CLI/core | Thin adapter only. Never duplicate logic. |
| **Task runner**        | **Justfile**              | Highly readable for agents and humans. Excellent for `just doctor`, `just check`, `just build`, etc. Prefer over heavy `package.json` scripts or Makefiles when starting fresh. |
| **Validation / Linting** | Language-native + custom rules (Dart analyzer, etc.) | Make error messages actionable for agents ("run `just fix-lints`"). |

### Strong preference against

- New harness CLIs written primarily in JavaScript / TypeScript / mjs / raw Node (unless you are extending a very large existing Node codebase and the team has deep expertise).
- Using package.json scripts as the primary long-lived task runner for harness commands.
- Mixing too many languages in the harness layer itself (increases cognitive load for agents).

## Why Dart for Harness CLIs (2026)

- Fast, small, self-contained binaries (`dart compile exe`).
- Extremely strong static analysis and refactoring tools — agents love this.
- Excellent cross-platform behavior (the same binary works on macOS, Linux, Windows).
- Mature package ecosystem for CLI work (`args`, `path`, `io`, `process`, etc.).
- Consistent with the direction taken in production harnesses, SDKs, and the Skill Steward meta-harness itself (`steward` CLI).

## Task Runner Guidance

**Justfile** is currently the recommended default for new or refreshed harness repositories because:

- Extremely high signal-to-noise for agents reading the file.
- Simple, declarative, easy to make idempotent.
- Works the same whether the underlying language is Dart, Rust, Go, etc.
- Plays nicely with both human `just <command>` and agent tool calls.

You can still keep a thin `package.json` / `pubspec.yaml` / `Cargo.toml` for dependency management and language-specific scripts, but route the primary developer/agent experience through Just.

## How to Apply This in a New or Existing Repo

1. Install the relevant Skill Steward skills:
   ```bash
   npx skills add arenukvern/skill_steward -a cursor -a claude-code -y
   ```
   Prioritize: `repo-quality-system-lifecycle`, `repository-governance-lifecycle`, `mcp-harness-repo-maintainer`, `skill-authoring-lifecycle`, `skill-source-citations`.

2. When starting the CLI surface, default to Dart + Justfile unless you have a documented exception.

3. Record the decision (and any justified deviations) in your local `harness-principles.md` or equivalent, referencing this file.

4. Make the choice legible:
   - Document the primary entry points in `DX_FAQ.mdx` (or `.md`).
   - Add a "Preferred tooling" row or section in your architecture docs.
   - Ensure `doctor` / `validate` / `check` commands exist and are the recommended path.

## Exceptions

You may deviate when you have a **strong, documented reason**, for example:

- Deep existing investment in a high-quality TypeScript CLI framework + team expertise.
- The harness is a very thin wrapper around an existing heavy Node tool.
- The primary consumers are Node-heavy teams and the maintenance burden of another language is proven higher.

In these cases, still apply the other principles (thin interfaces, mechanical gates, excellent error messages, Justfile where possible, clear docs).

## Related Guidance

- [cli-mcp-pattern.md](cli-mcp-pattern.md) — Thin interfaces, shared core
- [harness-principles.md](harness-principles.md) — Overall philosophy
- [steward-composition.md](steward-composition.md) — Which Skill Steward skills to use when
- [mcp-harness-repo-maintainer — repo-archetypes](https://github.com/arenukvern/skill_steward/blob/main/skills/mcp-harness-repo-maintainer/references/repo-archetypes.md)

## Sources

See [references/sources.md](sources.md). When researching or evolving this guidance, follow `skill-source-citations`.
