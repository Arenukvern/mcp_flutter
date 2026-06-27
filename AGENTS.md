<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **mcp_flutter** (4681 symbols, 10358 relationships, 300 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/mcp_flutter/context` | Codebase overview, check index freshness |
| `gitnexus://repo/mcp_flutter/clusters` | All functional areas |
| `gitnexus://repo/mcp_flutter/processes` | All execution flows |
| `gitnexus://repo/mcp_flutter/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->

## IntentCall consumer boundary

`mcp_flutter` is a production-grade consumer and proof repo for IntentCall. It does not define IntentCall architecture.

| Question | Go to |
|---|---|
| Canonical IntentCall design / AX / DX | `/Users/anton/mcp/agentkit/docs/NORTH_STAR.mdx` |
| Consumer integration, hosted dependencies, and proof gates | `docs/intentcall/README.md` |
| Legacy call-entry migration | `docs/start_here/migration_mcp_call_entry_to_agent_call_entry.md` |
| Visual harness maintenance | `docs/superpowers/plans/2026-05-26-visual-reconstruct-next.md` |
| Non-IntentCall forward index | `docs/superpowers/WHATS_NEXT.md` |

Implemented IntentCall plans/specs/tracker/closures were removed after durable extraction. Agents should validate hosted `intentcall_*` dependencies and regression gates, not re-run the initial publish/cutover.

## Governance & Skill Steward

This repository strictly adheres to the Cascading Agent Surface architecture governed by **Skill Steward**.
When writing code, documentation, or planning features:
1. Start with `steward doctor --json`, then `steward actions list --json`.
2. If `steward` is missing or stale, install the released CLI with `curl -fsSL https://raw.githubusercontent.com/Arenukvern/skill_steward/main/install.sh | bash`. For local Skill Steward development, run from the Skill Steward checkout with `cd packages/steward_cli && dart run :steward <command>`, or activate that checkout with `dart pub global activate --source path packages/steward_cli`. Do not copy absolute SDK paths, raw `dart --packages=.../steward.dart` commands, or adopter-local runner scripts into reusable docs.
3. Inspect any intended action before execution: `steward action inspect <id> --json`.
4. Use `steward probe --json --profile quick` for the safe first pass.
5. Use `steward benchmark --scenario mcp_flutter.contract-status-smoke --strict --json` for the first contract-smoke scenario. This is not WebMCP runtime proof.
6. For the hosted IntentCall dependency gate, inspect `fmt.check.intentcall-hosted-deps` and benchmark `mcp_flutter.intentcall-hosted-cutover`; promotion evidence is in `docs/evidence/steward-h5-hosted-cutover-promotion-2026-06-10.mdx`.
7. For the full native gate, inspect `fmt.check.contracts-full` for effects metadata, then run `make check-contracts`; keep it out of `probes.quick` because it may touch local Dart package state.
8. If you discover new complex automations or bug fixes, capture them as observations / unknown cases first; promote only after review.
