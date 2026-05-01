# DPR and semantic snapshot bounds / `resolveCenter`

## Symptom

On displays with **device pixel ratio (DPR) > 1** (Retina Macs, most phones), taps and other synthesized pointer events driven by `SemanticSnapshotService.resolveCenter` / `resolveBounds` could **miss the target widget** by roughly a factor of DPR along each axis.

## Root cause

`SemanticSnapshotService` records each node’s rect by walking **parent transforms** and applying them with `MatrixUtils.transformRect`:

- Each `SemanticsNode` has a `rect` in its local space.
- Walking to the root and multiplying transforms yields a rect in the coordinate space the engine uses along that chain.

On the path to the root, an ancestor semantics node carries the **viewport / view scaling** that corresponds to **physical pixels** (the engine’s DPR scale). The accumulated rect is therefore in **physical** coordinates while Flutter’s hit testing and `WidgetTester` helpers (e.g. `getCenter`, `getRect`) work in **logical** pixels.

Using those physical numbers for `GestureBinding` / `TestGesture` injection without converting them meant events were sent at coordinates that looked “zoomed” relative to the real widget.

## Fix (current behavior)

`_globalRect` still accumulates transforms the same way, then **divides LTRB by `WidgetsBinding.instance.renderViews.first.flutterView.devicePixelRatio`** when DPR ≠ 1, so cached bounds and centers stay in **logical Flutter space** and match `resolveCenter` / `resolveBounds` consumers (`GestureInteractionService`, tests).

Implementation: `mcp_toolkit/mcp_toolkit/lib/src/services/semantic_snapshot_service.dart` (`_globalRect`).

## Regression test

`mcp_toolkit/mcp_toolkit/test/semantic_snapshot_dpr_test.dart` pumps at DPR 1, 2, and 3 and asserts snapshot-resolved center and bounds match `tester.getCenter` / `tester.getRect` within tolerance.

## Notes

- The division assumes the same DPR applies across the snapshot’s coordinate space as reported by the primary `FlutterView`; that matches the common single-view app case this toolkit targets.
- If multi-window / multi-view semantics ever need first-class support, revisit whether DPR should be resolved per-view instead of `renderViews.first`.
