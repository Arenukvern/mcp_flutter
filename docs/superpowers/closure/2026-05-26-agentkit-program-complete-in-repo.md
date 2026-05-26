# Agentkit program — complete in-repo (Phase 6 closure)

**Date:** 2026-05-26  
**Verdict:** pass  
**Branch:** `feat/agentkit-phase1-3`

## Scope

Bar D pre-extract completion inside `mcp_flutter`: registry-backed resources/templates,
`MCPCallEntry` hard cut, server `@AgentTool` codegen pilot, `agentkit_platform` emitters
(web + native), migration CLI, contract tests, skills, and program gate before monorepo extract (Phase 7).

**Out of scope:** Gemma product wiring, HarmonyOS NEXT, standalone repo extract, `fmt_migrate_agent_entries` MCP tool.

## Phase 6 sub-phases

| ID | Commit (representative) | Status |
|----|-------------------------|--------|
| 6a | `7677239` registry-backed `app/errors/{count}` template | done |
| 6b | `9823430` remove `MCPCallEntry` | done |
| 6c | `d835a02` `@AgentTool` `fmt_get_recent_logs` | done |
| 6d-web | `f3614b0` Web C bootstrap + `agentkit_platform` | done |
| 6d-native | `0633da3` Android/iOS/macOS/Linux/Windows emitters | done |
| 6e | `d07a592` registry–MCP contract tests | done |
| 6f | `0910443` `migrate agent-entries` CLI + doc | done |
| 6g | skills + `skill_assets.g.dart` | done (this gate) |
| 6h | tracker `complete_in_repo` | done (this gate) |

## Validation (gate run)

| Command | Result |
|---------|--------|
| `cd mcp_server_dart && dart test test/contract/` | pass (3) |
| `dart test packages/agentkit_platform` | pass (17) |
| `dart analyze mcp_toolkit` | pass (errors none) |
| `bash tool/contracts/check_agentkit_skills_grep.sh` | pass |
| `flutter-mcp-toolkit migrate agent-entries --check flutter_test_app/lib` | pass (exit 0) |

Full matrix (`dart test packages/agentkit_*`, `cd mcp_server_dart && dart test`) should run in CI before merge to `main`.

## Delivered (6g / 6h)

- Skill **`flutter-mcp-toolkit-agentkit-migration`** (CLI, before/after patterns)
- **`flutter-mcp-toolkit-custom-tools`** — `AgentCallEntry`-only authoring (+ `mcpToolkitTool` bridge)
- **`flutter-mcp-toolkit-debug`** — registry vs bundled tools note
- **`server_instructions.dart`** — AgentCallEntry + migration skill pointers
- **`mcp_toolkit.dart`** — documented allowed public surface
- Grep contract **`tool/contracts/check_agentkit_skills_grep.sh`**

## Deferred → Phase 7

- Standalone `agentkit` monorepo + pub.dev publish
- `agentkit_platform` Flutter plugin (`agentkit://invoke` via `app_links`)
- One-time Gradle/Xcode hook injection (`init agentkit-platform`)
- `fmt_migrate_agent_entries` MCP tool
- Public re-export shim removal after consumer deprecation window (if any remain outside `mcp_toolkit`)

## Handoff

Tracker: `program.status: complete_in_repo`, `active_phase: null`.  
Next: Phase 7 extract plan from [agentkit design spec](../specs/2026-05-25-agentkit-design.md).
