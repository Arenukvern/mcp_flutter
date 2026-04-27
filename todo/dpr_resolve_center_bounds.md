# Latent DPR bug — `resolveCenter` / `resolveBounds` return physical-pixel coords

**Status:** open. Discovered while shipping P2 hover (commit `e798554` on `live-edit-v2-plannig`, 2026-04-27). Spawned as a follow-up task chip; this file durably records the bug for any agent picking up the work.

## Bug

`SemanticSnapshotService.resolveCenter(ref)` / `resolveBounds(ref)` (`mcp_toolkit/mcp_toolkit/lib/src/services/semantic_snapshot_service.dart`) accumulate the root `SemanticsNode`'s device-pixel-ratio (DPR) transform when computing global coordinates from the ref's cached center/bounds. They return **physical-pixel coordinates** instead of **logical / Flutter-space coordinates**.

With DPR=3.0 (the test default for `flutter_test`), a widget whose logical center is `(400, 300)` produces a `resolveCenter` of `(1200, 900)`. Synthesized pointer events sent at that location miss the widget by a factor of DPR.

## Production impact

Affects every gesture tool that consumes `resolveCenter` / `resolveBounds`:
- `tap_widget`
- `enter_text` (taps to focus before text entry)
- `scroll`
- `swipe`
- `drag`
- `long_press`
- `hover` (P2)

Maestro / MCP-driven flows on real devices with DPR > 1 (most modern phones, Retina Macs, 4K Linux desktops) may be silently misfiring. The existing tap/enter/scroll tests have been getting away with it — likely because `flutter_test`'s default viewport plus the test widgets' modest sizes happen to overlap the misfired coordinates with valid hit-target areas, or because the cached map/center was being cleared by the now-removed `_buildSnapshot` finally-clear before any test exercised resolve-after-snapshot.

## Reproducible workaround

The P2 hover test (`mcp_toolkit/mcp_toolkit/test/control_flow_service_test.dart`, around line 200) sets:

```dart
tester.view.devicePixelRatio = 1.0;
addTearDown(() => tester.view.resetDevicePixelRatio());
```

Without this, the hover test fails with `entered == false` because the synthesized pointer lands at `(1200, 900)` instead of the widget at `(400, 300)`.

## Where the bug lives

`mcp_toolkit/mcp_toolkit/lib/src/services/semantic_snapshot_service.dart`. The `_globalRect` (or equivalent) helper that converts a `SemanticsNode`'s rect to global coordinates walks up the parent chain and applies each `SemanticsNode.transform`, including the root view's DPR transform.

Three plausible fixes (pick one based on what's idiomatic in the codebase):
1. Skip the root SemanticsNode's transform in the walk.
2. Divide the final result by `view.devicePixelRatio`.
3. Use Flutter's logical-coord APIs for semantic node bounds instead of the transform chain (e.g. `RenderObject.localToGlobal` against the render tree directly).

## Acceptance criteria

1. `resolveCenter(ref)` returns logical (Flutter-space) coords on any DPR.
2. The `tester.view.devicePixelRatio = 1.0` workaround in `control_flow_service_test.dart` can be removed and the test still passes.
3. Add a regression test that builds a widget tree under `tester.view.devicePixelRatio = 3.0` (or some non-1.0 value), takes a snapshot, calls `resolveCenter(ref)`, and asserts the result is in logical coords (e.g. ≈ `tester.getCenter(find.byKey(...))`).
4. Manually verify all gesture tools (`tap_widget`, `enter_text`, `scroll`, `swipe`, `drag`, `long_press`, `hover`) still pass their existing tests after the fix.

## Branch policy

Independent of the Playwright-parity P0/P1/P2 series — branch off `main` (or off the last green commit) is fine. If you stack on `live-edit-v2-plannig`, no harm.

## Related docs

- P2 plan: `docs/superpowers/plans/2026-04-27-p2-fill-form-hover.md`
- Roadmap: `todo/playwright_parity_roadmap.md`
- Audit gap matrix: `todo/playwright_parity_audit.md` (the `hover` row references this file)
- Interaction-layer memory: `~/.claude/projects/-Users-antonio-mcp-cline-mcp-flutter/memory/project_mcp_flutter_interaction_layer.md` (Phase 8 section)
