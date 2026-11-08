# Coherent consumer repin: oka `1b7f18fa…` (identity fix)

**SDK SHA:** `1b7f18fa48f2c87096e023ce59478d30737e69f8`  
**Independent review:** NO critical source blocker; stop-start snapshot owner pid/port/startedAt triple-match, no-identity reject, unknown pidof stderr fail-closed, actual-resource force-stop/detach/long budget — reviewed correct. CI/native only remaining.

**Consumer mcp_flutter HEAD at repin push:** (see git after commit)  
**Provenance:** `docs/evidence/oka_consumer_provenance_1b7f18f.json`

## Local member gates (pre-push)

| Gate | Result |
|------|--------|
| `dart analyze --fatal-infos packages/harness` | pass |
| harness unit excl. native tags | **124 pass, 1 skip** (SIG_IGN child; `drainsCompleted` + ready handshake) |
| observation + session cleanup consumer | **9 pass** (verdict 4 + cleanup 3 + subprocess 2) |
| `oka_android` `dart analyze --fatal-infos` | pass |
| `oka_android` full `dart test` | **192 pass, 3 skip** |
| teardown file isolated | **17 pass** (~1.3s wall) |
| stop file isolated | **6 pass** (~22s wall) |
| stop+binding+teardown batched inventory | **1 flake** (`TCP quit flushed…`); **pass in isolation** — matches TEST-only `cooperative_stop_owner` partial-write fix pending |
| sidecar + binding | pass |
| `oka_harness` | **17 pass** |

**Native proof intents after push (not local):** true attach URL, owned forward baseline + removal, fixture app gone, frozen orphans quiet, same-device candidates absent at **10s** settle, `sessionCleanup` receipt identity match via SDK getters (`rawSessionTeardownFile` attach-only).

## TEST-only SDK follow-up (does not block production pin)

Upstream correcting **atomic fixture write** in `cooperative_stop_owner` (partial JSON read on plain write) — **not** port `31999` semantics. If a follow-up fixture-only SDK SHA lands before green native, may repin; otherwise **1b7f18f production code** stands; do not discard CI run on parallel flake alone.

**No merge/publish.**
