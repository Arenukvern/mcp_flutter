<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **mcp_flutter** (3749 symbols, 8525 relationships, 299 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## When Debugging

1. `gitnexus_query({query: "<error or symptom>"})` — find execution flows related to the issue
2. `gitnexus_context({name: "<suspect function>"})` — see all callers, callees, and process participation
3. `READ gitnexus://repo/mcp_flutter/process/{processName}` — trace the full execution flow step by step
4. For regressions: `gitnexus_detect_changes({scope: "compare", base_ref: "main"})` — see what your branch changed

## When Refactoring

- **Renaming**: MUST use `gitnexus_rename({symbol_name: "old", new_name: "new", dry_run: true})` first. Review the preview — graph edits are safe, text_search edits need manual review. Then run with `dry_run: false`.
- **Extracting/Splitting**: MUST run `gitnexus_context({name: "target"})` to see all incoming/outgoing refs, then `gitnexus_impact({target: "target", direction: "upstream"})` to find all external callers before moving code.
- After any refactor: run `gitnexus_detect_changes({scope: "all"})` to verify only expected files changed.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Tools Quick Reference

| Tool | When to use | Command |
|------|-------------|---------|
| `query` | Find code by concept | `gitnexus_query({query: "auth validation"})` |
| `context` | 360-degree view of one symbol | `gitnexus_context({name: "validateUser"})` |
| `impact` | Blast radius before editing | `gitnexus_impact({target: "X", direction: "upstream"})` |
| `detect_changes` | Pre-commit scope check | `gitnexus_detect_changes({scope: "staged"})` |
| `rename` | Safe multi-file rename | `gitnexus_rename({symbol_name: "old", new_name: "new", dry_run: true})` |
| `cypher` | Custom graph queries | `gitnexus_cypher({query: "MATCH ..."})` |

## Impact Risk Levels

| Depth | Meaning | Action |
|-------|---------|--------|
| d=1 | WILL BREAK — direct callers/importers | MUST update these |
| d=2 | LIKELY AFFECTED — indirect deps | Should test |
| d=3 | MAY NEED TESTING — transitive | Test if critical path |

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/mcp_flutter/context` | Codebase overview, check index freshness |
| `gitnexus://repo/mcp_flutter/clusters` | All functional areas |
| `gitnexus://repo/mcp_flutter/processes` | All execution flows |
| `gitnexus://repo/mcp_flutter/process/{name}` | Step-by-step execution trace |

## Self-Check Before Finishing

Before completing any code modification task, verify:
1. `gitnexus_impact` was run for all modified symbols
2. No HIGH/CRITICAL risk warnings were ignored
3. `gitnexus_detect_changes()` confirms changes match expected scope
4. All d=1 (WILL BREAK) dependents were updated

## Keeping the Index Fresh

After committing code changes, the GitNexus index becomes stale. Re-run analyze to update it:

```bash
npx gitnexus analyze
```

If the index previously included embeddings, preserve them by adding `--embeddings`:

```bash
npx gitnexus analyze --embeddings
```

To check whether embeddings exist, inspect `.gitnexus/meta.json` — the `stats.embeddings` field shows the count (0 means no embeddings). **Running analyze without `--embeddings` will delete any previously generated embeddings.**

> Claude Code users: A PostToolUse hook handles this automatically after `git commit` and `git merge`.

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

## intentcall program (spec-driven)

When implementing the **intentcall** migration, use the self-closing loop — do not mark phases complete without the Closer gate:

| Doc | Role |
|-----|------|
| `docs/superpowers/specs/2026-05-25-intentcall-design.md` | Source of truth |
| `docs/superpowers/plans/2026-05-25-intentcall-rollout.md` | Program overview |
| `docs/superpowers/tracker/intentcall-rollout.yaml` | Active phase + status |
| `docs/superpowers/intentcall-self-closing-loop.md` | Implementer + **Closer** protocol |
| `docs/superpowers/plans/2026-05-27-intentcall-phase7-extract.md` | Historical extract plan; do not re-execute publish/cutover steps |
| `docs/superpowers/plans/2026-05-26-visual-reconstruct-next.md` | Visual harness maintenance (checkpoint + optional runtime E2E) |
| `docs/superpowers/WHATS_NEXT.md` | Single-page forward index |
| `docs/superpowers/plans/archive/` | Historical phase plans — do not execute |

**Closer** verifies, writes `docs/superpowers/closure/`, regenerates the same phase plan on failure or the next phase plan on success. In-repo product gate is `complete_in_repo_product`; **Phase 7 extract/cutover is post-cutover**. Agents should validate hosted `intentcall_*` dependencies and regression gates, not re-run the initial publish/cutover.

## Governance & Skill Steward

This repository strictly adheres to the Cascading Agent Surface architecture governed by **Skill Steward**.
When writing code, documentation, or planning features:
1. Start with `steward doctor --json`, then `steward actions list --json`.
2. If the global `steward` binary is stale or lacks `doctor` / `actions` / `probe` / `benchmark`, use the adjacent checkout-local Skill Steward CLI: `dart --packages=../agent_guild/packages/steward_cli/.dart_tool/package_config.json ../agent_guild/packages/steward_cli/bin/steward.dart <command>`.
3. Inspect any intended action before execution: `steward action inspect <id> --json`.
4. Use `steward probe --json --profile quick` for the safe first pass.
5. Use `steward benchmark --scenario mcp_flutter.web-dogfood-warm --strict --json` for the first dogfood scenario.
6. If you discover new complex automations or bug fixes, capture them as observations / unknown cases first; promote only after review.
