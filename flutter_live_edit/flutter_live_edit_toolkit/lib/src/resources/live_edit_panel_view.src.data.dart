import 'package:flutter/material.dart' show Offset;
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../types/live_edit_types.dart';

/// Sentinel for [LiveEditPanelViewResourceData.copyWith] — omit `lastSelectionIdentity` to keep prior value.
const _kOmitLastSelectionIdentity = _OmitLastSelectionIdentity();

class _OmitLastSelectionIdentity {
  const _OmitLastSelectionIdentity();
}

/// Panel and view preferences.
final class LiveEditPanelViewResourceData {
  const LiveEditPanelViewResourceData({
    this.editMode = LiveEditEditMode.inspect,
    this.panelDisplayMode = LiveEditPanelDisplayMode.rail,
    this.bubbleWidth = 390,
    this.bubbleHeight = 280,
    this.panelExpandedWidth = 312,
    this.panelExpandedHeight = 520,
    this.panelRailWidth = 64,
    this.panelRailHeight = 420,
    this.panelDragOffset = Offset.zero,
    this.debugModeEnabled = false,
    this.deeperPickEnabled = false,
    this.toolPresentationArmed = false,
    this.lastSelectionIdentity,
  });

  final LiveEditEditMode editMode;
  final LiveEditPanelDisplayMode panelDisplayMode;
  final double bubbleWidth;
  final double bubbleHeight;
  final double panelExpandedWidth;
  final double panelExpandedHeight;
  final double panelRailWidth;
  final double panelRailHeight;
  final Offset panelDragOffset;
  final bool debugModeEnabled;
  final bool deeperPickEnabled;
  final bool toolPresentationArmed;
  final String? lastSelectionIdentity;

  static const LiveEditPanelViewResourceData initial =
      LiveEditPanelViewResourceData();

  LiveEditPanelViewResourceData copyWith({
    final LiveEditEditMode? editMode,
    final LiveEditPanelDisplayMode? panelDisplayMode,
    final double? bubbleWidth,
    final double? bubbleHeight,
    final double? panelExpandedWidth,
    final double? panelExpandedHeight,
    final double? panelRailWidth,
    final double? panelRailHeight,
    final Offset? panelDragOffset,
    final bool? debugModeEnabled,
    final bool? deeperPickEnabled,
    final bool? toolPresentationArmed,
    final Object? lastSelectionIdentity = _kOmitLastSelectionIdentity,
  }) => LiveEditPanelViewResourceData(
    editMode: editMode ?? this.editMode,
    panelDisplayMode: panelDisplayMode ?? this.panelDisplayMode,
    bubbleWidth: bubbleWidth ?? this.bubbleWidth,
    bubbleHeight: bubbleHeight ?? this.bubbleHeight,
    panelExpandedWidth: panelExpandedWidth ?? this.panelExpandedWidth,
    panelExpandedHeight: panelExpandedHeight ?? this.panelExpandedHeight,
    panelRailWidth: panelRailWidth ?? this.panelRailWidth,
    panelRailHeight: panelRailHeight ?? this.panelRailHeight,
    panelDragOffset: panelDragOffset ?? this.panelDragOffset,
    debugModeEnabled: debugModeEnabled ?? this.debugModeEnabled,
    deeperPickEnabled: deeperPickEnabled ?? this.deeperPickEnabled,
    toolPresentationArmed: toolPresentationArmed ?? this.toolPresentationArmed,
    lastSelectionIdentity:
        identical(lastSelectionIdentity, _kOmitLastSelectionIdentity)
        ? this.lastSelectionIdentity
        : lastSelectionIdentity as String?,
  );
}
