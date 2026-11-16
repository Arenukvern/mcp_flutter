# Hold native repin: oka `ac745d9f…` — session-cleanup identity still wrong

**Local SDK prep SHA (not remote pin):** `ac745d9f44f5aa5f0d0bcea31ea0be16615d078c`  
**Remote `tool/ci/oka_consumer_pin.txt`:** `9e6facf0ea3c5154e31d9e0b52de5f08ee69bfc0` until next SDK SHA fixes sidecar identity.

## SDK status (independent cleanup review)

Teardown budget (~36s bound), healthy-shell `pidof` exit-1-empty sentinel, retained sidecar with identity field, device debug URL + recorded host port attach — **core fixed**. Remaining blocker:

- **Receipt identity** still compares **discovery owner** to **spawn PID** (e.g. `4353 != 4371`) and can accept **no identity** — must not ship consumer pin or intentional native **10s** settlement until SDK publishes a coherent identity SHA.

## Consumer (this branch)

- `ab022b52` handshake: removes SIGTERM-before-handler race; **`drainsCompleted` restored** (single stdout subscription → ready, then drain passed into `stopOwnedSubprocess`).
- POSIX guard: `python3` SIG_IGN child skipped on non-Linux/non-macOS or missing `python3` (not a silent full-suite pass on unsupported OS).
- Session-cleanup consumer artifact: `android_session_cleanup_receipt.json` with identity match + frozen launch orphans referenced; **fail-closed** until SDK sidecar identity is truthful.
- Deadline verdict gate in `physicalSettlementVerdictFromObservation` — confirmed.
- **No** workflow-hold scaffolding; **no** merge/publish.

## Local gates exercised against `ac745d9f` checkout (VM only)

| Gate | Result |
|------|--------|
| `dart analyze --fatal-infos packages/harness` | pass |
| harness unit (excl. native tags) | 124 pass, 1 skip |
| `oka_android` stop (24) + binding (3) + teardown (15) | pass, teardown wall \< 45s |
| `oka_harness` | 17 pass |
| observation verdict / forward watch / identity | pass |

**Not done:** upstream oka SDK CI green; emulator **native** flutter_layer (10s physical settlement + parsed session cleanup identity match). Do not claim finished on local tests alone.
