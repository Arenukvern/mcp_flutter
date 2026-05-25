# Agentkit Phase 6 — Pre-extract completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. One subagent per sub-phase (6a–6h). Closer gate after each sub-phase. Branch: `feat/agentkit-phase1-3` (never `main`).

**Goal:** Complete agentkit inside mcp_flutter per [Bar D spec](../specs/2026-05-26-agentkit-pre-extract-completion-design.md) before any monorepo extract.

**Architecture:** Remove `MCPCallEntry` and dual paths; keep `AgentRegistry` + `AgentRuntime` + `McpPublishAdapter`; add emitters, migration tools, contract tests.

**Tech Stack:** Dart 3, agentkit_*, mcp_toolkit, flutter_mcp_toolkit_server CLI, build_runner (codegen), plugin skills → skill_assets.g.dart

---

## Key Design Decisions

| Decision | Choice |
|----------|--------|
| API cut | Delete `MCPCallEntry`; no public typedef shim |
| Migration | CLI `migrate agent-entries` + MCP `fmt_migrate_agent_entries` |
| Semver | Major mcp_toolkit bump; CHANGELOG migration section |
| Gemma | No product work |
| Swift/XML | Real emitters + CLI `codegen manifest` |

---

## Task 1: 6a — Registry-backed errors template

**Files:**
- Modify: `mcp_server_dart/lib/src/mcp_toolkit_server/mixins/flutter_inspector.dart`
- Modify: `packages/agentkit_mcp/lib/src/mcp_publish_adapter.dart` (if template URI matching needed)
- Test: `mcp_server_dart/test/flutter_inspector_resources_test.dart` (create if missing)

- [ ] **Step 1:** Write failing test — read `visual://localhost/app/errors/3` returns JSON via registry invoke
- [ ] **Step 2:** Register template URI pattern as resource intent(s) or single intent with `count` param; remove `addResourceTemplate` for errors
- [ ] **Step 3:** Run host + inspector tests
- [ ] **Step 4:** Commit `feat(agentkit): registry-backed app errors resource template`

---

## Task 2: 6b — Hard cut MCPCallEntry (client)

**Files:**
- Delete: `mcp_toolkit/lib/src/mcp_call_entry_bridge.dart`
- Modify: `mcp_toolkit/lib/src/mcp_models.dart` — remove MCPCallEntry; ensure AgentCallEntry factories cover tool/resource
- Modify: `mcp_toolkit/lib/mcp_toolkit.dart` exports
- Modify: `mcp_toolkit/lib/src/mcp_toolkit_binding.dart`, `mcp_toolkit_extensions.dart`, `agent_client_install.dart`
- Modify: all `mcp_toolkit/lib/src/toolkits/*.dart`
- Modify: `flutter_test_app/lib/main.dart`, examples
- Test: `mcp_toolkit/test/**`, `flutter_test_app` analyze

- [ ] **Step 1:** Add/extend `AgentCallEntry` factories if MCP factories had unique behavior (methodName, resourceUri)
- [ ] **Step 2:** Migrate toolkits + binding to `AgentCallEntry` (compile-driven)
- [ ] **Step 3:** Delete bridge + MCPCallEntry types
- [ ] **Step 4:** Fix tests; `dart test mcp_toolkit`
- [ ] **Step 5:** Commit `feat(agentkit)!: remove MCPCallEntry from mcp_toolkit`

---

## Task 3: 6c — Server @AgentTool codegen (one fmt_*)

**Files:**
- Modify: one capability under `packages/server_capability_core` or `mcp_server_dart` capabilities
- Create: annotated tool source + `.g.dart`
- Test: capability + `host_test` / e2e invoke

- [ ] **Step 1:** Pick low-risk `fmt_*` tool for codegen pilot
- [ ] **Step 2:** Add `@AgentTool` + build_runner dep; generate registration
- [ ] **Step 3:** Wire through existing ToolRegistration path
- [ ] **Step 4:** Test invoke via MCP/registry
- [ ] **Step 5:** Commit

---

## Task 4: 6d — Swift + XML emitters

