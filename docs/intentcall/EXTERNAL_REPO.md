# IntentCall external repository

As of Phase 7 extract (2026-05-28), the IntentCall workspace lives in a **sibling git repository**, not under `mcp_flutter/packages/intentcall_*`.

| Item | Location |
|------|----------|
| GitHub | [github.com/Arenukvern/intentcall](https://github.com/Arenukvern/intentcall) |
| Local clone | `../agentkit` or `../intentcall` (e.g. `~/mcp/agentkit`) |
| Consumer deps | Hosted `intentcall_* ^0.1.0` from pub.dev; sibling path deps are local-development-only |
| Integration gate | `make check-intentcall-integration` |
| Publish dry-run | `make -C ../agentkit publish-dry-run` or `make publish-intentcall-dry-run` from mcp_flutter |

## Local layout

```text
mcp/
├── agentkit/            # IntentCall workspace (folder name may lag GitHub rename)
└── mcp_flutter/         # consumers (hosted deps; optional local overrides only for IntentCall development)
```

## CI

`mcp_flutter` hosted integration should resolve from pub.dev. Workflows may still check out `Arenukvern/intentcall` for upstream source validation, publish dry-runs, or local-development override tests.

## History

The standalone repo uses **fresh git history**. Prior commits remain in `mcp_flutter` git history for paths under `intentcall/` before removal.
