# What's next — intentcall + visual

Single forward index. **Source of truth for program state:** [tracker/intentcall-rollout.yaml](tracker/intentcall-rollout.yaml).

## intentcall (Phase 7 extract — in progress)

| Sub-phase | Status | Doc / command |
|-----------|--------|----------------|
| 7.4 Publish to pub.dev | Pending | [Phase 7 plan](plans/2026-05-27-intentcall-phase7-extract.md) · `bash tool/intentcall/publish_all.sh --execute` |
| 7.5 Hosted consumer cutover | Pending (blocked on 7.4) | [Phase 7 plan](plans/2026-05-27-intentcall-phase7-extract.md) §7.5 · [hosted_cutover.md](../../docs/intentcall/hosted_cutover.md) |
| 7.7 Integration on hosted versions | Pending (blocked on 7.5) | `make check-intentcall-integration` after cutover |

**Done in-repo:** `program.status: complete_in_repo_product` — integration hardening archived ([integration completion plan](plans/archive/2026-05-26-intentcall-integration-completion-next.md)).

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
