import 'dart:ui' show Offset, Size;

import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../../ai/backend/live_edit_backend_utils.dart';
import '../../di_live_edit_context/live_edit_context.dart';
import '../../types/live_edit_types.dart';
import '../shared/live_edit_selectors_shared.dart';

bool selectOverlayVisible(final LiveEditContext ctx) =>
    ctx.sessionResource.value.overlayVisible;

bool selectPanelExpanded(final LiveEditContext ctx) =>
    ctx.panelViewResource.value.panelDisplayMode ==
    LiveEditPanelDisplayMode.expanded;

double selectPanelWidth(final LiveEditContext ctx) {
  final pv = ctx.panelViewResource.value;
  return pv.panelDisplayMode == LiveEditPanelDisplayMode.expanded
      ? pv.panelExpandedWidth
      : pv.panelRailWidth;
}

double selectPanelHeight(final LiveEditContext ctx) {
  final pv = ctx.panelViewResource.value;
  return pv.panelDisplayMode == LiveEditPanelDisplayMode.expanded
      ? pv.panelExpandedHeight
      : pv.panelRailHeight;
}

Offset selectPanelPlacement(final LiveEditContext ctx, final Size viewport) =>
    clampPanelPlacement(
      placement:
          Offset(viewport.width - selectPanelWidth(ctx) - 16, 16) +
          ctx.panelViewResource.value.panelDragOffset,
      viewport: viewport,
      panelWidth: selectPanelWidth(ctx),
      panelHeight: selectPanelHeight(ctx),
    );

bool selectDebugModeEnabled(final LiveEditContext ctx) =>
    ctx.panelViewResource.value.debugModeEnabled;

bool selectDeeperPickEnabled(final LiveEditContext ctx) =>
    ctx.panelViewResource.value.deeperPickEnabled;

LiveEditTargetDomain selectPresentedLayer(final LiveEditContext ctx) {
  final domain = ctx.sessionResource.value.targetDomain;
  if (domain == LiveEditTargetDomain.toolScene &&
      !ctx.panelViewResource.value.toolPresentationArmed) {
    return LiveEditTargetDomain.appScene;
  }
  return domain;
}

LiveEditEditMode selectEditMode(final LiveEditContext ctx) =>
    selectLayerViewState(ctx, domain: selectPresentedLayer(ctx)).editMode;
