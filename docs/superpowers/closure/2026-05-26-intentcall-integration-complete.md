# intentcall integration gate — complete in-repo (post Phase 6)

> **Historical snapshot** (2026-05-26). Platform init, plugin, and `fmt_migrate_agent_entries`
> shipped in [product closure](./2026-05-26-intentcall-product-complete-in-repo.md).
> Forward work: [WHATS_NEXT](../WHATS_NEXT.md) · [Phase 7 extract](../plans/2026-05-27-intentcall-phase7-extract.md). Integration hardening (archived): [integration completion plan](../plans/archive/2026-05-26-intentcall-integration-completion-next.md).

**Date:** 2026-05-26  
**Verdict:** pass  
**Branch:** `feat/intentcall-phase1-3`  
**Supersedes:** appends [2026-05-26-intentcall-program-complete-in-repo.md](./2026-05-26-intentcall-program-complete-in-repo.md) (Bar D); does not rename that file.

## Scope

Integration pass inside `mcp_flutter`: user-facing API truth (`AgentCallEntry`), CI doc gates, platform dogfood on `flutter_test_app`, `intentcall_testing` harness, validate-runtime capture policy alignment, web path C bootstrap via `mcp_toolkit`.

**Out of scope:** Phase 7 monorepo extract, pub.dev, `fmt_migrate_agent_entries` MCP tool, Gemma product wiring, HarmonyOS, `init intentcall-platform` CLI, `intentcall_platform` Flutter plugin.

## Workstreams

| ID | Result |
|----|--------|
| A — Documentation & API truth | pass — user-facing docs/plugin/skills grep gate; `MCPCallEntry` only in migration BEFORE + historical specs |
| B — Runtime E2E | pass — package + mcp_server_dart + mcp_toolkit tests; migrate `--check`; contracts (see appendix) |
| C — Platform integration | pass — `codegen sync` artifacts for web + native on `flutter_test_app`; web bootstrap in `mcp_toolkit`; `INTENTCALL_PLATFORM.md` hook doc |
| D — Testing | pass — `packages/intentcall_testing/test/entry_invoke_test.dart` |
| E — Operator | pass at integration time for CLI; MCP tool shipped in product gate (phase 8) |
| F — Program hygiene | pass at integration time — tracker milestone; archived phase6 task checkboxes were **not** updated (use tracker sub_phases 6a–6h) |

## Validation appendix

| Command | Result |
|---------|--------|
| `dart test packages/intentcall_* packages/server_capability_*` | pass |
| `cd mcp_toolkit && flutter test` | pass |
| `cd mcp_server_dart && dart test` | pass |
| `cd mcp_server_dart && dart test test/contract/` | pass |
| `bash tool/contracts/check_intentcall_skills_grep.sh` | pass |
| `dart run … migrate agent-entries --check flutter_test_app/lib` | pass |
| `dart run … codegen sync --platform web,android,ios,macos,linux,windows --project-dir flutter_test_app --check` | pass (after sync commit) |
| `make check-contracts` | pass after `skill_assets.g.dart` commit |
| macOS `validate-runtime` on showcase | pass — `ok: true`, `captureFallbackUsed: true`, `capturePlatformViewsDetected: true`, `captureBackend: macos_host` |
| Web `validate-runtime` on chrome | pass — `ok: true`, `capturePlatformViewsDetected: true`, `captureBackend: web_browser` |

## Key deliverables

- Extended `tool/contracts/check_intentcall_skills_grep.sh` + wired into `make check-contracts`
- ADR 0006 validate-runtime fallback matches code (`captureFallbackUsed` with platform views)
- `mcp_toolkit`: web `AgentWebMcpBootstrap.registerFromEntries` after `addEntries`
- Native platform artifacts under `flutter_test_app/` (shortcuts, Swift, linux desktop, windows reg)
- Archived `.cursor/skills/mcp_dynamic_tools.mdc` → plugin custom-tools skill

## Deferred (tracker)

- Standalone intentcall monorepo (phase7)
- `generateWebAgentManifest` pipeline from live registry (manifest maintained under `web/agent_manifest.json`)

## Superseded by product gate (2026-05-26)

See [2026-05-26-intentcall-product-complete-in-repo.md](./2026-05-26-intentcall-product-complete-in-repo.md): `init intentcall-platform`, `intentcall_platform` plugin + `app_links`, `fmt_migrate_agent_entries` MCP tool shipped.
