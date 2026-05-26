# What's next — agentkit + visual

Single forward index. **Source of truth for program state:** [tracker/agentkit-rollout.yaml](tracker/agentkit-rollout.yaml).

## Agentkit (Phase 7 extract — in progress)

| Sub-phase | Status | Doc / command |
|-----------|--------|----------------|
| 7.4 Publish to pub.dev | Pending | [Phase 7 plan](plans/2026-05-27-agentkit-phase7-extract.md) · `bash tool/agentkit/publish_all.sh --execute` |
| 7.5 Hosted consumer cutover | Pending (blocked on 7.4) | [Phase 7 plan](plans/2026-05-27-agentkit-phase7-extract.md) §7.5 · [hosted_cutover.md](../../docs/agentkit/hosted_cutover.md) |
| 7.7 Integration on hosted versions | Pending (blocked on 7.5) | `make check-agentkit-integration` after cutover |

**Done in-repo:** `program.status: complete_in_repo_product` — integration hardening archived ([integration completion plan](plans/archive/2026-05-26-agentkit-integration-completion-next.md)).

**Loop:** [agentkit-self-closing-loop.md](agentkit-self-closing-loop.md) · **Design:** [specs/2026-05-25-agentkit-design.md](specs/2026-05-25-agentkit-design.md)

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
