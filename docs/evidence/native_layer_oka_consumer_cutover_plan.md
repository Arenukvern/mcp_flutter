# Native layer capture — oka consumer cutover plan (blocked on immutable PR SHA)

**Status:** **Test pin active:** `tool/ci/oka_consumer_pin.txt` → `7416849a14cf817217e6fd84c305d5f1529b7c41` ([oka PR #18](https://github.com/Arenukvern/oka/pull/18), unmerged). **No merge, no publish** in either repo.

## Defect (confirmed)

- **`oka_harness` 0.9.1 `AndroidAppTarget`:** child argv `dev [--device …]` without positional **`android`**.
- **`oka` 0.9.1 CLI:** `DevCommand` routes non-`android` `dev` to kernel stack; **`oka dev android …`** writes `.flutter_mcp/runner-session.json`.

## Consumer integration (after SHA is provided)

1. **Pin (test/CI only, documented):** set `OKA_BIN` to the oka monorepo-built CLI at the **exact commit SHA** (not `main`, not a guessed tag). Record in `.github/workflows/native_flutter_layer_capture.yml` and/or steward probe metadata:
   - `OKA_CONSUMER_PIN_SHA=<parent-supplied>`
   - `OKA_BIN=<path-on-CI-after-checkout@SHA>`
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

## SDK review caveat (consumer does not fix here)

`oka_harness` launch-failure paths may not await/escalate child process death; do not treat pgrep-style or timeout-only cleanup as proof of settlement. Native receipts must show **all owners settled** (bounded UTR / oka session / device app) with honest failure bundles — not claims from unit fakes alone.

## Out of scope here

- Editing oka source in `mcp_flutter/oka` (checkout is read-only pin only).
- Permanent pub release break or mutable `git clone` on `main`.
