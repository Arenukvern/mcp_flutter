# Harness `visual_supervisor` loader failure — diagnosis (2026-11-08)

## Symptom

```
Failed to load "packages/harness/tool/visual_supervisor_test.dart":
Top-level main() function takes arguments.
```

Observed when running `dart test packages/harness` from the workspace root (collects `packages/harness/**/_test.dart` under that path). The inventory command `cd packages/harness && dart test --exclude-tags …` does **not** walk `tool/` by default.

## Baseline (honest)

| Fact | Evidence |
|------|----------|
| Introduced in `9bfcea9a` as **on-device VM probe** | `Future<void> main(List<String> args)` + `LA_VM_URI`, same family as `tool/visual_probe.dart` |
| Misnamed `*_test.dart` under `packages/harness/tool/` | Only that probe used the suffix there |
| `dart test` loader contract | Test entrypoints cannot use `main(List<String> args)` |
| **`main` at same commit** | **Not verified** here — switching to `main` hit workspace **version solving** (`universal_automation_semantics` conflict) before `dart test` could load the file |

**Plausible pre-existing misname** (same file name/signature on `main` in git), **not** a same-command reproduction on `main` in this VM.

## Fix in local batch (unpushed)

1. Rename probe → `tool/visual_supervisor_probe.dart` (align with `visual_probe.dart`).
2. `test/visual_supervisor_probe_entry_test.dart` resolves **`packages/harness` via `Platform.script`**, not `Directory.current`, so both invocations pass.
3. **No** `dart_test.yaml` `paths:` change — redundant in-package and **ignored** for `dart test packages/harness` from repo root; attribution removed from earlier draft.

Probe logic (timeouts, semantic checks) unchanged. Manual run:

```bash
cd packages/harness
export LA_VM_URI='http://127.0.0.1:PORT/TOKEN/'
dart run tool/visual_supervisor_probe.dart /tmp/out
```

## Verified command exit statuses (clean tree at `a7ccced6`+fixes, no shell pipelines)

Recorded with `set -o pipefail` and **no** `| tail` on `dart test`:

| Command | Exit |
|---------|------|
| `dart analyze --fatal-infos packages/harness` | **0** |
| `dart test packages/harness --exclude-tags native-android,native-linux,compile-repro-opt-in` | **0** (128 tests; 1 skip) |
| `cd packages/harness && dart test --exclude-tags native-android,native-linux,compile-repro-opt-in` | **0** (128 tests; 1 skip) |

Log: `/cursor/stores/self/harness_probe_verification_exit_codes_20261108.txt`

## Related harness test fix (same batch)

`bounded_subprocess_stop_test.dart` SIG_IGN: `return` after `markTestSkipped` when `python3` absent on POSIX.

## `native_layer_proof.dart` (accidental `git reset --hard` / `clean`)

Transcript: **`packages/harness/tool/native_layer_proof.dart` was untracked local WIP**, removed by destructive reset — **not** on `origin/cursor/native-flutter-layer-capture-3399` at `f9ef84ef`. Tracked history exists only on older branch commits (e.g. `233a8094`) as a **manual VM proof script** (`dart run` + `LA_VM_URI`), not CI. **Consequence:** optional local scratch lost; **native proof remains** `test/integration/native_flutter_layer_capture_test.dart`. No further `reset --hard` / `clean` / stash juggling.

## Native / pin

Purposeful Android native on **`f9ef84ef`** + pin **`a92e818061…`** finished **red** (pre-proof attach/DDS); raw diag already with SDK. **No repin, merge, publish, or blind native rerun.**