**Files:**
- Modify: `packages/agentkit_apple/lib/src/` — add `swift_app_intents_emitter.dart`
- Modify: `packages/agentkit_android/lib/src/` — add `shortcuts_xml_emitter.dart`
- Modify: `mcp_server_dart/bin/flutter_mcp_toolkit.dart` — `codegen manifest` subcommand
- Test: `packages/agentkit_apple/test/`, `packages/agentkit_android/test/`

- [ ] **Step 1:** Failing golden tests for minimal descriptor → Swift/XML strings
- [ ] **Step 2:** Implement emitters from manifest JSON or descriptor list
- [ ] **Step 3:** CLI subcommand writes stdout or `--output`
- [ ] **Step 4:** README updates in apple/android packages
- [ ] **Step 5:** Commit

---

## Task 5: 6e — Contract tests

**Files:**
- Create: `packages/agentkit_testing/lib/src/contract/` or `mcp_server_dart/test/contract/agentkit_contract_test.dart`
- Use: `agentkit_mcp` mappers

- [ ] **Step 1:** Test fmt tool args → registry vs MCP adapter same envelope
- [ ] **Step 2:** Test dynamic tool fake intent
- [ ] **Step 3:** Test one resource URI round-trip
- [ ] **Step 4:** Add to CI validation list in tracker
- [ ] **Step 5:** Commit

---

## Task 6: 6f — Migration CLI + MCP + docs

**Files:**
- Create: `mcp_server_dart/lib/src/cli/migrate_agent_entries_command.dart`
- Modify: `mcp_server_dart/bin/flutter_mcp_toolkit.dart`
- Create: MCP command in capability (e.g. `fmt_migrate_agent_entries`)
- Create: `docs/start_here/migration_agentkit_phase6.md`
- Modify: root `CHANGELOG.md`, `mcp_toolkit/CHANGELOG.md`
- Test: `mcp_server_dart/test/migrate_agent_entries_test.dart`, fixtures

- [ ] **Step 1:** Fixture pairs (before/after) for migrator unit tests
- [ ] **Step 2:** Implement AST-safe or regex-based migrator (document limits)
- [ ] **Step 3:** CLI `migrate agent-entries [--check] [--write]`
- [ ] **Step 4:** MCP tool report-only + optional apply flag
- [ ] **Step 5:** Migration doc + CHANGELOG
- [ ] **Step 6:** Commit

---

## Task 7: 6g — Skills

**Files:**
- Create: `plugin/skills/flutter-mcp-toolkit-agentkit-migration/SKILL.md`
- Modify: `plugin/skills/flutter-mcp-toolkit-custom-tools/SKILL.md`
- Modify: `plugin/skills/flutter-mcp-toolkit-debug/SKILL.md`, `flutter-mcp-toolkit-repo-maintainer/SKILL.md`
- Regenerate: `mcp_server_dart/lib/src/skill_assets.g.dart` (maintainer script)
- Modify: `mcp_server_dart/lib/src/mcp_toolkit_server/server_instructions.dart`

- [ ] **Step 1:** Write migration skill (CLI + MCP migrate, hard cut)
- [ ] **Step 2:** Rewrite custom-tools for AgentCallEntry only
- [ ] **Step 3:** Regenerate skill_assets; grep gate no stray MCPCallEntry
- [ ] **Step 4:** Commit

---

## Task 8: 6h — Shims + gate

**Files:**
- Modify: `mcp_toolkit/lib/mcp_toolkit.dart` exports
- Create: `docs/superpowers/closure/2026-05-26-agentkit-program-complete-in-repo.md`
- Modify: tracker, rollout

- [ ] **Step 1:** Remove redundant shims; document allowed imports
- [ ] **Step 2:** Run full validation matrix from spec 6h
- [ ] **Step 3:** Closure report + tracker `complete_in_repo`
- [ ] **Step 4:** Commit

---

## Suggested subagent order

```text
6a → 6b → 6c → 6d → 6e → 6f → 6g → 6h
```

(6f can start after 6b for fixture accuracy; 6g after 6f for skill content.)

---

## Validation matrix (final gate)

| Command | Expect |
|---------|--------|
| `dart test packages/agentkit_*` | pass |
| `dart test packages/server_capability_kernel` | pass |
| `cd mcp_server_dart && dart test` | pass |
| `dart analyze` agentkit paths | no errors |
| `flutter-mcp-toolkit migrate agent-entries --check` on flutter_test_app | exit 0 |
