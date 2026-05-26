# Agentkit Phase 7 — Standalone monorepo extract

**Status:** Active — 7.1 done (2026-05-27)  
**ADR:** [decisions/0009-agentkit-extract.mdx](../../../decisions/0009-agentkit-extract.mdx)  
**Prerequisite:** `integration_hardening_complete: true` in [tracker](../tracker/agentkit-rollout.yaml)

## Key design decisions

1. New repo `agentkit` workspace with all `agentkit_*` packages — no `mcp_flutter` path deps.
2. Publish order: schema → core → mcp → webmcp/gemma/apple/android → platform → testing.
3. mcp_flutter flips to hosted `^0.1.0` (or git SHA) in a follow-up PR after first publish.
4. CI split: both repos gate on their integration scripts.

## Tasks

| ID | Task | Done when |
|----|------|-----------|
| 7.1 | Create external workspace `pubspec.yaml` + melos or plain workspace | **done** — `agentkit/` root; `make test` → 41 passed |
| 7.2 | Copy/move `packages/agentkit_*` | **done** — under `agentkit/packages/`; mcp_flutter uses `path: …/agentkit/packages/*` |
| 7.3 | Remove `publish_to: none`; add repository/homepage/topics per package | **done** — `make publish-agentkit-dry-run` → 0 warnings |
| 7.4 | Publish to pub.dev in order | **ready** — `bash tool/agentkit/publish_all.sh --execute` (needs pub credentials) |
| 7.5 | Cut `mcp_toolkit` + `server_capability_core` to hosted deps | **ready** — `docs/agentkit/hosted_cutover.md` + `print_hosted_deps.sh` |
| 7.6 | Add `make publish-agentkit` / release-please entries | **done** — `publish-agentkit-dry-run`, `agentkit/release-please-config.json`, CI workflow |
| 7.7 | mcp_flutter integration job uses published versions | **blocked on 7.4** — `check_no_path_deps.sh` for post-cutover gate |

## Validation

```bash
# In agentkit workspace (mcp_flutter/agentkit/ until external repo split)
cd agentkit && make test

# In mcp_flutter after cutover
make check-agentkit-integration
make check-contracts
```

## Out of scope

- Deleting mcp_flutter copy until cutover PR merges.
- Visual reconstruct harness repos.
