# intentcall extract — regression checklist (mcp_flutter)

Last verified: 2026-05-28 after Phase 7 extract to sibling repo `../agentkit`.

See [EXTERNAL_REPO.md](EXTERNAL_REPO.md).

## Automated gates (run before merge)

| Gate | Command | Expected |
|------|---------|----------|
| intentcall unit tests | `cd ../agentkit && make test` | 41 passed |
| intentcall analyze | `cd ../agentkit && make analyze` | 0 errors |
| Integration | `make check-intentcall-integration` | OK |
| MCP toolkit app tests | `cd mcp_toolkit && flutter test` | All passed |
| Publish dry-run | `make publish-intentcall-dry-run` | 0 warnings |
| Contracts | `make check-contracts` | OK (local) |
| Runtime dogfood (web VM) | `make web-showcase` + `WS_URI=… make dogfood-eval` | iter 18: score **90**, `pass_with_warnings` (2026-05-26) |

## Flutter MCP Toolkit — no known regressions

| Area | Status | Notes |
|------|--------|-------|
| `MCPCallEntry` removed | OK | Only mentioned in export docs; use `AgentCallEntry` |
| `mcp_toolkit` path deps | OK | `../../agentkit/packages/*` + root `dependency_overrides` → `../agentkit` |
| `MCPToolkitBinding.addEntries` | OK | Accepts `AgentCallEntry` |
| Web bootstrap | OK | `registerAgentWebMcpFromEntries` in `mcp_toolkit_extensions.dart` |
| Service extensions | OK | Unchanged pattern |
| Dogfood app | OK | `flutter_test_app` builds with path intentcall deps |

## Intentional changes (not regressions)

| Change | Impact |
|--------|--------|
| Packages in sibling `../agentkit/packages/` | Clone [intentcall](https://github.com/Arenukvern/intentcall) next to `mcp_flutter` (on-disk folder often `agentkit`) |
| `ToolRegistration` canonical in `intentcall_mcp` | Kernel re-exports — public API unchanged |
| Separate git repo | Run `dart pub get` in both repos after pulls |

## Still open / not regression-tested here

| Item | Risk |
|------|------|
| Hosted pub.dev deps (7.5) | Not cut over — path overrides required |
| Full `mcp_server_dart` + `flutter_test_app` runtime dogfood | **Done** — iter 18 (2026-05-26): score 90, `pass_with_warnings` (`visual_fidelity_skipped`); `validate_runtime_ok`, `webmcp_verify` pass |
| macOS Screen Recording capture | `make macos-validate-runtime` |
| External apps using old `packages/intentcall_*` paths | Update to `intentcall/packages/` |

## If something breaks

1. `dart pub get` at repo root (applies `dependency_overrides`).
2. Confirm `../agentkit/packages/intentcall_core` exists (sibling clone).
3. `flutter-mcp-toolkit migrate agent-entries --check lib/`.
