import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:from_json_to_json/from_json_to_json.dart';

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
        'attempts': const <Object?>[],
      };
    }

    final normalizedMatchBy = _normalizeMatchBy(matchBy);
    final boundedMaxAttempts = jsonDecodeInt(
      maxAttempts.clamp(0, _maxAttemptsLimit),
    );
    final boundedDistance = jsonDecodeDouble(distance.clamp(1, _maxDistance));
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
    'warning': 'Target was found but its center is outside the viewport.',
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
