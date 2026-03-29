import 'dart:ui' show Rect;

import '../../models/models.dart';
import '../live_edit_context.dart';

/// Exposes session/selection/draft data from [LiveEditContext] for host code
/// that expects a "controller" with domain-scoped getters.
final class LiveEditController {
  LiveEditController(this._context);

  final LiveEditContext _context;

  List<LiveEditDraftChange> draftChangesForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) {
    final sid = sessionId ?? _context.sessionResource.value.activeSessionId;
    return _context.draftResource.value
        .layerFor(sid, targetDomain)
        .draftChanges;
  }

  LiveEditSelection? hoverSelectionForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) {
    final sid = sessionId ?? _context.sessionResource.value.activeSessionId;
    return _context.selectionResource.value
        .layerFor(sid, targetDomain)
        .hoverSelection;
  }

  Rect? marqueeRectForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) {
    final sid = sessionId ?? _context.sessionResource.value.activeSessionId;
    return _context.selectionResource.value
        .layerFor(sid, targetDomain)
        .marqueeRect;
  }

  List<LiveEditSelection> marqueeSelectionsForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) {
    final sid = sessionId ?? _context.sessionResource.value.activeSessionId;
    return _context.selectionResource.value
        .layerFor(sid, targetDomain)
        .marqueeSelections;
  }

  List<LiveEditSelection> multiSelectionForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) {
    final sid = sessionId ?? _context.sessionResource.value.activeSessionId;
    return _context.selectionResource.value
        .layerFor(sid, targetDomain)
        .multiSelections;
  }

  LiveEditSelection? selectionForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) {
    final sid = sessionId ?? _context.sessionResource.value.activeSessionId;
    return _context.selectionResource.value
        .layerFor(sid, targetDomain)
        .selection;
  }

  LiveEditSelection? get hoverSelection => hoverSelectionForDomain(
    targetDomain: _context.sessionResource.value.targetDomain,
    sessionId: _context.sessionResource.value.activeSessionId,
  );

  Rect? get marqueeRect => marqueeRectForDomain(
    targetDomain: _context.sessionResource.value.targetDomain,
    sessionId: _context.sessionResource.value.activeSessionId,
  );

  List<LiveEditSelectionCandidate> selectionCandidatesForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) {
    final sid = sessionId ?? _context.sessionResource.value.activeSessionId;
    return _context.selectionResource.value
        .layerFor(sid, targetDomain)
        .selectionCandidates;
  }
}
