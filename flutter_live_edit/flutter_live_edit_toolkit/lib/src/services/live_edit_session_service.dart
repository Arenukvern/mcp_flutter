// ignore_for_file: invalid_use_of_protected_member, unused_element

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:live_edit_tooling_ui_kit/live_edit_tooling_ui_kit.dart';

import '../models/models.dart';
import '../resources/live_edit_draft.src.data.dart';
import '../resources/live_edit_selection.src.data.dart';
import '../resources/live_edit_session.src.data.dart';
import '../ui_workbench/live_edit_overlay_theme.dart';
import 'live_edit_session/lru_selection_cache.dart';
import 'live_edit_session_update.dart';

part 'live_edit_session/live_edit_session_hit_testing.dart';
part 'live_edit_session/live_edit_session_hit_testing_helpers.dart';
part 'live_edit_session/live_edit_session_service_core.dart';
part 'live_edit_session/live_edit_session_service_preview.dart';
part 'live_edit_session/live_edit_session_service_selection_commands.dart';
part 'live_edit_session/live_edit_session_state.dart';

final class LiveEditSessionService extends _LiveEditSessionServiceCore {
  LiveEditSessionService() : super();

  Map<String, Object?> startSession({
    final String? requestedSessionId,
    final LiveEditTargetDomain targetDomain = LiveEditTargetDomain.appScene,
  }) => _LiveEditSessionServiceSelectionCommands(this).startSession(
    requestedSessionId: requestedSessionId,
    targetDomain: targetDomain,
  );

  Map<String, Object?> setOverlay({
    required final bool enabled,
    final String? sessionId,
  }) => _LiveEditSessionServiceSelectionCommands(
    this,
  ).setOverlay(enabled: enabled, sessionId: sessionId);

  Map<String, Object?> startMarquee({
    required final int x,
    required final int y,
    final String? sessionId,
  }) => _LiveEditSessionServiceSelectionCommands(
    this,
  ).startMarquee(x: x, y: y, sessionId: sessionId);

  Map<String, Object?> updateMarquee({
    required final int x,
    required final int y,
    final String? sessionId,
    final int? viewId,
    final Element? contentRoot,
  }) => _LiveEditSessionServiceSelectionCommands(this).updateMarquee(
    x: x,
    y: y,
    sessionId: sessionId,
    viewId: viewId,
    contentRoot: contentRoot,
  );

  Map<String, Object?> commitMarquee({final String? sessionId}) =>
      _LiveEditSessionServiceSelectionCommands(
        this,
      ).commitMarquee(sessionId: sessionId);

  Map<String, Object?> cancelMarquee({final String? sessionId}) =>
      _LiveEditSessionServiceSelectionCommands(
        this,
      ).cancelMarquee(sessionId: sessionId);

  Map<String, Object?> selectCandidate({
    final String? sessionId,
    final int? index,
    final String? nodeId,
    final LiveEditTargetDomain? targetDomain,
  }) => _LiveEditSessionServiceSelectionCommands(this).selectCandidate(
    sessionId: sessionId,
    index: index,
    nodeId: nodeId,
    targetDomain: targetDomain,
  );

  Map<String, Object?> selectTrackedNode({
    required final String nodeId,
    final String? sessionId,
    final LiveEditTargetDomain? targetDomain,
  }) => _LiveEditSessionServiceSelectionCommands(this).selectTrackedNode(
    nodeId: nodeId,
    sessionId: sessionId,
    targetDomain: targetDomain,
  );

  Map<String, Object?> selectParent({
    final String? sessionId,
    final LiveEditTargetDomain? targetDomain,
  }) => _LiveEditSessionServiceSelectionCommands(
    this,
  ).selectParent(sessionId: sessionId, targetDomain: targetDomain);

  Map<String, Object?> selectChild({
    final String? sessionId,
    final LiveEditTargetDomain? targetDomain,
  }) => _LiveEditSessionServiceSelectionCommands(
    this,
  ).selectChild(sessionId: sessionId, targetDomain: targetDomain);

  Map<String, Object?> setTargetDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) => _LiveEditSessionServiceSelectionCommands(
    this,
  ).setTargetDomain(targetDomain: targetDomain, sessionId: sessionId);

  Map<String, Object?> updateDraft({
    required final LiveEditDraftChange change,
    final String? sessionId,
  }) => _LiveEditSessionServicePreview(
    this,
  ).updateDraft(change: change, sessionId: sessionId);

  Map<String, Object?> updateDraftBatch({
    required final List<String> nodeIds,
    required final String propertyId,
    required final Object? targetValue,
    required final LiveEditPreviewMode previewMode,
    required final String intentText,
    final DraftTargetContext? targetContext,
    final String? sessionId,
  }) => _LiveEditSessionServicePreview(this).updateDraftBatch(
    nodeIds: nodeIds,
    propertyId: propertyId,
    targetValue: targetValue,
    previewMode: previewMode,
    intentText: intentText,
    targetContext: targetContext,
    sessionId: sessionId,
  );
}
