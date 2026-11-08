# Native layer capture — oka consumer cutover plan (blocked on immutable PR SHA)

**Status:** **Provisional test pin:** `tool/ci/oka_consumer_pin.txt` → **`469b0d55298035c9e896a49474df89a06680380b`** (oka PR #18; full 40-char SHA only). Supersedes `f41b0d64…`, `f339a359…`, `75153244…`. SDK stop: `app.stop` best-effort ≤10s (ignores failure), then `daemon.shutdown`/transport kill in `finally`; **no `adb forward --remove`**. Harness: read-only 10s settlement poll + artifact sha256 bindings; `provenOwnedResourceSettlement` always **false** (runner contract only). Consumer: `launchOka()` + spawn binding + `stopSession` (no generic `LaunchedApp.stop` on Android; **no consumer kills/forward cleanup**). **Independent SDK delta re-review in flight** — not final approval. **No merge, no publish** in either repo.

**`32a1b69f` oka_core full suite correction:** single failing test was **`storage_inventory_test.dart`** (mtime ordering), not `project_operations/` — the `251 ~1 -1` counter is **cumulative across the suite**, not a second `project_operations` failure. See `/cursor/stores/self/artifacts/oka_core-consumer-repro-notes-32a1b69.md`.

## Defect (confirmed)

- **`oka_harness` 0.9.1 `AndroidAppTarget`:** child argv `dev [--device …]` without positional **`android`**.
- **`oka` 0.9.1 CLI:** `DevCommand` routes non-`android` `dev` to kernel stack; **`oka dev android …`** writes `.flutter_mcp/runner-session.json`.

## Consumer integration (after SHA is provided)

1. **Pin (test/CI only, documented):** single source `tool/ci/oka_consumer_pin.txt` → checkout + path overrides + `OKA_BIN` from `dart pub global activate --source path oka/packages/oka` (not `main`, not a guessed tag).
2. **Deps alignment:** bump `oka_harness` / `oka_android` in `packages/harness/pubspec.yaml` to the **same monorepo revision** as the CLI pin (path/git ref in workspace only until parent publishes).
3. **Remove shell workarounds:** no `oka_dev_android.sh` or argv-rewrite scripts; `AndroidAppTarget(okaBin: Platform.environment['OKA_BIN'] ?? 'oka')` only.
4. **Verification gate:** Android native job runs only when pin env is set to the approved SHA artifact; first green must show capture PNGs + `runner-session.json` + honest Impeller log, not timeout-only artifacts.
5. **Artifacts:** `android_oka_dev_launch_intent.json` must show `supportedOkaCliArgv` matches actual child argv after SDK fix.

## What this branch does until SHA exists

- Linux native proof: `runBounded` + `app.stop` machine parser (`4d9f5a23`).
- Failure bundles + argv diagnostics (honest routing documentation).
- **Android integration enabled in CI but expected fail** on hosted 0.9.1 until pin lands — **no blind reruns** for green.

## Coherent graph (fixture + harness)

`tool/ci/apply_oka_consumer_overrides.sh` overrides **every** `oka/packages/*` pub package (incl. `resource_composition`, `oka_core`, `oka_android`, `oka_harness`, transitive oka members) so neither harness tests nor fixture `tool/oka_pipeline.dart` (`dart run` / `oka build`) mixes hosted 0.9.1 with path sources. `tool/ci/report_oka_consumer_provenance.sh` records checkout HEAD + `dart pub deps` for parent review.

**CLI:** `dart pub global activate --source path oka/packages/oka` at the pinned checkout — not `dart pub global activate oka` from pub.dev.

**Fixture pipeline:** `steps: [...AndroidPipeline.defaultSteps]` only — no manual `RecordRunSessionStep` (pinned `defaultSteps` includes recorder).

**CI emulator ABI:** `native_flutter_layer_capture` sets `OKA_ANDROID_BUILD_ABI=x86_64` for prebuild + integration so `app-debug.apk` matches the `pixel_6` x86_64 AVD (`INSTALL_FAILED_NO_MATCHING_ABIS` otherwise).

**CI emulator readiness (consumer, not SDK):** enable `/dev/kvm` via `tool/ci/enable_android_emulator_kvm.sh` (reactivecircus docs). Integration polls `adb shell pm path com.android.shell` before `oka dev android` (fail-closed `android_emulator_readiness.json`); `sys.boot_completed` alone is insufficient on API 34 GHA images.

## SDK cooperative-stop review blockers (`75153244` / follow-up `f339a35`)

Still under independent re-review on `f339a35` until cleared:

| Finding | Consumer stance |
|--------|------------------|
| Fatal **lint CI** on oka | Fix in oka; do not patch consumer to greenwash |
| Cooperative **TCP EOF/ack race** on `requestQuit` | Real TCP lifecycle tests required (today’s fakes exercise stdin only) |
| **`stdin` quit write** counted as `controlQuitAcknowledged` | SDK must not label acknowledged without verified ack |
| **`DevSessionStopReport.ok`** | **Only** owning-child exit + `runner-session` discovery cleared — **not** adb forward, device app PID, attach children |
| **`AndroidAppTarget` API break** | `launchOka()` + spawn binding on `f339a35`; `launch()` compat only |

**Physical settlement:** consumer retains read-only `android_owned_physical_observations.json`; `provenOwnedResourceSettlement` stays **false** until observations + SDK receipts are reviewed together — **exit 0 + file absent alone are insufficient**.

**Prior native runs** (`900c5a80`, `684e8850`, `5d0d5d8f`, `dde9a7c5`): diagnostic archives only until SDK re-review clears cooperative-stop blockers.

## SDK review caveat (consumer does not fix here)

Pinned SDK head adds core **fixture teardown bounded reaping**, CI **all-package test** failure collection, and harness **failed-launch TERM → 5s wait → KILL** plus bounded log stability drain. Independent re-review requested; **consumer CI not verified** on `32a1b69…` at pin move time.

TERM/KILL alone does **not** prove descendant/orphan cleanup (attach/forward/session leftovers). Native receipts must show **all owners settled** with honest failure bundles — preserve any evidence of survivors; do not claim settlement from unit fakes or parent kill alone.

## Out of scope here

- Editing oka source in `mcp_flutter/oka` (checkout is read-only pin only).
- Permanent pub release break or mutable `git clone` on `main`.
