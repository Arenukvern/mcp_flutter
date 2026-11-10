# Native flutter_layer proof — consumer `03c1fdae` / oka `3477fb8a` (2026-11-09)

| Field | Value |
|-------|--------|
| Consumer HEAD (proof) | `03c1fdae450a9d9abf739fa690cc23b791fd6e32` |
| Merge commit | `a2d1e510` (`origin/main` into capture branch) |
| Prior pin attempt HEAD | `d0fbf497` — native **failed** (fixture pub get / semantics graph; fixed in `03c1fdae`) |
| Oka pin | `3477fb8ad96bd96750a7cdbe2959f818e55d6029` |
| Repin record | `docs/evidence/oka_consumer_repin_3477fb8a_20261109.md` |
| Prior pin history | `754b4750…` — `docs/evidence/oka_consumer_repin_754b4750_20261109.md` |

## CI runs (`03c1fdae`)

| Workflow | Run ID | Conclusion |
|----------|--------|------------|
| Native flutter_layer capture | [42637091496](https://github.com/Arenukvern/mcp_flutter/actions/runs/42637091496) | **success** |
| Contract Gates | [42637091629](https://github.com/Arenukvern/mcp_flutter/actions/runs/42637091629) | **success** |
| intentcall eval gates | [42637091666](https://github.com/Arenukvern/mcp_flutter/actions/runs/42637091666) | **success** |

PR #159 at proof head: **15 checks — 10 success, 5 skipped, 0 failed**; `mergeable: MERGEABLE`.

## Android gates (`native-capture-android`)

| Gate | Value |
|------|--------|
| Harness verdict | **pass** |
| `physicalSettlementOk` | **true** |
| One owned forward (session) | `post_launch`: `emulator-5554 tcp:43671 tcp:45269` (single matched owned line) |
| `forwardLinesAtEnd` | **[]** |
| App gone | `deviceAppGoneAtEnd: true` |
| Host identities quiet 10s | `trackedHostIdentitiesQuietAtEnd: true`, `windowElapsedMs: 10196`, `windowSeconds: 10` |
| `sessionCleanupIdentityMatch` | **true** (`android_session_cleanup_receipt.json`) |
| Counter | 0 → 1, pixel proof **pass** |
| Pin provenance | `pinMatchesHead: true` |

## Linux gates (`native-capture-linux`)

| Gate | Value |
|------|--------|
| Harness verdict | **pass** |
| `physicalSettlementOk` | **true** |
| `linuxSettlement.physicallySettled` | **true** |
| `linuxSettlement.shutdownTruthful` | **true** |
| Survivors | **[]** |

## CI fix note (`03c1fdae`)

After main #161 (`150a01d5`), provisioning pins the full oka graph via path overrides and sets hosted `universal_automation_interface: 0.4.0` (oka pin `3477fb8a` still declares `^0.3.0`) — **not** an assertion change.
