# Native layer capture — oka consumer cutover plan (blocked on immutable PR SHA)

**Status:** HOLD Android native proof until parent supplies **one immutable git commit** from the focused oka SDK fix workstream. **No merge, no publish** in either repo from this branch alone.

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

## Out of scope here

- Building or patching oka upstream in `mcp_flutter`.
- Permanent pub release break or mutable `git clone` on `main`.
