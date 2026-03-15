import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

const String kLiveEditOverlayThemeSourcePath =
    'flutter_live_edit/flutter_live_edit_toolkit/lib/src/live_edit_overlay_theme.dart';

const String kLiveEditSelectionBubbleSurfaceId = 'selection_bubble';
const String kLiveEditAiBubbleSurfaceId = 'ai_bubble';
const String kLiveEditPanelRailSurfaceId = 'panel_rail';
const String kLiveEditPanelExpandedSurfaceId = 'panel_expanded';
const String kLiveEditBackendSwitcherSurfaceId = 'backend_switcher';
const String kLiveEditStatusBadgeSurfaceId = 'status_badge';
const String kLiveEditPropertyEditorRowSurfaceId = 'property_editor_row';

double _asDouble(final Object? value, {final double fallback = 0}) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse('$value') ?? fallback;
}

bool _asBool(final Object? value, {final bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  final normalized = '$value'.trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return fallback;
}

String _colorHex(final Color color) {
  final value = color.toARGB32();
  return '#${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

Color _parseColor(final Object? value, final Color fallback) {
  final normalized = '$value'.trim();
  if (!normalized.startsWith('#')) {
    return fallback;
  }
  final raw = normalized.substring(1);
  final expanded = raw.length == 6 ? 'FF$raw' : raw;
  final parsed = int.tryParse(expanded, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

Map<String, Object?> _edgeInsetsJson(final EdgeInsets value) =>
    <String, Object?>{
      'left': value.left,
      'top': value.top,
      'right': value.right,
      'bottom': value.bottom,
    };

EdgeInsets _parseEdgeInsets(final Object? value, final EdgeInsets fallback) {
  if (value is Map) {
    final normalized = value.map(
      (final key, final nestedValue) => MapEntry('$key', nestedValue),
    );
    return EdgeInsets.fromLTRB(
      _asDouble(normalized['left'], fallback: fallback.left),
      _asDouble(normalized['top'], fallback: fallback.top),
      _asDouble(normalized['right'], fallback: fallback.right),
      _asDouble(normalized['bottom'], fallback: fallback.bottom),
    );
  }
  return fallback;
}

LiveEditBounds? _boundsForKey(final GlobalKey key) {
  final context = key.currentContext;
  final renderObject = context?.findRenderObject();
  if (renderObject is! RenderBox ||
      !renderObject.attached ||
      !renderObject.hasSize) {
    return null;
  }
  final origin = renderObject.localToGlobal(ui.Offset.zero);
  final rect = origin & renderObject.size;
  return LiveEditBounds(
    left: rect.left,
    top: rect.top,
    right: rect.right,
    bottom: rect.bottom,
    width: rect.width,
    height: rect.height,
  );
}

final class LiveEditOverlaySurfaceStyle {
  const LiveEditOverlaySurfaceStyle({
    this.width,
    this.height,
    required this.cornerRadius,
    required this.padding,
    required this.gap,
    required this.backgroundColor,
    required this.borderColor,
    required this.badgeTone,
    required this.showDragHandle,
    required this.showResizeHandle,
  });

  final double? width;
  final double? height;
  final double cornerRadius;
  final EdgeInsets padding;
  final double gap;
  final Color backgroundColor;
  final Color borderColor;
  final String badgeTone;
  final bool showDragHandle;
  final bool showResizeHandle;

  LiveEditOverlaySurfaceStyle copyWith({
    final double? width,
    final double? height,
    final double? cornerRadius,
    final EdgeInsets? padding,
    final double? gap,
    final Color? backgroundColor,
    final Color? borderColor,
    final String? badgeTone,
    final bool? showDragHandle,
    final bool? showResizeHandle,
  }) => LiveEditOverlaySurfaceStyle(
    width: width ?? this.width,
    height: height ?? this.height,
    cornerRadius: cornerRadius ?? this.cornerRadius,
    padding: padding ?? this.padding,
    gap: gap ?? this.gap,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    borderColor: borderColor ?? this.borderColor,
    badgeTone: badgeTone ?? this.badgeTone,
    showDragHandle: showDragHandle ?? this.showDragHandle,
    showResizeHandle: showResizeHandle ?? this.showResizeHandle,
  );
}

final class LiveEditOverlayThemeModel extends ChangeNotifier {
  LiveEditOverlayThemeModel._();

  static final LiveEditOverlayThemeModel instance =
      LiveEditOverlayThemeModel._();

  final Map<String, GlobalKey> _surfaceKeys = <String, GlobalKey>{
    kLiveEditSelectionBubbleSurfaceId: GlobalKey(
      debugLabel: kLiveEditSelectionBubbleSurfaceId,
    ),
    kLiveEditAiBubbleSurfaceId: GlobalKey(
      debugLabel: kLiveEditAiBubbleSurfaceId,
    ),
    kLiveEditPanelRailSurfaceId: GlobalKey(
      debugLabel: kLiveEditPanelRailSurfaceId,
    ),
    kLiveEditPanelExpandedSurfaceId: GlobalKey(
      debugLabel: kLiveEditPanelExpandedSurfaceId,
    ),
    kLiveEditBackendSwitcherSurfaceId: GlobalKey(
      debugLabel: kLiveEditBackendSwitcherSurfaceId,
    ),
    kLiveEditStatusBadgeSurfaceId: GlobalKey(
      debugLabel: kLiveEditStatusBadgeSurfaceId,
    ),
    kLiveEditPropertyEditorRowSurfaceId: GlobalKey(
      debugLabel: kLiveEditPropertyEditorRowSurfaceId,
    ),
  };

  final Map<String, LiveEditOverlaySurfaceStyle> _styles =
      <String, LiveEditOverlaySurfaceStyle>{
        kLiveEditSelectionBubbleSurfaceId: const LiveEditOverlaySurfaceStyle(
          width: 300,
          height: 340,
          cornerRadius: 18,
          padding: EdgeInsets.all(14),
          gap: 10,
          backgroundColor: Color(0xFFF8FAFC),
          borderColor: Color(0xFFCBD5E1),
          badgeTone: 'mint',
          showDragHandle: true,
          showResizeHandle: true,
        ),
        kLiveEditAiBubbleSurfaceId: const LiveEditOverlaySurfaceStyle(
          width: 300,
          height: 340,
          cornerRadius: 18,
          padding: EdgeInsets.all(14),
          gap: 10,
          backgroundColor: Color(0xFFFFFBEB),
          borderColor: Color(0xFFFCD34D),
          badgeTone: 'amber',
          showDragHandle: true,
          showResizeHandle: true,
        ),
        kLiveEditPanelRailSurfaceId: const LiveEditOverlaySurfaceStyle(
          width: 64,
          height: 420,
          cornerRadius: 16,
          padding: EdgeInsets.symmetric(vertical: 8),
          gap: 6,
          backgroundColor: Color(0xFFFFFFFF),
          borderColor: Color(0xFFE2E8F0),
          badgeTone: 'sky',
          showDragHandle: false,
          showResizeHandle: false,
        ),
        kLiveEditPanelExpandedSurfaceId: const LiveEditOverlaySurfaceStyle(
          width: 312,
          height: 460,
          cornerRadius: 16,
          padding: EdgeInsets.all(8),
          gap: 8,
          backgroundColor: Color(0xFFFFFFFF),
          borderColor: Color(0xFFE2E8F0),
          badgeTone: 'slate',
          showDragHandle: false,
          showResizeHandle: false,
        ),
        kLiveEditBackendSwitcherSurfaceId: const LiveEditOverlaySurfaceStyle(
          cornerRadius: 10,
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          gap: 6,
          backgroundColor: Color(0xFFF8FAFC),
          borderColor: Color(0xFFE2E8F0),
          badgeTone: 'blue',
          showDragHandle: false,
          showResizeHandle: false,
        ),
        kLiveEditStatusBadgeSurfaceId: const LiveEditOverlaySurfaceStyle(
          cornerRadius: 999,
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          gap: 4,
          backgroundColor: Color(0xFFDBEAFE),
          borderColor: Color(0xFF93C5FD),
          badgeTone: 'blue',
          showDragHandle: false,
          showResizeHandle: false,
        ),
        kLiveEditPropertyEditorRowSurfaceId: const LiveEditOverlaySurfaceStyle(
          cornerRadius: 8,
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          gap: 6,
          backgroundColor: Color(0xFFFFFFFF),
          borderColor: Color(0xFFE2E8F0),
          badgeTone: 'slate',
          showDragHandle: false,
          showResizeHandle: false,
        ),
      };

  final Map<String, Offset> _positions = <String, Offset>{
    kLiveEditSelectionBubbleSurfaceId: const Offset(40, 120),
    kLiveEditAiBubbleSurfaceId: const Offset(72, 160),
    kLiveEditPanelRailSurfaceId: const Offset(420, 48),
    kLiveEditPanelExpandedSurfaceId: const Offset(480, 48),
    kLiveEditBackendSwitcherSurfaceId: const Offset(506, 112),
    kLiveEditStatusBadgeSurfaceId: const Offset(78, 244),
    kLiveEditPropertyEditorRowSurfaceId: const Offset(506, 256),
  };

  GlobalKey keyFor(final String surfaceId) =>
      _surfaceKeys[surfaceId] ??= GlobalKey(debugLabel: surfaceId);

  String? surfaceIdForElement(final Element element) {
    for (final entry in _surfaceKeys.entries) {
      var cursor = element;
      while (true) {
        if (cursor.widget.key == entry.value) {
          return entry.key;
        }
        Element? parent;
        cursor.visitAncestorElements((final candidate) {
          parent = candidate;
          return false;
        });
        if (parent == null) {
          break;
        }
        cursor = parent!;
      }
    }
    return null;
  }

  bool isSurfaceRootElement(final Element element) {
    final surfaceId = surfaceIdForElement(element);
    if (surfaceId == null) {
      return false;
    }
    return element.widget.key == keyFor(surfaceId);
  }

  String componentKindForSurface(final String surfaceId) =>
      _componentKindFor(surfaceId);

  LiveEditOverlaySurfaceStyle styleFor(final String surfaceId) =>
      _styles[surfaceId] ?? _styles[kLiveEditPropertyEditorRowSurfaceId]!;

  Offset positionFor(final String surfaceId) =>
      _positions[surfaceId] ?? const Offset(32, 32);

  double selectionBubbleWidth({required final bool aiMode}) =>
      (styleFor(
        aiMode ? kLiveEditAiBubbleSurfaceId : kLiveEditSelectionBubbleSurfaceId,
      ).width) ??
      300;

  double selectionBubbleHeight({required final bool aiMode}) =>
      (styleFor(
        aiMode ? kLiveEditAiBubbleSurfaceId : kLiveEditSelectionBubbleSurfaceId,
      ).height) ??
      340;

  double panelWidth({required final bool expanded}) =>
      (styleFor(
        expanded
            ? kLiveEditPanelExpandedSurfaceId
            : kLiveEditPanelRailSurfaceId,
      ).width) ??
      (expanded ? 312 : 64);

  LiveEditSelection? selectionForSurface({
    required final String surfaceId,
    required final String sessionId,
  }) {
    final style = _styles[surfaceId];
    if (style == null) {
      return null;
    }
    return LiveEditSelection(
      sessionId: sessionId,
      nodeId: surfaceId,
      widgetType: surfaceId,
      targetDomain: LiveEditTargetDomain.toolScene,
      bounds: _boundsForKey(keyFor(surfaceId)),
      source: const LiveEditSourceLocation(
        file: kLiveEditOverlayThemeSourcePath,
      ),
      propertyGroups: descriptorsForSurface(surfaceId),
      rawNode: <String, Object?>{
        'surfaceId': surfaceId,
        'componentKind': _componentKindFor(surfaceId),
        'position': <String, Object?>{
          'x': positionFor(surfaceId).dx,
          'y': positionFor(surfaceId).dy,
        },
      },
    );
  }

  List<LiveEditSelection> hitTest({
    required final String sessionId,
    required final Offset point,
  }) {
    final hits = <LiveEditSelection>[];
    for (final surfaceId in _styles.keys) {
      final selection = selectionForSurface(
        surfaceId: surfaceId,
        sessionId: sessionId,
      );
      final bounds = selection?.bounds;
      if (selection == null || bounds == null) {
        continue;
      }
      if (point.dx >= bounds.left &&
          point.dx <= bounds.right &&
          point.dy >= bounds.top &&
          point.dy <= bounds.bottom) {
        hits.add(selection);
      }
    }
    hits.sort((final left, final right) {
      final leftArea = (left.bounds?.width ?? 0) * (left.bounds?.height ?? 0);
      final rightArea =
          (right.bounds?.width ?? 0) * (right.bounds?.height ?? 0);
      return leftArea.compareTo(rightArea);
    });
    return hits;
  }

  Map<String, Object?> buildTreeSnapshot(final String sessionId) =>
      <String, Object?>{
        'domain': LiveEditTargetDomain.toolScene.wireName,
        'surfaces': _styles.keys
            .map(
              (final surfaceId) => <String, Object?>{
                'id': surfaceId,
                'label': surfaceId,
                'componentKind': _componentKindFor(surfaceId),
                'bounds': selectionForSurface(
                  surfaceId: surfaceId,
                  sessionId: sessionId,
                )?.bounds?.toJson(),
              },
            )
            .toList(growable: false),
      };

  List<LiveEditPropertyDescriptor> descriptorsForSurface(
    final String surfaceId,
  ) {
    final style = styleFor(surfaceId);
    final meta = <String, Object?>{
      'surfaceId': surfaceId,
      'componentKind': _componentKindFor(surfaceId),
      'persistStrategy': 'overlay_theme_model',
    };
    return <LiveEditPropertyDescriptor>[
      if (style.width != null)
        LiveEditPropertyDescriptor(
          id: 'width',
          label: 'Width',
          group: LiveEditPropertyGroup.layout,
          kind: LiveEditPropertyKind.number,
          value: style.width,
          editable: true,
          previewMode: LiveEditPreviewMode.exact,
          persistable: true,
          canPreviewExactly: true,
          meta: meta,
        ),
      if (style.height != null)
        LiveEditPropertyDescriptor(
          id: 'height',
          label: 'Height',
          group: LiveEditPropertyGroup.layout,
          kind: LiveEditPropertyKind.number,
          value: style.height,
          editable: true,
          previewMode: LiveEditPreviewMode.exact,
          persistable: true,
          canPreviewExactly: true,
          meta: meta,
        ),
      LiveEditPropertyDescriptor(
        id: 'x',
        label: 'X',
        group: LiveEditPropertyGroup.layout,
        kind: LiveEditPropertyKind.number,
        value: positionFor(surfaceId).dx,
        editable: true,
        previewMode: LiveEditPreviewMode.exact,
        persistable: true,
        canPreviewExactly: true,
        meta: meta,
      ),
      LiveEditPropertyDescriptor(
        id: 'y',
        label: 'Y',
        group: LiveEditPropertyGroup.layout,
        kind: LiveEditPropertyKind.number,
        value: positionFor(surfaceId).dy,
        editable: true,
        previewMode: LiveEditPreviewMode.exact,
        persistable: true,
        canPreviewExactly: true,
        meta: meta,
      ),
      LiveEditPropertyDescriptor(
        id: 'cornerRadius',
        label: 'Corner Radius',
        group: LiveEditPropertyGroup.style,
        kind: LiveEditPropertyKind.number,
        value: style.cornerRadius,
        editable: true,
        previewMode: LiveEditPreviewMode.exact,
        persistable: true,
        canPreviewExactly: true,
        meta: meta,
      ),
      LiveEditPropertyDescriptor(
        id: 'padding',
        label: 'Padding',
        group: LiveEditPropertyGroup.layout,
        kind: LiveEditPropertyKind.edgeInsets,
        value: _edgeInsetsJson(style.padding),
        editable: true,
        previewMode: LiveEditPreviewMode.exact,
        persistable: true,
        canPreviewExactly: true,
        meta: meta,
      ),
      LiveEditPropertyDescriptor(
        id: 'gap',
        label: 'Gap',
        group: LiveEditPropertyGroup.layout,
        kind: LiveEditPropertyKind.number,
        value: style.gap,
        editable: true,
        previewMode: LiveEditPreviewMode.exact,
        persistable: true,
        canPreviewExactly: true,
        meta: meta,
      ),
      LiveEditPropertyDescriptor(
        id: 'backgroundColor',
        label: 'Background',
        group: LiveEditPropertyGroup.style,
        kind: LiveEditPropertyKind.color,
        value: _colorHex(style.backgroundColor),
        editable: true,
        previewMode: LiveEditPreviewMode.exact,
        persistable: true,
        canPreviewExactly: true,
        meta: meta,
      ),
      LiveEditPropertyDescriptor(
        id: 'borderColor',
        label: 'Border',
        group: LiveEditPropertyGroup.style,
        kind: LiveEditPropertyKind.color,
        value: _colorHex(style.borderColor),
        editable: true,
        previewMode: LiveEditPreviewMode.exact,
        persistable: true,
        canPreviewExactly: true,
        meta: meta,
      ),
      LiveEditPropertyDescriptor(
        id: 'badgeTone',
        label: 'Badge Tone',
        group: LiveEditPropertyGroup.style,
        kind: LiveEditPropertyKind.enumValue,
        value: style.badgeTone,
        options: const <String>['slate', 'blue', 'mint', 'amber'],
        editable: true,
        previewMode: LiveEditPreviewMode.exact,
        persistable: true,
        canPreviewExactly: true,
        meta: meta,
      ),
      LiveEditPropertyDescriptor(
        id: 'showDragHandle',
        label: 'Drag Handle',
        group: LiveEditPropertyGroup.layout,
        kind: LiveEditPropertyKind.boolean,
        value: style.showDragHandle,
        editable: true,
        previewMode: LiveEditPreviewMode.exact,
        persistable: true,
        canPreviewExactly: true,
        meta: meta,
      ),
      LiveEditPropertyDescriptor(
        id: 'showResizeHandle',
        label: 'Resize Handle',
        group: LiveEditPropertyGroup.layout,
        kind: LiveEditPropertyKind.boolean,
        value: style.showResizeHandle,
        editable: true,
        previewMode: LiveEditPreviewMode.exact,
        persistable: true,
        canPreviewExactly: true,
        meta: meta,
      ),
    ];
  }

  bool applyDraft(final LiveEditDraftChange change) {
    final surfaceId = '${change.meta['surfaceId'] ?? change.nodeId}'.trim();
    final current = _styles[surfaceId];
    if (current == null) {
      return false;
    }
    LiveEditOverlaySurfaceStyle next = current;
    switch (change.propertyId) {
      case 'width':
        next = next.copyWith(width: _asDouble(change.targetValue));
        break;
      case 'height':
        next = next.copyWith(height: _asDouble(change.targetValue));
        break;
      case 'x':
        _positions[surfaceId] = Offset(
          _asDouble(change.targetValue),
          positionFor(surfaceId).dy,
        );
        break;
      case 'y':
        _positions[surfaceId] = Offset(
          positionFor(surfaceId).dx,
          _asDouble(change.targetValue),
        );
        break;
      case 'cornerRadius':
        next = next.copyWith(cornerRadius: _asDouble(change.targetValue));
        break;
      case 'padding':
        next = next.copyWith(
          padding: _parseEdgeInsets(change.targetValue, current.padding),
        );
        break;
      case 'gap':
        next = next.copyWith(gap: _asDouble(change.targetValue));
        break;
      case 'backgroundColor':
        next = next.copyWith(
          backgroundColor: _parseColor(
            change.targetValue,
            current.backgroundColor,
          ),
        );
        break;
      case 'borderColor':
        next = next.copyWith(
          borderColor: _parseColor(change.targetValue, current.borderColor),
        );
        break;
      case 'badgeTone':
        next = next.copyWith(badgeTone: '${change.targetValue}'.trim());
        break;
      case 'showDragHandle':
        next = next.copyWith(showDragHandle: _asBool(change.targetValue));
        break;
      case 'showResizeHandle':
        next = next.copyWith(showResizeHandle: _asBool(change.targetValue));
        break;
      default:
        return false;
    }
    _styles[surfaceId] = next;
    notifyListeners();
    return true;
  }

  void translateSurface(final String surfaceId, final Offset delta) {
    final current = positionFor(surfaceId);
    _positions[surfaceId] = current + delta;
    notifyListeners();
  }

  String _componentKindFor(final String surfaceId) => switch (surfaceId) {
    kLiveEditSelectionBubbleSurfaceId => 'bubble',
    kLiveEditAiBubbleSurfaceId => 'bubble',
    kLiveEditPanelRailSurfaceId => 'panel',
    kLiveEditPanelExpandedSurfaceId => 'panel',
    kLiveEditBackendSwitcherSurfaceId => 'switcher',
    kLiveEditStatusBadgeSurfaceId => 'badge',
    _ => 'property_row',
  };
}
