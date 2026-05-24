// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.
//
// Kept in sync with packages/core/lib/src/visual_capture/platform_view_hints.dart.

const String kCaptureHintRecommendedDesktopWindow = 'desktop_window';

const String kPlatformViewWarning =
    'Native platform view detected. flutter_layer omits embedded pixels.';

const _strongWidgetSuffixes = <String>{
  'AndroidView',
  'UiKitView',
  'AppKitView',
  'HtmlElementView',
  'PlatformViewLink',
};

const _strongRenderSuffixes = <String>{
  'RenderAndroidView',
  'RenderUiKitView',
  'RenderAppKitView',
  'RenderHtmlElementView',
  'RenderPlatformView',
};

const _weakWidgetSuffixes = <String>{'Texture'};

final class PlatformViewMatch {
  const PlatformViewMatch({
    required this.widgetType,
    required this.depth,
    required this.confidence,
    this.renderObjectType,
    this.globalBounds,
  });

  final String widgetType;
  final int depth;
  final String confidence;
  final String? renderObjectType;
  final Map<String, Object?>? globalBounds;

  Map<String, Object?> toJson() => <String, Object?>{
    'widgetType': widgetType,
    'depth': depth,
    'confidence': confidence,
    if (renderObjectType != null) 'renderObjectType': renderObjectType,
    if (globalBounds != null) 'globalBounds': globalBounds,
  };
}

final class PlatformViewHints {
  const PlatformViewHints({
    required this.platformViewsDetected,
    required this.matches,
    required this.recommendedMode,
    required this.warning,
  });

  final bool platformViewsDetected;
  final List<PlatformViewMatch> matches;
  final String? recommendedMode;
  final String? warning;

  static const PlatformViewHints none = PlatformViewHints(
    platformViewsDetected: false,
    matches: <PlatformViewMatch>[],
    recommendedMode: null,
    warning: null,
  );

  Map<String, Object?> toCaptureHintsJson() => <String, Object?>{
    'platformViewsDetected': platformViewsDetected,
    'matches': matches.map((final m) => m.toJson()).toList(growable: false),
    if (recommendedMode != null) 'recommendedMode': recommendedMode,
    if (warning != null) 'warning': warning,
  };
}

PlatformViewHints detectPlatformViews(final Object? widgetTree) {
  final matches = <PlatformViewMatch>[];
  _walkWidgetTree(widgetTree, depth: 0, matches: matches);
  return platformViewHintsFromMatches(matches);
}

/// Builds [PlatformViewHints] from collected [matches].
PlatformViewHints platformViewHintsFromMatches(
  final List<PlatformViewMatch> matches,
) {
  if (matches.isEmpty) {
    return PlatformViewHints.none;
  }
  final hasStrong = matches.any((final m) => m.confidence == 'high');
  return PlatformViewHints(
    platformViewsDetected: hasStrong,
    matches: matches,
    recommendedMode: hasStrong ? kCaptureHintRecommendedDesktopWindow : null,
    warning: hasStrong ? kPlatformViewWarning : null,
  );
}

/// Records platform-view signals for one widget/render pair.
void accumulatePlatformViewSignals({
  required final String? widgetType,
  required final String? renderObjectType,
  required final int depth,
  required final List<PlatformViewMatch> matches,
  final Map<String, Object?>? globalBounds,
}) {
  final strongWidget =
      widgetType != null && _matchesSuffix(widgetType, _strongWidgetSuffixes);
  final strongRender = renderObjectType != null &&
      _matchesSuffix(renderObjectType, _strongRenderSuffixes);
  if (strongWidget || strongRender) {
    matches.add(
      PlatformViewMatch(
        widgetType: widgetType ?? renderObjectType ?? 'unknown',
        depth: depth,
        confidence: 'high',
        renderObjectType: renderObjectType,
        globalBounds: globalBounds,
      ),
    );
  } else if (widgetType != null &&
      _matchesSuffix(widgetType, _weakWidgetSuffixes)) {
    matches.add(
      PlatformViewMatch(
        widgetType: widgetType,
        depth: depth,
        confidence: 'low',
        renderObjectType: renderObjectType,
        globalBounds: globalBounds,
      ),
    );
  }
}

void _walkWidgetTree(
  final Object? node, {
  required final int depth,
  required final List<PlatformViewMatch> matches,
}) {
  final map = _asTreeMap(node);
  if (map.isEmpty) {
    return;
  }

  accumulatePlatformViewSignals(
    widgetType: _typeName(map['widgetType']),
    renderObjectType: _typeName(map['renderObjectType']),
    depth: depth,
    globalBounds: _boundsMap(map['globalBounds']),
    matches: matches,
  );

  final children = map['children'];
  if (children is! List) {
    return;
  }
  for (final child in children) {
    _walkWidgetTree(child, depth: depth + 1, matches: matches);
  }
}

bool _matchesSuffix(final String value, final Set<String> suffixes) {
  for (final suffix in suffixes) {
    if (value == suffix || value.endsWith(suffix)) {
      return true;
    }
  }
  return false;
}

String? _typeName(final Object? value) {
  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') {
    return null;
  }
  return text;
}

Map<String, Object?> _asTreeMap(final Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  return const <String, Object?>{};
}

Map<String, Object?>? _boundsMap(final Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  return null;
}
