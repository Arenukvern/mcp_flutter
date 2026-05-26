# Agentkit in-repo product gate — complete (Phase 8)

> **Product code gate** (2026-05-26). **Integration hardening** (CI parity, doc sync, runtime
> re-verify) complete — archived [integration completion plan](../plans/archive/2026-05-26-agentkit-integration-completion-next.md). **Forward:** [WHATS_NEXT](../WHATS_NEXT.md) · [Phase 7 extract](../plans/2026-05-27-agentkit-phase7-extract.md).
> **Paths:** file paths below are pre-Phase-7; live packages are under `agentkit/packages/`.

**Date:** 2026-05-26  
**Verdict:** pass  
**Branch:** `feat/agentkit-phase1-3`  
**Appends:** [2026-05-26-agentkit-integration-complete.md](./2026-05-26-agentkit-integration-complete.md) (does not rename prior closures).

## Scope

In-repo **product** completion inside `mcp_flutter` (no monorepo extract, no pub.dev): platform init CLI, thin invoke plugin, operator MCP migrate tool, CI codegen drift gate, Client DX testing, discoverability.

**Out of scope:** Phase 7 extract, Gemma product wiring, HarmonyOS, second `@AgentTool` codegen tool (pilot-only documented).

## Workstreams

| ID | Result |
|----|--------|
| A — Platform productization | pass — `init agentkit-platform` + `--check`; `agentkit_platform` plugin + `AgentkitInvokeLinkListener`; manifest workflow documented; ADR 0008 web invoke JS-only |
| B — Operator & codegen | pass — `fmt_migrate_agent_entries`; codegen pilot docs in `server_capability_core/README` |
| C — Testing & contracts | pass — `agentkit_testing` ecsly-style envelope test; e2e tool count 29/33 |
| D — API surface & release | pass — `mcp_toolkit.dart` public surface documented; CHANGELOG Unreleased; README + QUICK_START migration links |
| E — Program hygiene | pass — tracker `complete_in_repo_product`; validation appendix below |

## Validation appendix

| Command | Result |
|---------|--------|
| `dart test packages/agentkit_* packages/server_capability_*` | pass |
| `cd mcp_toolkit && flutter test` | pass (run at gate) |
| `cd mcp_server_dart && dart test` | pass |
| `cd mcp_server_dart && dart test test/contract/` | pass (run at gate) |
| `make check-contracts` | pass (includes `codegen sync --check` on `flutter_test_app`) |
| `bash tool/contracts/check_agentkit_skills_grep.sh` | pass |
| `dart run … migrate agent-entries --check flutter_test_app/lib` | pass |
| `dart run … init agentkit-platform --check --project-dir flutter_test_app` | pass |
| `dart run … codegen sync --platform web,android,ios,macos,linux,windows --project-dir flutter_test_app --check` | pass |
| macOS `validate-runtime` (showcase) | run at gate — prior integration pass; re-run before merge if showcase touched |
| Web `validate-runtime` chrome | run at gate — prior integration pass |

## Key deliverables

- `packages/agentkit_platform/lib/src/init/platform_hooks_init.dart`
- `mcp_server_dart/lib/src/cli/init_agentkit_platform_command.dart`
- `packages/agentkit_platform` Flutter plugin + `agentkit_platform_flutter.dart`
- `packages/agentkit_core/lib/src/migrate_agent_entries.dart` + `fmt_migrate_agent_entries`
- `decisions/0008_web_agent_invoke_js_only.mdx`
- `flutter_test_app/AGENTKIT_PLATFORM.md` updated

## Deferred (Phase 7 only)

- Standalone agentkit monorepo extract
- `generateWebAgentManifest` wired from live registry (manual `web/agent_manifest.json` + `codegen sync`)
- Second `@AgentTool` server tool beyond pilot
- Gemma product wiring, HarmonyOS
