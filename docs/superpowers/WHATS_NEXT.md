# What's next

This file tracks non-IntentCall forward work. IntentCall consumer guidance lives in
[docs/intentcall/README.md](../intentcall/README.md); canonical IntentCall
architecture lives in `/Users/anton/mcp/agentkit`.

## Visual reconstruct (maintenance)

| Track | Status | Doc |
|-------|--------|-----|
| Checkpoint protocol (HS + human `.approved`) | Open | [visual-reconstruct-next](plans/2026-05-26-visual-reconstruct-next.md) |
| Warm-path dogfood | Green iters 13–17; optional re-run | [evals README](evals/README.md) · [dogfood tracker](../.showcase/dogfood_web_eval.yaml) |
| Cold path / deconstruct | Offline green | [deconstruct verification](evals/2026-05-26-deconstruct-verification.md) |

**Not a tracker phase** — parallel harness work across sibling repos (`flutter_harness`, `flutter_visual_reconstruct`).

## Historical eval snapshots

Historical eval snapshots live in [evals/archive/](evals/archive/). They are evidence records, not execution plans.
