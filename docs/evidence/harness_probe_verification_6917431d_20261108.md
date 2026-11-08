# Harness probe / loader verification record (2026-11-08)

**Tested code (immutable):** `6917431d423769918e0fc87c433a92d8daf89bc6`  
**Working tree during run:** clean (`git status --porcelain` exit **0**, `porcelain_sha256=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`, line count **0**)

Recorded **sequentially** (no concurrent `git add`/`commit`, no doc edits during commands). Full log:

`/cursor/stores/self/harness_probe_verification_exit_codes_6917431d_20261108.txt`

Runner script: `/cursor/stores/self/harness_probe_verification_sequential_6917431d_20261108.sh`

| Step | Command | Exit |
|------|---------|------|
| meta | `git rev-parse HEAD` | 0 |
| meta | `git status --porcelain` → sha256 | 0 |
| 1 | `dart analyze --fatal-infos packages/harness` | 0 |
| 2 | `dart test packages/harness --exclude-tags native-android,native-linux,compile-repro-opt-in` | 0 |
| 3 | `cd packages/harness && dart test --exclude-tags native-android,native-linux,compile-repro-opt-in` | 0 |

Harness unit: **128 passed**, **1 skipped** (native integration tag).

## SDK / native (unchanged)

- Consumer pin remains **`a92e818061…`**; purposeful native on remote **`f9ef84ef`** finished **red** (pre-proof attach); diag with SDK.
- SDK **`7fd1d5bf039cbbd0125683945c5273e83e7aac1b`** source-reviewed locally — **not** authorized repin; await final SDK CI (no polling this turn).
- **No merge/publish**; batch consumer repin only after reviewed SDK pin + green SDK CI.
