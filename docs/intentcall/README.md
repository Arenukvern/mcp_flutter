# IntentCall consumer guide for mcp_flutter

`mcp_flutter` is a consumer and proof repository for IntentCall. It uses hosted `intentcall_*` packages, validates Flutter MCP Toolkit integration, and dogfoods platform hooks. Canonical IntentCall architecture, package design, platform projection, and ADRs live in the sibling IntentCall repository.

| Item | Location |
|------|----------|
| Canonical local IntentCall clone | `/Users/anton/mcp/agentkit` |
| GitHub | `github.com/Arenukvern/intentcall` |
| Consumer package policy | Hosted `intentcall_* ^0.3.0` from pub.dev |
| Local-development exception | Temporary sibling path overrides to `/Users/anton/mcp/agentkit/packages/intentcall_*` only |
| Main integration gate | `make check-intentcall-integration` |
| Repo contract gate | `make check-contracts` |
| IntentCall publish checks | Run from `/Users/anton/mcp/agentkit` |

## Boundary

Keep IntentCall product architecture out of this repository. If a doc needs to explain API ownership, package boundaries, adapter contracts, schema semantics, platform projection, or release strategy, update `/Users/anton/mcp/agentkit` instead.

Keep `mcp_flutter` docs focused on consumer integration, migration, regression proof, and dogfood behavior.

## Runtime sessions

Runtime session ownership lives in IntentCall, not in this consumer repo.
Downstream debug tools that need a running app session should depend on
`intentcall_session` for session state/lifecycle and on `intentcall_core` /
`intentcall_schema` for registry, invocation, result, artifact, and event
semantics.

The reusable session surface is:

- `SessionState`, `PersistedState`, `StateStore`, `StateLockManager`, and
  `SafeFileWriter`
- `IntentSessionManager` backed by an `IntentSessionConnector`
- `IntentSessionExecutor` for invoking an `AgentRegistry` inside a session
- `IntentSnapshotStore` for generic JSON snapshot persistence and diffing
- `AgentResult` / `AgentArtifact` from IntentCall

Do not import `mcp_server_dart/src/cli/session/*` or other private server
internals from downstream repos. The hard public boundary is
`intentcall_session` plus the IntentCall registry/result packages; Flutter MCP
is the adapter proving those pieces against a real Flutter app.

Breaking boundary cut: `mcp_server_dart/lib/flutter_mcp_core.dart` and
server-local session barrels no longer promise compatibility for removed
`SessionManager`, `StateStore`, `StateLockManager`, `SafeFileWriter`, or
snapshot internals. Downstream code must import `intentcall_session` for
`IntentSessionManager`, `StateStore`, `StateLockManager`, `SafeFileWriter`, and
`IntentSnapshotStore`. Flutter MCP exposes `FlutterSessionConnector` only as
its adapter between `ConnectionContext` and IntentCall sessions.

Flutter MCP remains one runtime adapter. It keeps VM service discovery, DTD,
Flutter extension calls, screenshots, widget inspection, MCP projection, and CLI
daemon wiring in `mcp_server_dart`. Its `FlutterSessionConnector` adapts
`ConnectionContext` to `IntentSessionConnector`.

The word "broker" should describe product composition, not a new facade layer.
For example, a visual-debug broker can compose `IntentSessionManager`,
`IntentSessionExecutor`, `AgentRegistry`, `intentcall_mcp`, and its artifact
storage. It should not re-export those packages or duplicate the command
executor under a new name.

Dynamic registry is also IntentCall responsibility. If registry ownership,
catalog snapshots, invocation semantics, durable permissions, or transport
publication rules need to change, update `/Users/anton/mcp/agentkit` and dogfood
the hosted or overridden package here.

Flutter MCP still owns Flutter-specific dynamic discovery: reading app-posted
tools/resources from the VM service, registering Flutter extension calls, and
bridging screenshots/widget inspection. IntentCall owns the reusable registry
events and MCP publication behavior, including query-tolerant resource reads and
resource-template de-duplication.

Flutter MCP also owns command snapshot production. The reusable
`IntentSnapshotStore` persists and diffs JSON payloads; `CommandSnapshotService`
in `mcp_server_dart` builds those payloads by executing the Flutter MCP command
catalog through `DefaultCoreCommandExecutor`.

## Normal consumer state

Committed `mcp_flutter` state should use hosted `intentcall_*` dependencies. Do not commit normal consumer pubspecs with `agentkit/packages`, `intentcall/packages`, or `path: .*intentcall` dependencies.

Use root `dependency_overrides` only while deliberately developing against the
sibling IntentCall checkout, then remove them before publishing consumer
integration changes.

## Consumer proof gates

Run these before changing IntentCall consumption in `mcp_flutter`:

```bash
make check-intentcall-integration
make check-contracts
```

When plugin skills change, also run the skill sync workflow before claiming the generated runtime assets are current:

```bash
make sync-skills
```

The durable proof should live in checks, CI, Steward scenarios, tests, and dated evidence records, not in a hand-maintained pass-count checklist.

## Troubleshooting routes

| Symptom | Start here |
|---------|------------|
| `MCPCallEntry` compile errors or migration work | [MCPCallEntry to AgentCallEntry migration](../start_here/migration_mcp_call_entry_to_agent_call_entry.md) |
| Hosted dependency or local path override drift | `tool/intentcall/check_no_path_deps.sh`; use `--strict-root` before release/cutover |
| Platform hooks, WebMCP, deep links, app dynamic tools | [flutter_test_app/INTENTCALL_PLATFORM.md](../../flutter_test_app/INTENTCALL_PLATFORM.md) |
| Schema, `fmt_*`, CLI `exec`, or app-dynamic parity debugging | `plugin/skills/flutter-mcp-boundary-audit/` |
| Unsure whether to fix `mcp_flutter` or IntentCall upstream | Fix consumer wiring here; fix architecture/package behavior in `/Users/anton/mcp/agentkit` |

## Maintainer notes

For future hosted dependency bumps:

1. Confirm the intended `intentcall_*` versions exist on pub.dev.
2. Update consumer constraints in `mcp_toolkit`, `mcp_server_dart`, capability packages, and `flutter_test_app` as needed.
3. Remove temporary local path overrides.
4. Run `tool/intentcall/check_no_path_deps.sh --strict-root`.
5. Run the consumer proof gates above.
6. Investigate package behavior regressions in `/Users/anton/mcp/agentkit`, not in this consumer repo.

Historical in-repo IntentCall rollout plans, specs, trackers, closure reports, hosted cutover notes, and checklist docs were removed after durable extraction. Git history is the forensic archive.
