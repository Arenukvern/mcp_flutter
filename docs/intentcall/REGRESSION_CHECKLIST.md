# intentcall extract — regression checklist (mcp_flutter)

Last verified: 2026-06-06 after Phase 7 hosted cutover to pub.dev `intentcall_* 0.1.0`.

See [EXTERNAL_REPO.md](EXTERNAL_REPO.md).

## Automated gates (run before merge)

| Gate | Command | Expected |
|------|---------|----------|
| intentcall unit tests | `cd ../agentkit && make test` | 41 passed |
| intentcall analyze | `cd ../agentkit && make analyze` | 0 errors |
| Hosted integration | `make check-contracts` | OK |
| MCP toolkit app tests | `cd mcp_toolkit && flutter test` | All passed |
| No stale path deps | `rg -n "agentkit/packages|intentcall/packages|path: .*intentcall" pubspec.yaml packages/*/pubspec.yaml mcp_toolkit/pubspec.yaml flutter_test_app/pubspec.yaml mcp_server_dart/pubspec.yaml` | No matches |
| Publish dry-run | `cd ../agentkit && just publish-dry-run` | For future IntentCall releases |
| Contracts | `make check-contracts` | OK |
| Runtime dogfood (web VM) | `make web-showcase` + `WS_URI=… make dogfood-eval` | iter 18: score **90**, `pass_with_warnings` (2026-05-26) |

## Flutter MCP Toolkit — no known regressions

| Area | Status | Notes |
|------|--------|-------|
| `MCPCallEntry` removed | OK | Only mentioned in export docs; use `AgentCallEntry` |
| `mcp_toolkit` hosted deps | OK | Uses hosted `intentcall_* ^0.1.0`; no `intentcall_*` path overrides |
| `MCPToolkitBinding.addEntries` | OK | Accepts `AgentCallEntry` |
| Web bootstrap | OK | `registerAgentWebMcpFromEntries` in `mcp_toolkit_extensions.dart` |
| Service extensions | OK | Unchanged pattern |
| Dogfood app | OK | `flutter_test_app` builds with path intentcall deps |

## Intentional changes (not regressions)

| Change | Impact |
|--------|--------|
| Packages in sibling `../agentkit/packages/` | Local-development source only; hosted consumers use pub.dev |
| `ToolRegistration` canonical in `intentcall_mcp` | Kernel re-exports — public API unchanged |
| Separate git repo | Run `dart pub get` in both repos after pulls |

## Still open / not regression-tested here

| Item | Risk |
|------|------|
| Hosted pub.dev deps (7.5) | Cut over — path overrides should not reappear in normal consumers |
| Full `mcp_server_dart` + `flutter_test_app` runtime dogfood | **Done** — iter 18 (2026-05-26): score 90, `pass_with_warnings` (`visual_fidelity_skipped`); `validate_runtime_ok`, `webmcp_verify` pass |
| macOS Screen Recording capture | `make macos-validate-runtime` |
| External apps using old `packages/intentcall_*` paths | Update to `intentcall/packages/` |

## If something breaks

1. `dart pub get` at repo root.
2. Confirm pub.dev resolves the intended `intentcall_*` versions in lockfiles.
3. `flutter-mcp-toolkit migrate agent-entries --check lib/`.
