# Hold: oka `cb672b7b…` (PR #18) — SDK not ready for expensive native rerun

**Full SHA (provisional, not consumer-pushed):** `cb672b7bca8198c57a05b548443980efabf5d679`  
**Committed consumer pin (remote):** `9e6facf0ea3c5154e31d9e0b52de5f08ee69bfc0` until next coherent SDK fix.

**Independent review:** consumer `1edd1e4f` observation verdict (primary vs candidates, read errors, identity unknown, pre-launch baseline) — **fail-closed correct**. Native `pull_request` remains enabled; **do not** re-introduce allowlist/workflow-hold scaffolding.

## SDK blockers (independent review, SDK fixing)

| Issue | Detail |
|--------|--------|
| Teardown tests | Overall runtime **≥67s** vs **45s** bound; unbounded adb usage |
| Read semantics | Read failures treated as success paths |
| Quit/stop | `app.stop` / attach still **no actual stop** evidence |
| Forwards | Second forward path unhandled |
| Receipts | Failure receipt **not propagated** |

**Consumer:** no kills, no relaxed physical gate, no merge/publish. Await next immutable SDK SHA + local stop/binding/**teardown** + observation helper green before **intentional** native (10s settlement).

Local-only prep: provision pin `cb672b7b…` in VM for unit tests only; do not push repin until SDK sign-off.
