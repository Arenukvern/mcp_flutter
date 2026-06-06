# Golden images — `flutter_test_app`

## `visual_reconstruct.png`

Reference frame for the **visual reconstruct** dogfood fixture (`VisualReconstructScreen`). Used by:

- Widget test: `test/visual_reconstruct_golden_test.dart`
- Harness warm path: `flutter_harness/.../warm_path_direct.hs.yaml` → `compare.reference`
- Guild compare in `tool/evals/run_dogfood_eval.sh` when `WS_URI` is set

## Regenerate

From **mcp_flutter** repo root:

```bash
cd flutter_test_app
flutter test test/visual_reconstruct_golden_test.dart --update-goldens
```

Commit the updated `test/goldens/visual_reconstruct.png` only when the UI change is intentional.

After updating the golden, re-run the warm path:

```bash
DOGFOOD_VISUAL=1 make web-showcase
export WS_URI='…'
bash tool/evals/run_dogfood_eval.sh --ws-uri "$WS_URI" --merge
```

## Live capture vs widget golden

The widget test renders at the test binding’s logical size (typically **800×600**, DPR **1.0**). Live Chrome capture (`screenshot_mode: flutter_layer`) depends on window size and DPR — see [docs/superpowers/evals/README.md](../../../docs/superpowers/evals/README.md) (viewport/DPR pinning). Warm dogfood uses `dogfood_warm.yaml`, not strict `default_guild.yaml`.
