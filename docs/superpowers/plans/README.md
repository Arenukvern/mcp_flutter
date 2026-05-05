# v3.0.0 Implementation Plans

Four sub-plans implementing [the v3.0.0 plugin design spec](../specs/2026-04-29-flutter-mcp-toolkit-plugin-design.md).

## Wave structure

```
Wave 1 (parallel):  Plan A ───────────────┐
                    Plan C ─┐             │
                            │             │
Wave 2:                     │     Plan B  ┤   (B needs A)
                            │             │
Wave 3:                     └─┬───────────┘
                              │
                              └──── Plan D   (D needs A + B + C)
```

| Plan | File | Tasks | Wave |
|---|---|---|---|
| **A — Skill Bundle Infra** | [2026-04-29-plan-a-skill-bundle-infra.md](2026-04-29-plan-a-skill-bundle-infra.md) | 16 | 1 |
| **B — CLI Commands** | [2026-04-29-plan-b-cli-commands.md](2026-04-29-plan-b-cli-commands.md) | 14 | 2 |
| **C — Renames** | [2026-04-29-plan-c-renames.md](2026-04-29-plan-c-renames.md) | 13 | 1 |
| **D — Docs Migration** | [2026-04-29-plan-d-docs-migration.md](2026-04-29-plan-d-docs-migration.md) | 13 | 3 |

**Total: ~56 tasks across 4 plans.**

## Why this split

Each plan ends in working, testable software:

- **Plan A** ships a usable plugin source tree + bundled skill assets (manual install path works).
- **Plan B** ships `init` + `codegen-init` (one-command install for any agent).
- **Plan C** ships the renamed surface (binaries + tool prefix `fmt_`).
- **Plan D** ships docs that match reality (READMe + nav).

Plans A and C have no overlap — true parallel-safe. Plan B consumes Plan A's `SkillAssets`. Plan D references all three.

## Execution

Recommended: dispatch a fresh subagent per task per plan. Plans A and C run concurrently; Plan B starts when Plan A hits Task 12 (the asset bundle); Plan D starts when all three Wave 1+2 plans land.

See each plan file for the full TDD-discipline task breakdown.
