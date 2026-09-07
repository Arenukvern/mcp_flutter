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
    // Every identifier any screen of the search published, so a miss can name
    // what was there instead of the one asked for.
    final identifiersSeen = <String>{};

    for (var attempt = 0; attempt <= boundedMaxAttempts; attempt++) {
      final snapshot = await SemanticSnapshotService.buildSemanticSnapshot();
      lastSnapshot = snapshot;
      identifiersSeen.addAll(_identifiersOf(snapshot));
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
          ..['centerInViewport'] = match['centerInViewport']
          // How far the target still sits outside the viewport. Recorded per
          // attempt so the refusal can tell "not scrolled far enough" from
          // "the scrolling is not moving this target at all".
          ..['outsideViewportBy'] = _outsideViewportBy(
            match: match,
            viewport: snapshot['viewport'],
          );
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

      // Scroll the list the target lives in, not whatever sits under the
      // screen centre. In a shell those are different widgets, and scrolling
      // the second one moves the page while leaving the target exactly where
      // it was — every attempt reporting success.
      final scroll = await GestureInteractionService.scroll(
        ref: match?['ref']?.toString(),
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
              'point being scrolled is not over the list; see scrollError. '
              '${_missHint(query: normalizedQuery, matchBy: normalizedMatchBy, identifiersSeen: identifiersSeen)}',
          'query': normalizedQuery,
          'matchBy': normalizedMatchBy,
          ..._missDetails(
            query: normalizedQuery,
            matchBy: normalizedMatchBy,
            identifiersSeen: identifiersSeen,
          ),
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
          '${attempts.length} screens. '
          '${_missHint(query: normalizedQuery, matchBy: normalizedMatchBy, identifiersSeen: identifiersSeen)} '
          'Raise maxAttempts if the target sits further than '
          '${(boundedMaxAttempts * boundedDistance).round()} px away.',
      'query': normalizedQuery,
      'matchBy': normalizedMatchBy,
      ..._missDetails(
        query: normalizedQuery,
        matchBy: normalizedMatchBy,
        identifiersSeen: identifiersSeen,
      ),
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
  }) {
    final approached = _targetApproached(attempts);
    final scrolled = _lastScrolledNode(attempts);
    final anyScrollFailed = attempts.any(
      (final attempt) => _asMap(attempt['scroll'])?['success'] == false,
    );
    return <String, Object?>{
      'success': false,
      'error': 'target_not_actionable',
      'actionable': false,
      'ref': match['ref'],
      'snapshotId': snapshot['snapshot_id'],
      'match': match,
      'visibleInViewport': match['visibleInViewport'],
      'centerInViewport': match['centerInViewport'],
      'viewport': snapshot['viewport'],
      'recommendedNextAction': approached
          ? 'scroll_more'
          : 'scroll_other_widget',
      'movedCloser': approached,
      'scrolledNode': ?scrolled,
      'hint': approached
          ? 'The target is in the tree but its centre is still outside the '
                'viewport, so a gesture aimed at it would land off screen. Call '
                'reveal_search again with a larger maxAttempts or distance; the '
                'ref returned here is good for reading, not for tapping.'
          : '${anyScrollFailed ? 'No attempted scroll moved the target closer, and at least one reported failure (see attempts[*].scroll)' : 'Every scroll succeeded and the target never moved closer'}, so '
                'repeating them will not reveal it: what is being scrolled '
                '${scrolled == null ? 'is not the list holding the target' : 'is node $scrolled, not the list holding the target'}. '
                'Call semantic_snapshot, find the scrollable whose children '
                'include this ref, and scroll that node by its own ref.',
      'query': query,
      'matchBy': matchBy,
      'direction': direction,
      'maxAttempts': maxAttempts,
      'distance': distance,
      'attempts': attempts,
    };
  }

  /// How far [match]'s centre sits outside [viewport], in logical pixels.
  ///
  /// Zero once the centre is inside — the condition a gesture needs before it
  /// can aim at the target.
  static double? _outsideViewportBy({
    required final Map<String, Object?> match,
    required final Object? viewport,
  }) {
    final center = _asMap(match['center']);
    final box = _asMap(viewport);
    if (center == null || box == null) return null;
    final x = _asDouble(center['x']);
    final y = _asDouble(center['y']);
    final left = _asDouble(box['left']);
    final top = _asDouble(box['top']);
    final right = _asDouble(box['right']);
    final bottom = _asDouble(box['bottom']);
    if (x == null ||
        y == null ||
        left == null ||
        top == null ||
        right == null ||
        bottom == null) {
      return null;
    }
    final horizontal = x < left
        ? left - x
        : x > right
        ? x - right
        : 0.0;
    final vertical = y < top
        ? top - y
        : y > bottom
        ? y - bottom
        : 0.0;
    return horizontal > vertical ? horizontal : vertical;
  }

  /// Whether the scrolling actually brought the target closer to the viewport.
  ///
  /// A search driving a list the target does not belong to reports a
  /// successful scroll on every attempt while the target stays exactly where
  /// it was. Answering that with "try a larger distance" loops without ever
  /// converging, so the distance is measured instead of assumed. Absent
  /// evidence — fewer than two measured attempts — the answer is yes: a
  /// refusal must not accuse the caller on a guess.
  static bool _targetApproached(final List<Map<String, Object?>> attempts) {
    final distances = attempts
        .map((final attempt) => _asDouble(attempt['outsideViewportBy']))
        .whereType<double>()
        .toList();
    if (distances.length < 2) return true;
    return distances.last < distances.first;
  }

  /// The node the most recent attempt actually scrolled, if it named one.
  static Object? _lastScrolledNode(final List<Map<String, Object?>> attempts) {
    for (final attempt in attempts.reversed) {
      final scrolled = _asMap(attempt['scroll'])?['targetNodeId'];
      if (scrolled != null) return scrolled;
    }
    return null;
  }

  static Map<String, Object?>? _asMap(final Object? value) => switch (value) {
    final Map<Object?, Object?> map => map.cast<String, Object?>(),
    _ => null,
  };

  static double? _asDouble(final Object? value) =>
      value is num ? value.toDouble() : null;

  static const int _maxNearIdentifiers = 8;

  static Iterable<String> _identifiersOf(final Map<String, Object?> snapshot) {
    final nodes = snapshot['nodes'];
    if (nodes is! List) return const <String>[];
    return nodes
        .whereType<Map<Object?, Object?>>()
        .map((final node) => node['identifier'])
        .whereType<String>()
        .where((final id) => id.isNotEmpty);
  }

  /// Identifiers from the screens searched that look like the one asked for,
  /// closest first: the same spelling in another case, then those the query
  /// is a prefix of (`panel.tab` → `panel.tab.overview`), then those that
  /// contain it, then those sharing its leading dotted segments.
  ///
  /// The list is what turns "not found" into a result the caller can act on:
  /// an identifier is matched exactly, so a typo or a missing trailing
  /// segment finds nothing on its own and the caller cannot see why.
  @visibleForTesting
  static List<String> nearIdentifiersFor({
    required final String query,
    required final Iterable<String> identifiersSeen,
  }) {
    final lowerQuery = query.toLowerCase();
    final querySegments = query.split('.');
    int sharedSegments(final String id) {
      final segments = id.split('.');
      var shared = 0;
      while (shared < segments.length &&
          shared < querySegments.length &&
          segments[shared] == querySegments[shared]) {
        shared++;
      }
      return shared;
    }

    // Lower rank sorts first; the shared-segment count breaks ties within
    // the same rank so the sibling with the longer common path leads.
    (int, int)? rankOf(final String id) {
      final lowerId = id.toLowerCase();
      final shared = sharedSegments(id);
      if (lowerId == lowerQuery) return (0, -shared);
      if (lowerId.startsWith(lowerQuery)) return (1, -shared);
      if (lowerId.contains(lowerQuery)) return (2, -shared);
      if (shared > 0) return (3, -shared);
      return null;
    }

    final ranked =
        <(String, (int, int))>[
          for (final id in identifiersSeen.toSet())
            if (rankOf(id) case final rank?) (id, rank),
        ]..sort((final a, final b) {
          final byRank = a.$2.$1.compareTo(b.$2.$1);
          if (byRank != 0) return byRank;
          final bySegments = a.$2.$2.compareTo(b.$2.$2);
          if (bySegments != 0) return bySegments;
          return a.$1.compareTo(b.$1);
        });
    return <String>[for (final (id, _) in ranked.take(_maxNearIdentifiers)) id];
  }

  static Map<String, Object?> _missDetails({
    required final String query,
    required final String matchBy,
    required final Set<String> identifiersSeen,
  }) {
    if (matchBy != 'identifier') return const <String, Object?>{};
    return <String, Object?>{
      'identifiersSeen': identifiersSeen.length,
      'nearIdentifiers': nearIdentifiersFor(
        query: query,
        identifiersSeen: identifiersSeen,
      ),
    };
  }

  /// Why a miss by [matchBy] happens and what to read next — an identifier
  /// is compared whole, so the text-mode advice about split nodes does not
  /// apply to it.
  static String _missHint({
    required final String query,
    required final String matchBy,
    required final Set<String> identifiersSeen,
  }) {
    if (matchBy != 'identifier') {
      return 'Matching by $matchBy is a case-insensitive substring test, so '
          'the text may be split across nodes or rendered without semantics '
          '— call semantic_snapshot and read what the screen actually '
          'publishes.';
    }
    final near = nearIdentifiersFor(
      query: query,
      identifiersSeen: identifiersSeen,
    );
    if (near.isNotEmpty) {
      return 'An identifier must match whole and case-sensitively; '
          '${identifiersSeen.length} identifiers were seen and the closest '
          'are ${near.map((final id) => '"$id"').join(', ')} '
          '(nearIdentifiers) — pass one of them.';
    }
    if (identifiersSeen.isEmpty) {
      return 'An identifier must match whole and case-sensitively, and no '
          'screen searched published any identifier at all — the app does '
          'not set Semantics(identifier:) here; search by text instead.';
    }
    return 'An identifier must match whole and case-sensitively; '
        '${identifiersSeen.length} identifiers were seen and none resembles '
        '"$query" — call semantic_snapshot and read the identifier field, '
        'or search by text.';
  }

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

  /// Whether a scroll that reported failure still moved the screen enough to
  /// be worth re-reading.
  ///
  /// Only the web tier answers this way: it cannot read a scroll offset, so it
  /// compares the visible subtree before and after and says so in
  /// `movementVerified`. Everywhere else a failed scroll means the screen is
  /// unchanged, and another attempt would re-read it.
  static bool _shouldContinueAfterScroll(final Map<String, Object?> scroll) =>
      scroll['movementVerified'] == true;
}
