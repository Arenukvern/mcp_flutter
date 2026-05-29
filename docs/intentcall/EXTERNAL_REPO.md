# IntentCall external repository

As of Phase 7 extract (2026-05-28), the IntentCall workspace lives in a **sibling git repository**, not under `mcp_flutter/packages/intentcall_*`.

| Item | Location |
|------|----------|
| GitHub | [github.com/Arenukvern/intentcall](https://github.com/Arenukvern/intentcall) |
| Local clone | `../agentkit` or `../intentcall` (e.g. `~/mcp/agentkit`) |
| Consumer path deps | `../agentkit/packages/<package>` from `mcp_flutter` root overrides |
| Integration gate | `make check-intentcall-integration` |
| Publish dry-run | `make -C ../agentkit publish-dry-run` or `make publish-intentcall-dry-run` from mcp_flutter |

## Local layout

```text
mcp/
├── agentkit/            # IntentCall workspace (folder name may lag GitHub rename)
└── mcp_flutter/         # consumers (path deps → ../agentkit/packages/intentcall_*)
```

## CI

`mcp_flutter` workflows check out `Arenukvern/intentcall` into `intentcall-external/` and set `INTENTCALL_ROOT` for integration jobs.

## History

The standalone repo uses **fresh git history**. Prior commits remain in `mcp_flutter` git history for paths under `intentcall/` before removal.
