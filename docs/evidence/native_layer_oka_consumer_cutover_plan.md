# Native layer capture — oka consumer cutover plan (blocked on immutable PR SHA)

**Status:** **Test pin active:** `tool/ci/oka_consumer_pin.txt` → `75153244c0357b04f730707c95bae98b8b29b7fd` (supersedes `32a1b69f…` / SDK `5ac6dea…`; cooperative `OkaLaunchedApp.stopSession` → `DevSessionStopReport`). Prior pins retained in CI logs as diagnostic only. **No merge, no publish** in either repo.

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

## SDK review caveat (consumer does not fix here)

Pinned SDK head adds core **fixture teardown bounded reaping**, CI **all-package test** failure collection, and harness **failed-launch TERM → 5s wait → KILL** plus bounded log stability drain. Independent re-review requested; **consumer CI not verified** on `32a1b69…` at pin move time.

TERM/KILL alone does **not** prove descendant/orphan cleanup (attach/forward/session leftovers). Native receipts must show **all owners settled** with honest failure bundles — preserve any evidence of survivors; do not claim settlement from unit fakes or parent kill alone.

## Out of scope here

- Editing oka source in `mcp_flutter/oka` (checkout is read-only pin only).
- Permanent pub release break or mutable `git clone` on `main`.
