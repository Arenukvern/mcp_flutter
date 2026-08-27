import 'package:flutter/foundation.dart' show visibleForTesting;

import 'gesture_interaction_service.dart';
import 'semantic_snapshot_service.dart';

/// Bounded semantic reveal/search helper for targets that may start off-screen.
///
/// This is intentionally not a general selector engine. It matches one query
/// against one narrow semantics field mode, scrolling between fresh snapshots.
mixin RevealSearchService {
  static const int _defaultMaxAttempts = 5;
  static const int _maxAttemptsLimit = 10;
  static const double _defaultDistance = 300;
  static const double _maxDistance = 2000;

  static Future<Map<String, Object?>> revealSearch({
    required final String query,
    final String matchBy = 'text',
    final String direction = 'down',
    final int maxAttempts = _defaultMaxAttempts,
    final double distance = _defaultDistance,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return <String, Object?>{
        'success': false,
        'error': 'missing_query',
        'hint':
            'reveal_search needs something to look for. Pass the text a node '
            'shows, or its identifier together with matchBy: "identifier".',
        'attempts': const <Object?>[],
      };
    }

    final normalizedMatchBy = _normalizeMatchBy(matchBy);
    final boundedMaxAttempts = maxAttempts.clamp(0, _maxAttemptsLimit);
    final boundedDistance = distance.clamp(1, _maxDistance).toDouble();
    final attempts = <Map<String, Object?>>[];
    Map<String, Object?>? lastSnapshot;

    for (var attempt = 0; attempt <= boundedMaxAttempts; attempt++) {
      final snapshot = await SemanticSnapshotService.buildSemanticSnapshot();
      lastSnapshot = snapshot;
      final match = _findMatch(
        snapshot: snapshot,
        query: normalizedQuery,
        matchBy: normalizedMatchBy,
      );

      final trace = <String, Object?>{
        'attempt': attempt,
        'snapshotId': snapshot['snapshot_id'],
        'nodeCount': snapshot['nodeCount'],
        'found': match != null,
      };
      if (match != null) {
        trace
          ..['ref'] = match['ref']
          ..['visibleInViewport'] = match['visibleInViewport']
          ..['centerInViewport'] = match['centerInViewport'];
      }
      attempts.add(trace);

      if (match != null && match['centerInViewport'] == true) {
        return <String, Object?>{
          'success': true,
          'ref': match['ref'],
          'snapshotId': snapshot['snapshot_id'],
          'match': match,
          'visibleInViewport': match['visibleInViewport'],
          'centerInViewport': match['centerInViewport'],
          'viewport': snapshot['viewport'],
          'query': normalizedQuery,
          'matchBy': normalizedMatchBy,
          'attempts': attempts,
        };
      }

      if (attempt == boundedMaxAttempts) {
        if (match != null) {
          return _foundButNotActionableResult(
            snapshot: snapshot,
            match: match,
            query: normalizedQuery,
            matchBy: normalizedMatchBy,
            direction: direction,
            maxAttempts: boundedMaxAttempts,
            distance: boundedDistance,
            attempts: attempts,
          );
        }
        break;
      }

      final scroll = await GestureInteractionService.scroll(
        direction: direction,
        distance: boundedDistance,
      );
      trace['scroll'] = scroll;
      if (scroll['success'] != true) {
        if (_shouldContinueAfterScroll(scroll)) {
          continue;
        }
        if (match != null) {
          return _foundButNotActionableResult(
            snapshot: snapshot,
            match: match,
            query: normalizedQuery,
            matchBy: normalizedMatchBy,
            direction: direction,
            maxAttempts: boundedMaxAttempts,
            distance: boundedDistance,
            attempts: attempts,
          );
        }
        return <String, Object?>{
          'success': false,
          'error': 'scroll_blocked',
          'scrollError': scroll['error'],
          'hint':
              'The search stopped early: scrolling "$direction" moved nothing, '
              'so further attempts would re-read the same screen. The list is '
              'already at that edge — search the other direction — or the '
              'point being scrolled is not over the list; see scrollError.',
          'query': normalizedQuery,
          'matchBy': normalizedMatchBy,
          'direction': direction,
          'maxAttempts': boundedMaxAttempts,
          'distance': boundedDistance,
          'snapshotId': snapshot['snapshot_id'],
          'attempts': attempts,
        };
      }
    }

    return <String, Object?>{
      'success': false,
      'error': 'target_not_found',
      'hint':
          'Nothing matched "$normalizedQuery" by $normalizedMatchBy across '
          '${attempts.length} screens. The text may be split across nodes or '
          'rendered without semantics — call semantic_snapshot and read what '
          'the screen actually publishes, or raise maxAttempts if the target '
          'sits further than '
          '${(boundedMaxAttempts * boundedDistance).round()} px away.',
      'query': normalizedQuery,
      'matchBy': normalizedMatchBy,
      'direction': direction,
      'maxAttempts': boundedMaxAttempts,
      'distance': boundedDistance,
      'snapshotId': lastSnapshot?['snapshot_id'],
      'attempts': attempts,
    };
  }

  static Map<String, Object?> _foundButNotActionableResult({
    required final Map<String, Object?> snapshot,
    required final Map<String, Object?> match,
    required final String query,
    required final String matchBy,
    required final String direction,
    required final int maxAttempts,
    required final double distance,
    required final List<Map<String, Object?>> attempts,
  }) => <String, Object?>{
    'success': false,
    'error': 'target_not_actionable',
    'actionable': false,
    'ref': match['ref'],
    'snapshotId': snapshot['snapshot_id'],
    'match': match,
    'visibleInViewport': match['visibleInViewport'],
    'centerInViewport': match['centerInViewport'],
    'viewport': snapshot['viewport'],
    'recommendedNextAction': 'scroll_more',
    'hint':
        'The target is in the tree but its centre is still outside the '
        'viewport, so a gesture aimed at it would land off screen. Call '
        'reveal_search again with a larger maxAttempts or distance; the ref '
        'returned here is good for reading, not for tapping.',
    'query': query,
    'matchBy': matchBy,
    'direction': direction,
    'maxAttempts': maxAttempts,
    'distance': distance,
    'attempts': attempts,
  };

  static Map<String, Object?>? _findMatch({
    required final Map<String, Object?> snapshot,
    required final String query,
    required final String matchBy,
  }) {
    final nodes = snapshot['nodes'];
    if (nodes is! List) return null;
    for (final rawNode in nodes) {
      if (rawNode is! Map) continue;
      final node = rawNode.cast<String, Object?>();
      if (_matches(node: node, query: query, matchBy: matchBy)) {
        return Map<String, Object?>.from(node);
      }
    }
    return null;
  }

  static bool _matches({
    required final Map<String, Object?> node,
    required final String query,
    required final String matchBy,
  }) {
    final normalizedQuery = query.toLowerCase();
    return switch (matchBy) {
      'identifier' => _equalsField(node['identifier'], query),
      'label' => _containsField(node['label'], normalizedQuery),
      'value' => _containsField(node['value'], normalizedQuery),
      'hint' => _containsField(node['hint'], normalizedQuery),
      _ =>
        _containsField(node['label'], normalizedQuery) ||
            _containsField(node['value'], normalizedQuery) ||
            _containsField(node['hint'], normalizedQuery),
    };
  }

  static bool _equalsField(final Object? value, final String query) =>
      value is String && value.trim() == query;

  static bool _containsField(
    final Object? value,
    final String normalizedQuery,
  ) => value is String && value.toLowerCase().contains(normalizedQuery);

  static String _normalizeMatchBy(final String matchBy) {
    final normalized = matchBy.trim().toLowerCase();
    return switch (normalized) {
      'identifier' || 'label' || 'value' || 'hint' => normalized,
      _ => 'text',
    };
  }

  @visibleForTesting
  static bool shouldContinueAfterScrollForTesting(
    final Map<String, Object?> scroll,
  ) => _shouldContinueAfterScroll(scroll);

  @visibleForTesting
  static Map<String, Object?> foundButNotActionableResultForTesting({
    required final Map<String, Object?> snapshot,
    required final Map<String, Object?> match,
    required final String query,
    required final String matchBy,
    required final String direction,
    required final int maxAttempts,
    required final double distance,
    required final List<Map<String, Object?>> attempts,
  }) => _foundButNotActionableResult(
    snapshot: snapshot,
    match: match,
    query: query,
    matchBy: matchBy,
    direction: direction,
    maxAttempts: maxAttempts,
    distance: distance,
    attempts: attempts,
  );

  static bool _shouldContinueAfterScroll(final Map<String, Object?> scroll) {
    if (scroll['deferredMovementCheck'] == true) return true;
    if (scroll['movementVerified'] == true) return true;
    return false;
  }
}
