# IntentCall consumer guide for mcp_flutter

`mcp_flutter` is a consumer and proof repository for IntentCall. It uses hosted `intentcall_*` packages, validates Flutter MCP Toolkit integration, and dogfoods platform hooks. Canonical IntentCall architecture, package design, platform projection, and ADRs live in the sibling IntentCall repository.

| Item | Location |
|------|----------|
| Canonical local IntentCall clone | `/Users/anton/mcp/agentkit` |
| GitHub | `github.com/Arenukvern/intentcall` |
| Consumer package policy | Hosted `intentcall_* ^0.1.0` from pub.dev |
| Local-development exception | Temporary sibling path overrides to `/Users/anton/mcp/agentkit/packages/intentcall_*` only |
| Main integration gate | `make check-intentcall-integration` |
| Repo contract gate | `make check-contracts` |
| IntentCall publish checks | Run from `/Users/anton/mcp/agentkit` |

## Boundary

Keep IntentCall product architecture out of this repository. If a doc needs to explain API ownership, package boundaries, adapter contracts, schema semantics, platform projection, or release strategy, update `/Users/anton/mcp/agentkit` instead.

Keep `mcp_flutter` docs focused on consumer integration, migration, regression proof, and dogfood behavior.

## Normal consumer state

Committed `mcp_flutter` state should use hosted `intentcall_*` dependencies. Do not commit normal consumer pubspecs with `agentkit/packages`, `intentcall/packages`, or `path: .*intentcall` dependencies.

Use local path overrides only while deliberately developing against the sibling IntentCall checkout, then remove them before committing consumer integration changes.

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
| Hosted dependency or local path override drift | `tool/intentcall/check_no_path_deps.sh`, then this guide |
| Platform hooks, WebMCP, deep links, app dynamic tools | [flutter_test_app/INTENTCALL_PLATFORM.md](../../flutter_test_app/INTENTCALL_PLATFORM.md) |
| Schema, `fmt_*`, CLI `exec`, or app-dynamic parity debugging | `plugin/skills/flutter-mcp-boundary-audit/` |
| Unsure whether to fix `mcp_flutter` or IntentCall upstream | Fix consumer wiring here; fix architecture/package behavior in `/Users/anton/mcp/agentkit` |

## Maintainer notes

For future hosted dependency bumps:

1. Confirm the intended `intentcall_*` versions exist on pub.dev.
2. Update consumer constraints in `mcp_toolkit`, `mcp_server_dart`, capability packages, and `flutter_test_app` as needed.
3. Remove temporary local path overrides.
4. Run the consumer proof gates above.
5. Investigate package behavior regressions in `/Users/anton/mcp/agentkit`, not in this consumer repo.

Historical in-repo IntentCall rollout plans, specs, trackers, closure reports, hosted cutover notes, and checklist docs were removed after durable extraction. Git history is the forensic archive.
