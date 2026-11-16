# Native flutter_layer proof — consumer `dbee54a3` / oka `7fd1d5bf` (2026-11-09)

| Field | Value |
|-------|--------|
| Consumer HEAD | `dbee54a38315dc54347ec05bc9c21a8d6bc4fde4` |
| Pin | `7fd1d5bf039cbbd0125683945c5273e83e7aac1b` |
| CI run | [42618846519](https://github.com/Arenukvern/mcp_flutter/actions/runs/42618846519) |
| Android job | **success** |
| Artifacts | `native-capture-android` |

## CI checks (15)

**10 success**, **5 skipped**, **0 failed** at `dbee54a3` (incl. Android + Linux native, contract gates, intentcall eval).

## Android proof (artifact-backed)

| Gate | Result |
|------|--------|
| Attach / session | `runner-session.json` published; VM `127.0.0.1:33327` |
| Attach handshake (7fd policy) | SDK uses explicit **`--dds-port`** with host forward (see oka `attach_dds_port_policy_test`); CI green ⇒ **`app.started` reached** (no attach-handshake failure artifact) |
| Marker pixels | `android_pixel_proof.json` **pass** — interior exact green 1.0 before/after stripe |
| Counter | 0 → 1, `counterRoiDiffPixels`: 3885 |
| CLI compression | `android_cli_capture_proof.json` **pass** — compress applied, marker stripe ok, `compressSmallerThanDriver: false` |
| Impeller | `android_renderer_verdict.json` **impeller** affirmative startup |
| Forwards during session | Pre-stop observation: **one** owned baseline forward line (`emulator-5554 tcp:33327 tcp:46037`) |
| Forwards after 10s | `forwardLinesAtEnd: []` |
| App on device | `fixtureAppStateAtEnd: not_running`, `deviceAppGoneAtEnd: true` |
| Host identities 10s | `trackedHostIdentitiesQuietAtEnd: true`, `windowElapsedMs`: 10141, 18 samples |
| SDK cleanup identity | `sessionCleanupIdentityMatch: true` (`android_session_cleanup_receipt.json`) |
| Harness verdict | `android_harness_proof.json` **pass**, `physicalSettlementOk: true` |
