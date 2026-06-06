# What's next — intentcall + visual

Single forward index. **Source of truth for program state:** [tracker/intentcall-rollout.yaml](tracker/intentcall-rollout.yaml).

## intentcall (post-cutover verification)

| Sub-phase | Status | Doc / command |
|-----------|--------|----------------|
| 7.4 Publish to pub.dev | Done | `intentcall_*` packages are hosted at `0.1.0`; use the Phase 7 plan only as release history |
| 7.5 Hosted consumer cutover | Done | `mcp_toolkit`, `mcp_server_dart`, capability packages, and `flutter_test_app` use hosted `intentcall_* ^0.1.0` |
| 7.7 Integration on hosted versions | Active verification | `make check-contracts`; stale path scan for `agentkit/packages`, `intentcall/packages`, and `path: .*intentcall` |

**Done in-repo:** `program.status: complete_in_repo_product` — integration hardening archived ([integration completion plan](plans/archive/2026-05-26-intentcall-integration-completion-next.md)).

**Current next work:** keep hosted dependency proof green, publish/validate `mcp_toolkit` prereleases explicitly, and update downstream apps only when they pin the intended prerelease (`^4.0.0-dev.1` or newer).

**Loop:** [intentcall-self-closing-loop.md](intentcall-self-closing-loop.md) · **Design:** [specs/2026-05-25-intentcall-design.md](specs/2026-05-25-intentcall-design.md)

## Visual reconstruct (maintenance)

| Track | Status | Doc |
|-------|--------|-----|
| Checkpoint protocol (HS + human `.approved`) | Open | [visual-reconstruct-next](plans/2026-05-26-visual-reconstruct-next.md) |
| Warm-path dogfood | Green iters 13–17; optional re-run | [evals README](evals/README.md) · [dogfood tracker](../.showcase/dogfood_web_eval.yaml) |
| Cold path / deconstruct | Offline green | [deconstruct verification](evals/2026-05-26-deconstruct-verification.md) |

**Not a tracker phase** — parallel harness work across sibling repos (`flutter_harness`, `flutter_visual_reconstruct`).

## Archives (do not execute)

- [plans/archive/](plans/archive/) — completed phase plans
- [evals/archive/](evals/archive/) — historical eval snapshots
