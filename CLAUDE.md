# mcp_flutter — Claude Code Context

MCP server + Flutter toolkit that lets AI assistants inspect and interact with
Flutter apps via the Dart VM Service. Dart-based server with dynamic tools
registration from the Flutter app side.

See `ARCHITECTURE.md` for the full system overview and `docs/ai_agents/execution_playbook.mdx`
for the AI-agent runbook.

## Repository Layout (monorepo)

- `mcp_server_dart/` — MCP server + `flutter-mcp-toolkit` binary. Primary build target.
- `mcp_toolkit/mcp_toolkit/` — Dart package integrated into Flutter apps; registers
  VM service extensions (`ext.mcp.toolkit.*`) and supports dynamic tool registration.
- `flutter_test_app/` — Showcase/example Flutter app used for e2e testing.
- `mcp_capability_kernel/` — kernel contracts (Capability, ToolRegistration, CapabilityContext, host-service registry).
- `mcp_capability_core/` — the `fmt` capability (class `CoreCapability`, MCP id `fmt`) — all 27 + 4-dump MCP tools.
- `mcp_shared_core/` — pure-Dart command catalog + connection-override types shared by server, CLI, and capability_core.
- `maestro/`, `tool/contracts/`, `tool/release/` — test flows, contract checks, release scripts.
- `docs/` — audience-first MDX docs (humans + AI agents).
- `todo/` — planning + design docs for in-flight work and deferred follow-ups.

## Commands

```bash
make install              # cd mcp_server_dart && make setup (pub get + deps)
make build                # compile mcp_server_dart binaries to build/
make showcase             # run flutter_test_app on macOS, print VM URI (blocks)
make check-contracts      # SDK parity + error code + docs drift checks
make inspect              # launch MCP inspector against built server
```

Per-package: `cd mcp_server_dart && make compile` produces
`build/flutter-mcp-toolkit-server` and `build/flutter-mcp-toolkit`.

### Tests

```bash
cd mcp_server_dart                       && flutter test
cd mcp_toolkit/mcp_toolkit               && flutter test
cd mcp_capability_kernel                 && dart test
cd mcp_capability_core                   && dart test
cd mcp_shared_core                       && dart test
```

Each package must be `cd`'d into — tests run per-package, not repo-wide.
Run one test by name: `flutter test path/to/x_test.dart --plain-name "exact name"`
(`--plain-name` flags combine with AND, so pass only one at a time).

## v3.0 Gotchas (non-obvious)

- **MCP tool names are prefixed.** The capability kernel is the only
  registration path; every MCP tool surfaces as `fmt_<name>`
  (e.g. `fmt_tap_widget`, `fmt_hot_reload_and_capture`). Legacy
  unprefixed names return `tool_not_found`. The dynamic-registry host
  trio (`listClientToolsAndResources`, `runClientTool`,
  `runClientResource`) stays unprefixed. CLI catalog names are unchanged
  (`flutter-mcp-toolkit exec --name <unprefixed>`). Locked surface lives in
  `tool/contracts/expected_tool_surface.txt`.
- **Preflight first**: run `flutter-mcp-toolkit doctor --json` before any VM-dependent
  automation — parses env, ports, and app reachability. Binary is
  `mcp_server_dart/build/flutter-mcp-toolkit` after `make build`.
- **Safe-write flags** on snapshot/bundle commands: `--check --diff --backup --no-overwrite`
  (atomic write/publish). Don't skip these in automation.
- **Error envelope contract**: errors are `{code, message, details, descriptor, recovery}`.
  Read `error.descriptor` (not top-level) when parsing.
- **Strict schemas**: `additionalProperties: false` by default — unknown params reject.
- **Dump RPCs disabled** by default (token cost); opt in with `--dumps`.
- **`uses-material-design` warnings** when running tests in `mcp_server_dart` come from
  transitive Flutter deps (`mcp_toolkit`) — benign, ignore.

## Connection model

- VM Service port defaults to **8181** (override: `--dart-vm-port`).
- MCP transport is **stdio** — no inbound network port.
- Target app must run in **debug mode**; `mcp_toolkit` must be initialized.

## Conventions

- Dart formatting via `dart format`; analysis via per-package `analysis_options.yaml`.
- Commit style: imperative mood (see `git log`).
- Don't edit `dist/` or `build/` — generated.
- `.clinerules` is for Cline's memory bank workflow; not authoritative for Claude.

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **mcp_flutter** (7707 symbols, 17980 relationships, 300 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

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
