// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

/// Pure-Dart platform-view detection from widget-tree maps (no dart:io).
library;

const String kCaptureHintRecommendedDesktopWindow = 'desktop_window';

const String kPlatformViewWarning =
    'Native platform view detected. flutter_layer omits embedded pixels.';

const String kWeakTextureWarning =
    'External Texture detected; flutter_layer may omit GPU/canvas pixels. '
    'Prefer desktop_window on macOS host.';

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

/// One platform-view signal discovered in the widget tree.
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

/// Aggregated platform-view hints for agents and capture routing.
final class PlatformViewHints {
  const PlatformViewHints({
    required this.platformViewsDetected,
    required this.matches,
    required this.recommendedMode,
    required this.warning,
    this.weakSignalsDetected = false,
  });

  final bool platformViewsDetected;
  final bool weakSignalsDetected;
  final List<PlatformViewMatch> matches;
  final String? recommendedMode;
  final String? warning;

  static const PlatformViewHints none = PlatformViewHints(
    platformViewsDetected: false,
    matches: <PlatformViewMatch>[],
    recommendedMode: null,
    warning: null,
  );

  bool get hasCaptureRoutingHints =>
      platformViewsDetected || weakSignalsDetected;

  Map<String, Object?> toCaptureHintsJson() => <String, Object?>{
    'platformViewsDetected': platformViewsDetected,
    if (weakSignalsDetected) 'weakSignalsDetected': true,
    'matches': matches.map((final m) => m.toJson()).toList(growable: false),
    if (recommendedMode != null) 'recommendedMode': recommendedMode,
    if (warning != null) 'warning': warning,
  };
}

/// Builds [PlatformViewHints] from collected [matches].
PlatformViewHints platformViewHintsFromMatches(
  final List<PlatformViewMatch> matches,
) {
  if (matches.isEmpty) {
    return PlatformViewHints.none;
  }
  final hasStrong = matches.any((final m) => m.confidence == 'high');
  final hasWeak = matches.any((final m) => m.confidence == 'low');
  if (hasStrong) {
    return PlatformViewHints(
      platformViewsDetected: true,
      matches: matches,
      recommendedMode: kCaptureHintRecommendedDesktopWindow,
      warning: kPlatformViewWarning,
    );
  }
  if (hasWeak) {
    return PlatformViewHints(
      platformViewsDetected: false,
      weakSignalsDetected: true,
      matches: matches,
      recommendedMode: kCaptureHintRecommendedDesktopWindow,
      warning: kWeakTextureWarning,
    );
  }
  return PlatformViewHints.none;
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
  final strongRender =
      renderObjectType != null &&
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

/// Merges auto-detected [detected] hints with an optional app [contributor].
PlatformViewHints mergePlatformViewHints({
  required final PlatformViewHints detected,
  final PlatformViewHints? contributor,
}) {
  if (contributor == null) {
    return detected;
  }
  final matches = <PlatformViewMatch>[
    ...detected.matches,
    ...contributor.matches,
  ];
  final merged = platformViewHintsFromMatches(matches);
  if (contributor.platformViewsDetected) {
    return PlatformViewHints(
      platformViewsDetected: true,
      matches: matches,
      recommendedMode:
          contributor.recommendedMode ??
          merged.recommendedMode ??
          kCaptureHintRecommendedDesktopWindow,
      warning: contributor.warning ?? merged.warning ?? kPlatformViewWarning,
      weakSignalsDetected: merged.weakSignalsDetected,
    );
  }
  return merged;
}

/// Parses app-embedded `captureHints` from `get_view_details` (authoritative when present).
PlatformViewHints platformViewHintsFromCaptureHintsJson(
  final Map<String, Object?> json,
) {
  final platformViewsDetected = json['platformViewsDetected'] == true;
  final weakSignalsDetected = json['weakSignalsDetected'] == true;
  if (!platformViewsDetected && !weakSignalsDetected) {
    return PlatformViewHints.none;
  }
  final matches = <PlatformViewMatch>[];
  final raw = json['matches'];
  if (raw is List) {
    for (final entry in raw) {
      final map = _asTreeMap(entry);
      if (map.isEmpty) {
        continue;
      }
      matches.add(
        PlatformViewMatch(
          widgetType: '${map['widgetType'] ?? 'unknown'}',
          depth: (map['depth'] as num?)?.toInt() ?? 0,
          confidence: '${map['confidence'] ?? 'high'}',
          renderObjectType: map['renderObjectType']?.toString(),
          globalBounds: _boundsMap(map['globalBounds']),
        ),
      );
    }
  }
  if (matches.isEmpty) {
    matches.add(
      const PlatformViewMatch(
        widgetType: 'PlatformView',
        depth: 0,
        confidence: 'high',
      ),
    );
  }
  final fromMatches = platformViewHintsFromMatches(matches);
  if (platformViewsDetected) {
    return PlatformViewHints(
      platformViewsDetected: true,
      matches: fromMatches.matches,
      recommendedMode:
          fromMatches.recommendedMode ?? kCaptureHintRecommendedDesktopWindow,
      warning: fromMatches.warning ?? kPlatformViewWarning,
    );
  }
  return PlatformViewHints(
    platformViewsDetected: false,
    weakSignalsDetected: true,
    matches: fromMatches.matches,
    recommendedMode:
        fromMatches.recommendedMode ?? kCaptureHintRecommendedDesktopWindow,
    warning: fromMatches.warning ?? kWeakTextureWarning,
  );
}

/// Detects native platform views in a [widgetTree] map from `get_view_details`.
PlatformViewHints detectPlatformViews(final Object? widgetTree) {
  final matches = <PlatformViewMatch>[];
  _walkWidgetTree(widgetTree, depth: 0, matches: matches);
  return platformViewHintsFromMatches(matches);
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

/// Merges [hints] and optional [warnings] into screenshot/snapshot payload maps.
Map<String, Object?> mergeCaptureHintMetadata({
  required final Map<String, Object?> data,
  required final PlatformViewHints hints,
  final List<String> extraWarnings = const <String>[],
}) {
  final warnings = <String>[
    ...extraWarnings,
    if (hints.warning != null && hints.hasCaptureRoutingHints) hints.warning!,
  ];
  return <String, Object?>{
    ...data,
    if (hints.hasCaptureRoutingHints)
      'captureHints': hints.toCaptureHintsJson(),
    if (warnings.isNotEmpty) 'warnings': warnings,
    if (hints.hasCaptureRoutingHints)
      'suggestedAction': hints.platformViewsDetected
          ? 'Use mode desktop_window or ensure Simulator/app window is foreground.'
          : 'Consider mode desktop_window on macOS host for external Texture pixels.',
  };
}
