# Agentkit extract — regression checklist (mcp_flutter)

Last verified: 2026-05-27 after Phase 7 workspace move to `agentkit/`.

## Automated gates (run before merge)

| Gate | Command | Expected |
|------|---------|----------|
| Agentkit unit tests | `cd agentkit && make test` | 41 passed |
| Agentkit analyze | `cd agentkit && make analyze` | 0 errors |
| Integration | `make check-agentkit-integration` | OK |
| MCP toolkit app tests | `cd mcp_toolkit && flutter test` | All passed |
| Publish dry-run | `make publish-agentkit-dry-run` | 0 warnings |
| Contracts | `make check-contracts` | OK (local) |
| Runtime dogfood (web VM) | `make web-showcase` + `WS_URI=… make dogfood-eval` | iter 18: score **90**, `pass_with_warnings` (2026-05-26) |

## Flutter MCP Toolkit — no known regressions

| Area | Status | Notes |
|------|--------|-------|
| `MCPCallEntry` removed | OK | Only mentioned in export docs; use `AgentCallEntry` |
| `mcp_toolkit` path deps | OK | `../agentkit/packages/*` + root `dependency_overrides` |
| `MCPToolkitBinding.addEntries` | OK | Accepts `AgentCallEntry` |
| Web bootstrap | OK | `registerAgentWebMcpFromEntries` in `mcp_toolkit_extensions.dart` |
| Service extensions | OK | Unchanged pattern |
| Dogfood app | OK | `flutter_test_app` builds with path agentkit deps |

## Intentional changes (not regressions)

| Change | Impact |
|--------|--------|
| Packages moved to `agentkit/packages/` | Update imports only if you used `path: packages/agentkit_*` |
| `ToolRegistration` canonical in `agentkit_mcp` | Kernel re-exports — public API unchanged |
| Separate workspace | Run `dart pub get` at repo root after pulls |

## Still open / not regression-tested here

| Item | Risk |
|------|------|
| Hosted pub.dev deps (7.5) | Not cut over — path overrides required |
| Full `mcp_server_dart` + `flutter_test_app` runtime dogfood | **Done** — iter 18 (2026-05-26): score 90, `pass_with_warnings` (`visual_fidelity_skipped`); `validate_runtime_ok`, `webmcp_verify` pass |
| macOS Screen Recording capture | `make macos-validate-runtime` |
| External apps using old `packages/agentkit_*` paths | Update to `agentkit/packages/` |

## If something breaks

1. `dart pub get` at repo root (applies `dependency_overrides`).
2. Confirm `agentkit/packages/agentkit_core` exists.
3. `flutter-mcp-toolkit migrate agent-entries --check lib/`.
