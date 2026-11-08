# Harness `visual_supervisor` loader failure — diagnosis (2026-11-08)

## Symptom

```
Failed to load "packages/harness/tool/visual_supervisor_test.dart":
Top-level main() function takes arguments.
```

Observed when running `dart test packages/harness` from the workspace root (not the inventory command).

## Baseline (coherent graph)

| Fact | Evidence |
|------|----------|
| Introduced in `9bfcea9a` as **on-device VM probe**, same pattern as `tool/visual_probe.dart` | `Future<void> main(List<String> args)` + `LA_VM_URI` |
| Misnamed `*_test.dart` under `tool/` | Only probe in `tool/` using test suffix |
| `dart test` contract | Test entrypoints must be `void main()` / `void main() async` **without required parameters** |
| Inventory script | `cd packages/harness && dart test --exclude-tags …` only scanned `test/` by default → **did not** hit `tool/` until root-path invocation |

**Not a regression from native-layer PR `f9ef84ef`** — same loader error on `main` at `9bfcea9a..HEAD` before fix.

## External prerequisite (preserved)

Automations pane visual acceptance (ADR-0041 §6) still runs manually:

```bash
cd packages/harness
export LA_VM_URI='http://127.0.0.1:PORT/TOKEN/'
dart run tool/visual_supervisor_probe.dart /tmp/out
```

All step logic, timeouts, and semantic assertions remain in `tool/visual_supervisor_probe.dart` (renamed from `visual_supervisor_test.dart`).

## Fix in PR

1. Rename probe → `visual_supervisor_probe.dart` (align with `visual_probe.dart`).
2. `dart_test.yaml` `paths: [test]` so `dart test packages/harness` cannot collect `tool/`.
3. `test/visual_supervisor_probe_entry_test.dart` guards naming contract + documents `dart run` entry.

## Approval

Attach/native proof unchanged — **no merge/publish** on this doc alone.
