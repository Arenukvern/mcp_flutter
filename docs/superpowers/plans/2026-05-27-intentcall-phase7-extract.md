# intentcall Phase 7 — Standalone monorepo extract

**Status:** Active — 7.1 done (2026-05-27)  
**ADR:** [decisions/0009-intentcall-extract.mdx](../../../decisions/0009-intentcall-extract.mdx)  
**Prerequisite:** `integration_hardening_complete: true` in [tracker](../tracker/intentcall-rollout.yaml)

## Key design decisions

1. New repo `intentcall` workspace with all `intentcall_*` packages — no `mcp_flutter` path deps.
2. Publish order: schema → core → mcp → webmcp/gemma/apple/android → platform → testing.
3. mcp_flutter flips to hosted `^0.1.0` (or git SHA) in a follow-up PR after first publish.
4. CI split: both repos gate on their integration scripts.

## Tasks

| ID | Task | Done when |
|----|------|-----------|
| 7.1 | Create external workspace `pubspec.yaml` + melos or plain workspace | **done** — `intentcall/` root; `make test` → 41 passed |
| 7.2 | Copy/move `packages/intentcall_*` | **done** — under `intentcall/packages/`; mcp_flutter uses `path: …/intentcall/packages/*` |
| 7.3 | Remove `publish_to: none`; add repository/homepage/topics per package | **done** — `make publish-intentcall-dry-run` → 0 warnings |
| 7.4 | Publish to pub.dev in order | **ready** — `bash tool/intentcall/publish_all.sh --execute` (needs pub credentials) |
| 7.5 | Cut `mcp_toolkit` + `server_capability_core` to hosted deps | **ready** — `docs/intentcall/hosted_cutover.md` + `print_hosted_deps.sh` |
| 7.6 | Add `make publish-intentcall` / release-please entries | **done** — `publish-intentcall-dry-run`, `intentcall/release-please-config.json`, CI workflow |
| 7.7 | mcp_flutter integration job uses published versions | **blocked on 7.4** — `check_no_path_deps.sh` for post-cutover gate |

## Validation

```bash
# In intentcall workspace (mcp_flutter/intentcall/ until external repo split)
cd intentcall && make test

# In mcp_flutter after cutover
make check-intentcall-integration
make check-contracts
```

## Out of scope

- Deleting mcp_flutter copy until cutover PR merges.
- Visual reconstruct harness repos.
