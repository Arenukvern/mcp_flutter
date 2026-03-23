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
    if (sid == null) return const <LiveEditDraftChange>[];
    final byDomain = _context.draftResource.value[sid];
    if (byDomain == null) return const <LiveEditDraftChange>[];
    return byDomain[targetDomain]?.draftChanges ??
        const <LiveEditDraftChange>[];
  }

  LiveEditSelection? hoverSelectionForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) {
    final sid = sessionId ?? _context.sessionResource.value.activeSessionId;
    if (sid == null) return null;
    final byDomain = _context.selectionResource.value[sid];
    if (byDomain == null) return null;
    return byDomain[targetDomain]?.hoverSelection;
  }

  Rect? marqueeRectForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) {
    final sid = sessionId ?? _context.sessionResource.value.activeSessionId;
    if (sid == null) return null;
    final byDomain = _context.selectionResource.value[sid];
    if (byDomain == null) return null;
    return byDomain[targetDomain]?.marqueeRect;
  }

  List<LiveEditSelection> marqueeSelectionsForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) {
    final sid = sessionId ?? _context.sessionResource.value.activeSessionId;
    if (sid == null) return const <LiveEditSelection>[];
    final byDomain = _context.selectionResource.value[sid];
    if (byDomain == null) return const <LiveEditSelection>[];
    return byDomain[targetDomain]?.marqueeSelections ??
        const <LiveEditSelection>[];
  }

  List<LiveEditSelection> multiSelectionForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) {
    final sid = sessionId ?? _context.sessionResource.value.activeSessionId;
    if (sid == null) return const <LiveEditSelection>[];
    final byDomain = _context.selectionResource.value[sid];
    if (byDomain == null) return const <LiveEditSelection>[];
    return byDomain[targetDomain]?.multiSelections ??
        const <LiveEditSelection>[];
  }

  LiveEditSelection? selectionForDomain({
    required final LiveEditTargetDomain targetDomain,
    final String? sessionId,
  }) {
    final sid = sessionId ?? _context.sessionResource.value.activeSessionId;
    if (sid == null) return null;
    final byDomain = _context.selectionResource.value[sid];
    if (byDomain == null) return null;
    return byDomain[targetDomain]?.selection;
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
    if (sid == null) return const <LiveEditSelectionCandidate>[];
    final byDomain = _context.selectionResource.value[sid];
    if (byDomain == null) return const <LiveEditSelectionCandidate>[];
    return byDomain[targetDomain]?.selectionCandidates ??
        const <LiveEditSelectionCandidate>[];
  }
}
