// Pure candidate-ranking helpers extracted from the live-edit session
// service. See `todo/selection_state_machine.md` Phase 0.
//
// Currently this file publishes a public analogue of the existing
// ranking rule so tests and future callers can reason about it without
// reaching into `live_edit_session_hit_testing.dart` private helpers.
// The session service keeps its own copy for now; follow-up phases will
// fold its call sites onto these helpers.

/// Widget-type names that ordinarily wrap something more meaningful and
/// should lose candidate ranking ties to semantically-richer siblings.
const Set<String> kStructuralWidgetTypes = <String>{
  'Align',
  'Builder',
  'Center',
  'ColoredBox',
  'Column',
  'ConstrainedBox',
  'Container',
  'DecoratedBox',
  'DefaultTextStyle',
  'Expanded',
  'Flex',
  'Flexible',
  'IconTheme',
  'KeyedSubtree',
  'MediaQuery',
  'Padding',
  'Positioned',
  'RepaintBoundary',
  'RichText',
  'Row',
  'Semantics',
};

/// Classification signal for a hit candidate, used by [rankHitCandidate].
final class HitCandidateSignals {
  const HitCandidateSignals({
    required this.widgetType,
    this.infrastructureHit = false,
    this.hasStrongProjectOwnership = false,
    this.hasProjectHintSignal = false,
  });

  final String widgetType;
  final bool infrastructureHit;
  final bool hasStrongProjectOwnership;
  final bool hasProjectHintSignal;

  bool get isStructural => kStructuralWidgetTypes.contains(widgetType);
}

/// Returns a score for a single hit; higher is a better candidate.
///
/// Mirrors the scoring inside `_preferredSelectionIndex` in the legacy
/// `live_edit_session_hit_testing.dart` so tests have a stable
/// reference. Extracting both copies into one implementation is Phase 2+.
int rankHitCandidate(final HitCandidateSignals signals) {
  if (signals.infrastructureHit) {
    return -100;
  }
  if (signals.hasStrongProjectOwnership) {
    return 70;
  }
  if (signals.hasProjectHintSignal && !signals.isStructural) {
    return 50;
  }
  if (!signals.isStructural) {
    return 40;
  }
  return 0;
}

/// Pick the index with the highest [rankHitCandidate] score, breaking
/// ties by keeping the first occurrence (matches the legacy loop).
int preferredHitIndex(final List<HitCandidateSignals> signals) {
  if (signals.isEmpty) {
    return 0;
  }
  var bestIndex = 0;
  var bestRank = -1 << 31;
  for (var index = 0; index < signals.length; index += 1) {
    final rank = rankHitCandidate(signals[index]);
    if (rank > bestRank) {
      bestRank = rank;
      bestIndex = index;
    }
  }
  return bestIndex;
}
