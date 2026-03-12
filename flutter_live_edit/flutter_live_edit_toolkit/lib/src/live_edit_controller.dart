// ignore_for_file: invalid_use_of_protected_member

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

Map<String, Object?> _alignmentJson(final AlignmentGeometry geometry) {
  final resolved = geometry.resolve(TextDirection.ltr);
  return <String, Object?>{'x': resolved.x, 'y': resolved.y};
}

int? _asNullableInt(final Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  return int.tryParse('$value');
}

LiveEditBounds? _boundsForRenderObject(final RenderObject? renderObject) {
  if (renderObject == null || !renderObject.attached) {
    return null;
  }
  if (renderObject is RenderBox) {
    if (!renderObject.hasSize) {
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

  try {
    final rect = MatrixUtils.transformRect(
      renderObject.getTransformTo(null),
      renderObject.paintBounds,
    );
    return LiveEditBounds(
      left: rect.left,
      top: rect.top,
      right: rect.right,
      bottom: rect.bottom,
      width: rect.width,
      height: rect.height,
    );
  } on Exception {
    return null;
  }
}

List<LiveEditPropertyDescriptor> _buildPropertyDescriptors(
  final Element element,
) {
  final widget = element.widget;
  final renderObject = element.renderObject;
  final descriptors = <LiveEditPropertyDescriptor>[];

  void add(final LiveEditPropertyDescriptor descriptor) {
    final normalizedMeta = <String, Object?>{
      ...descriptor.meta,
      if (!descriptor.meta.containsKey('editSurface'))
        'editSurface': descriptor.requiresAgentForPersistence
            ? LiveEditEditSurface.aiBubble.wireName
            : descriptor.options.isNotEmpty ||
                  descriptor.kind == LiveEditPropertyKind.boolean ||
                  descriptor.kind == LiveEditPropertyKind.enumValue
            ? LiveEditEditSurface.inline.wireName
            : LiveEditEditSurface.panel.wireName,
      if (!descriptor.meta.containsKey('editor'))
        'editor': switch (descriptor.kind) {
          LiveEditPropertyKind.boolean => 'toggle',
          LiveEditPropertyKind.integer ||
          LiveEditPropertyKind.number => 'number',
          LiveEditPropertyKind.string => 'text',
          LiveEditPropertyKind.enumValue => 'options',
          _ when descriptor.options.isNotEmpty => 'options',
          _ => 'readonly',
        },
      if (!descriptor.meta.containsKey('selectionUi') &&
          descriptor.options.isNotEmpty)
        'selectionUi': 'chips',
      if (!descriptor.meta.containsKey('step') &&
          (descriptor.kind == LiveEditPropertyKind.integer ||
              descriptor.kind == LiveEditPropertyKind.number))
        'step': descriptor.kind == LiveEditPropertyKind.integer ? 1 : 1.0,
    };
    descriptors.add(
      LiveEditPropertyDescriptor(
        id: descriptor.id,
        label: descriptor.label,
        group: descriptor.group,
        kind: descriptor.kind,
        value: descriptor.value,
        options: descriptor.options,
        editable: descriptor.editable,
        previewMode: descriptor.previewMode,
        persistable: descriptor.persistable,
        canPreviewExactly:
            descriptor.canPreviewExactly ||
            descriptor.previewMode == LiveEditPreviewMode.exact,
        requiresAgentForPersistence:
            descriptor.requiresAgentForPersistence ||
            (descriptor.persistable &&
                descriptor.previewMode != LiveEditPreviewMode.exact),
        safeToAutoGroupInApply:
            descriptor.safeToAutoGroupInApply || descriptor.editable,
        meta: normalizedMeta,
      ),
    );
  }

  if (widget is SizedBox) {
    add(
      LiveEditPropertyDescriptor(
        id: 'width',
        label: 'Width',
        group: LiveEditPropertyGroup.layout,
        kind: LiveEditPropertyKind.number,
        value: widget.width,
        editable: true,
        previewMode: LiveEditPreviewMode.ghost,
        persistable: true,
      ),
    );
    add(
      LiveEditPropertyDescriptor(
        id: 'height',
        label: 'Height',
        group: LiveEditPropertyGroup.layout,
        kind: LiveEditPropertyKind.number,
        value: widget.height,
        editable: true,
        previewMode: LiveEditPreviewMode.ghost,
        persistable: true,
      ),
    );
  }

  if (widget is Container) {
    final width = _finiteDimension(widget.constraints?.maxWidth);
    final height = _finiteDimension(widget.constraints?.maxHeight);
    add(
      LiveEditPropertyDescriptor(
        id: 'width',
        label: 'Width',
        group: LiveEditPropertyGroup.layout,
        kind: LiveEditPropertyKind.number,
        value: width,
        editable: true,
        previewMode: LiveEditPreviewMode.ghost,
        persistable: true,
      ),
    );
    add(
      LiveEditPropertyDescriptor(
        id: 'height',
        label: 'Height',
        group: LiveEditPropertyGroup.layout,
        kind: LiveEditPropertyKind.number,
        value: height,
        editable: true,
        previewMode: LiveEditPreviewMode.ghost,
        persistable: true,
      ),
    );
    if (widget.padding != null) {
      add(
        LiveEditPropertyDescriptor(
          id: 'padding',
          label: 'Padding',
          group: LiveEditPropertyGroup.layout,
          kind: LiveEditPropertyKind.edgeInsets,
          value: _edgeInsetsJson(widget.padding!),
          editable: true,
          previewMode: LiveEditPreviewMode.ghost,
          persistable: true,
        ),
      );
    }
    if (widget.alignment != null) {
      add(
        LiveEditPropertyDescriptor(
          id: 'alignment',
          label: 'Alignment',
          group: LiveEditPropertyGroup.layout,
          kind: LiveEditPropertyKind.alignment,
          value: _alignmentJson(widget.alignment!),
          editable: true,
          previewMode: LiveEditPreviewMode.ghost,
          persistable: true,
        ),
      );
    }
    if (widget.color != null) {
      add(
        LiveEditPropertyDescriptor(
          id: 'color',
          label: 'Color',
          group: LiveEditPropertyGroup.style,
          kind: LiveEditPropertyKind.color,
          value: _colorHex(widget.color!),
          editable: true,
          previewMode: LiveEditPreviewMode.ghost,
          persistable: true,
        ),
      );
    }
  }

  if (widget is Padding) {
    add(
      LiveEditPropertyDescriptor(
        id: 'padding',
        label: 'Padding',
        group: LiveEditPropertyGroup.layout,
        kind: LiveEditPropertyKind.edgeInsets,
        value: _edgeInsetsJson(widget.padding),
        editable: true,
        previewMode: LiveEditPreviewMode.ghost,
        persistable: true,
      ),
    );
  }

  if (widget is Align) {
    add(
      LiveEditPropertyDescriptor(
        id: 'alignment',
        label: 'Alignment',
        group: LiveEditPropertyGroup.layout,
        kind: LiveEditPropertyKind.alignment,
        value: _alignmentJson(widget.alignment),
        editable: true,
        previewMode: LiveEditPreviewMode.ghost,
        persistable: true,
      ),
    );
  }

  if (widget is ColoredBox) {
    add(
      LiveEditPropertyDescriptor(
        id: 'color',
        label: 'Color',
        group: LiveEditPropertyGroup.style,
        kind: LiveEditPropertyKind.color,
        value: _colorHex(widget.color),
        editable: true,
        previewMode: LiveEditPreviewMode.ghost,
        persistable: true,
      ),
    );
  }

  if (widget is Text) {
    add(
      LiveEditPropertyDescriptor(
        id: 'text',
        label: 'Text',
        group: LiveEditPropertyGroup.content,
        kind: LiveEditPropertyKind.string,
        value: widget.data ?? widget.textSpan?.toPlainText(),
        editable: true,
        previewMode: LiveEditPreviewMode.ghost,
        persistable: true,
        meta: <String, Object?>{
          'editor': 'text',
          'editSurface': LiveEditEditSurface.inline.wireName,
          'multiline': ((widget.data ?? widget.textSpan?.toPlainText()) ?? '')
              .contains('\n'),
        },
      ),
    );
    if (widget.style?.fontSize != null) {
      add(
        LiveEditPropertyDescriptor(
          id: 'fontSize',
          label: 'Font Size',
          group: LiveEditPropertyGroup.style,
          kind: LiveEditPropertyKind.number,
          value: widget.style?.fontSize,
          editable: true,
          previewMode: LiveEditPreviewMode.ghost,
          persistable: true,
        ),
      );
    }
    if (widget.style?.color != null) {
      add(
        LiveEditPropertyDescriptor(
          id: 'textColor',
          label: 'Text Color',
          group: LiveEditPropertyGroup.style,
          kind: LiveEditPropertyKind.color,
          value: _colorHex(widget.style!.color!),
          editable: true,
          previewMode: LiveEditPreviewMode.ghost,
          persistable: true,
        ),
      );
    }
  }

  final parentData = renderObject?.parentData;
  if (parentData is FlexParentData) {
    add(
      LiveEditPropertyDescriptor(
        id: 'flexFactor',
        label: 'Flex',
        group: LiveEditPropertyGroup.layout,
        kind: LiveEditPropertyKind.integer,
        value: parentData.flex,
        editable: true,
        previewMode: LiveEditPreviewMode.exact,
        persistable: true,
      ),
    );
    add(
      LiveEditPropertyDescriptor(
        id: 'flexFit',
        label: 'Flex Fit',
        group: LiveEditPropertyGroup.layout,
        kind: LiveEditPropertyKind.enumValue,
        value: parentData.fit?.name ?? 'tight',
        options: const <String>['tight', 'loose'],
        editable: true,
        previewMode: LiveEditPreviewMode.exact,
        persistable: true,
      ),
    );
  }

  if (renderObject is RenderFlex) {
    add(
      LiveEditPropertyDescriptor(
        id: 'mainAxisAlignment',
        label: 'Main Axis',
        group: LiveEditPropertyGroup.layout,
        kind: LiveEditPropertyKind.enumValue,
        value: renderObject.mainAxisAlignment.name,
        options: MainAxisAlignment.values
            .map((final value) => value.name)
            .toList(growable: false),
        editable: true,
        previewMode: LiveEditPreviewMode.exact,
        persistable: true,
      ),
    );
    add(
      LiveEditPropertyDescriptor(
        id: 'crossAxisAlignment',
        label: 'Cross Axis',
        group: LiveEditPropertyGroup.layout,
        kind: LiveEditPropertyKind.enumValue,
        value: renderObject.crossAxisAlignment.name,
        options: CrossAxisAlignment.values
            .map((final value) => value.name)
            .toList(growable: false),
        editable: true,
        previewMode: LiveEditPreviewMode.exact,
        persistable: true,
      ),
    );
  }

  final bounds = _boundsForRenderObject(renderObject);
  if (bounds != null) {
    add(
      LiveEditPropertyDescriptor(
        id: 'bounds',
        label: 'Bounds',
        group: LiveEditPropertyGroup.diagnostics,
        kind: LiveEditPropertyKind.bounds,
        value: bounds.toJson(),
      ),
    );
  }

  return descriptors;
}

String _colorHex(final Color color) {
  final value = color.toARGB32();
  return '#${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

bool _containsPoint(final LiveEditBounds bounds, final ui.Offset point) =>
    point.dx >= bounds.left &&
    point.dx <= bounds.right &&
    point.dy >= bounds.top &&
    point.dy <= bounds.bottom;

List<Object?> _decodeList(final String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    return const <Object?>[];
  }
  return decoded.cast<Object?>();
}

Map<String, Object?> _decodeObject(final String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    return const <String, Object?>{};
  }
  return decoded.map((final key, final value) => MapEntry('$key', value));
}

Map<String, Object?> _edgeInsetsJson(final EdgeInsetsGeometry geometry) {
  final resolved = geometry.resolve(TextDirection.ltr);
  return <String, Object?>{
    'left': resolved.left,
    'top': resolved.top,
    'right': resolved.right,
    'bottom': resolved.bottom,
  };
}

LiveEditSourceLocation? _extractSourceLocation(
  final Map<String, Object?> detailsTree,
  final Element element,
) {
  final creationLocation = detailsTree['creationLocation'];
  if (creationLocation is Map) {
    final normalized = creationLocation.map(
      (final key, final value) => MapEntry('$key', value),
    );
    final file = '${normalized['file'] ?? normalized['fileUri'] ?? ''}'.trim();
    if (file.isNotEmpty) {
      return LiveEditSourceLocation(
        file: file,
        line: _asNullableInt(normalized['line']),
        column: _asNullableInt(normalized['column']),
      );
    }
  }

  String? sourceHint;
  assert(() {
    sourceHint = element.debugGetCreatorChain(8);
    return true;
  }());
  if (sourceHint == null || sourceHint!.trim().isEmpty) {
    return null;
  }
  return LiveEditSourceLocation(file: '', sourceHint: sourceHint!.trim());
}

List<_ElementHit> _findElementHitCandidates(
  final Element root, {
  required final ui.Offset point,
  required final int? requestedViewId,
  final List<Map<String, Object?>> ancestry = const <Map<String, Object?>>[],
}) {
  final renderObject = root.renderObject;
  final bounds = _boundsForRenderObject(renderObject);
  if (bounds == null) {
    return const <_ElementHit>[];
  }
  if (!_containsPoint(bounds, point)) {
    return const <_ElementHit>[];
  }

  final viewId = _viewIdForRenderObject(renderObject);
  if (requestedViewId != null && viewId != null && viewId != requestedViewId) {
    return const <_ElementHit>[];
  }

  final children = <Element>[];
  root.visitChildElements(children.add);
  for (var index = children.length - 1; index >= 0; index -= 1) {
    final child = children[index];
    final childHits = _findElementHitCandidates(
      child,
      point: point,
      requestedViewId: requestedViewId,
      ancestry: <Map<String, Object?>>[
        ...ancestry,
        <String, Object?>{
          'widgetType': root.widget.runtimeType.toString(),
          'renderObjectType': renderObject?.runtimeType.toString(),
        },
      ],
    );
    if (childHits.isNotEmpty) {
      return <_ElementHit>[
        ...childHits,
        _ElementHit(element: root, ancestry: ancestry),
      ];
    }
  }

  return <_ElementHit>[_ElementHit(element: root, ancestry: ancestry)];
}

double? _finiteDimension(final double? value) {
  if (value == null || !value.isFinite) {
    return null;
  }
  return value;
}

Map<String, Object?> _layoutContextForElement(final Element element) {
  final renderObject = element.renderObject;
  final context = <String, Object?>{
    'widgetType': element.widget.runtimeType.toString(),
    if (renderObject != null)
      'renderObjectType': renderObject.runtimeType.toString(),
  };

  if (renderObject case final RenderBox box when box.hasSize) {
    context['size'] = <String, Object?>{
      'width': box.size.width,
      'height': box.size.height,
    };
  }

  try {
    if (renderObject != null && !renderObject.debugNeedsLayout) {
      final constraints = renderObject.constraints;
      context['constraints'] = constraints.toString();
    }
  } on Exception {
    // best effort
  }

  final parentData = renderObject?.parentData;
  if (parentData is FlexParentData) {
    context['flexFactor'] = parentData.flex;
    context['flexFit'] = parentData.fit?.name;
  } else if (parentData is BoxParentData) {
    context['offset'] = <String, Object?>{
      'dx': parentData.offset.dx,
      'dy': parentData.offset.dy,
    };
  }

  if (renderObject?.parent case final RenderFlex parentFlex) {
    context['parentFlex'] = <String, Object?>{
      'direction': parentFlex.direction.name,
      'mainAxisAlignment': parentFlex.mainAxisAlignment.name,
      'crossAxisAlignment': parentFlex.crossAxisAlignment.name,
    };
  }

  return context;
}

int? _viewIdForRenderObject(final RenderObject? renderObject) {
  if (renderObject == null) {
    return null;
  }
  RenderObject current = renderObject;
  while (current.parent is RenderObject) {
    current = current.parent!;
  }
  if (current is RenderView) {
    return current.flutterView.viewId;
  }
  return null;
}

final class LiveEditController extends ChangeNotifier {
  LiveEditController._();

  static final LiveEditController instance = LiveEditController._();

  final Map<String, _LiveEditSessionState> _sessions =
      <String, _LiveEditSessionState>{};
  String? _activeSessionId;

  List<LiveEditDraftChange> get activeDraftChanges =>
      List<LiveEditDraftChange>.unmodifiable(
        _activeSessionOrNull()?.draftChanges ?? const <LiveEditDraftChange>[],
      );

  LiveEditSelection? get activeSelection => _activeSessionOrNull()?.selection;

  List<LiveEditSelectionCandidate> get activeSelectionCandidates =>
      List<LiveEditSelectionCandidate>.unmodifiable(
        _activeSessionOrNull()?.selectionCandidates ??
            const <LiveEditSelectionCandidate>[],
      );

  String? get activeSessionId => _activeSessionId;

  bool get overlayVisible => _activeSessionOrNull()?.overlayEnabled ?? false;

  Map<String, Object?> discardDraft({final String? sessionId}) {
    final session = _requireSession(sessionId);
    _revertExactPreview(session);
    session.draftChanges.clear();
    session.lastTouchedAt = DateTime.now().toUtc();
    notifyListeners();
    return <String, Object?>{
      'sessionId': session.sessionId,
      'discarded': true,
      'draftChanges': const <Object?>[],
    };
  }

  Map<String, Object?> endSession({final String? sessionId}) {
    final session = _requireSession(sessionId);
    _revertExactPreview(session);
    final removed = _sessions.remove(session.sessionId);
    if (_activeSessionId == session.sessionId) {
      _activeSessionId = _sessions.keys.isEmpty ? null : _sessions.keys.first;
    }
    notifyListeners();
    return <String, Object?>{
      'sessionId': session.sessionId,
      'ended': removed != null,
    };
  }

  Map<String, Object?> getDraft({final String? sessionId}) {
    final session = _requireSession(sessionId);
    return <String, Object?>{
      'sessionId': session.sessionId,
      'draftChanges': session.draftChanges
          .map((final draft) => draft.toJson())
          .toList(),
    };
  }

  Map<String, Object?> getSelection({final String? sessionId}) {
    final session = _requireSession(sessionId);
    final selection = session.selection;
    return <String, Object?>{
      'sessionId': session.sessionId,
      'selection': selection?.toJson(),
      'hasSelection': selection != null,
      'selectionCandidates': session.selectionCandidates
          .map((final candidate) => candidate.toJson())
          .toList(growable: false),
    };
  }

  Map<String, Object?> getTree({final String? sessionId}) {
    final session = _requireSession(sessionId);
    final rawTree = _decodeObject(
      WidgetInspectorService.instance.getRootWidgetSummaryTree(
        session.objectGroup,
      ),
    );
    session.lastTouchedAt = DateTime.now().toUtc();
    return <String, Object?>{
      'sessionId': session.sessionId,
      'selectedNodeId': session.selection?.nodeId,
      'tree': rawTree,
    };
  }

  Map<String, Object?> selectAtGlobalOffset(final ui.Offset offset) =>
      selectAtPoint(
        sessionId: _activeSessionId,
        x: offset.dx.round(),
        y: offset.dy.round(),
      );

  Map<String, Object?> selectAtPoint({
    required final int x,
    required final int y,
    final String? sessionId,
    final int? viewId,
    final Element? contentRoot,
  }) {
    final session = _requireSession(sessionId);
    final root =
        (contentRoot != null && contentRoot.mounted ? contentRoot : null) ??
        WidgetsBinding.instance.rootElement;
    if (root == null) {
      return <String, Object?>{
        'sessionId': session.sessionId,
        'hit': false,
        'reason': 'widget_tree_unavailable',
      };
    }

    final point = ui.Offset(x.toDouble(), y.toDouble());
    final hits = _findElementHitCandidates(
      root,
      point: point,
      requestedViewId: viewId,
    );
    if (hits.isEmpty) {
      return <String, Object?>{
        'sessionId': session.sessionId,
        'hit': false,
        'point': <String, Object?>{'x': x, 'y': y},
      };
    }

    session.selectionHitCandidates = hits;
    final selection = _setSelection(
      session: session,
      element: hits.first.element,
      ancestry: hits.first.ancestry,
    );
    _syncSelectionCandidates(session);
    notifyListeners();
    return <String, Object?>{
      'sessionId': session.sessionId,
      'hit': true,
      'point': <String, Object?>{'x': x, 'y': y},
      'selection': selection.toJson(),
      'selectionCandidates': session.selectionCandidates
          .map((final candidate) => candidate.toJson())
          .toList(growable: false),
    };
  }

  Map<String, Object?> selectCandidate({
    final String? sessionId,
    final int? index,
    final String? nodeId,
  }) {
    final session = _requireSession(sessionId);
    final hits = session.selectionHitCandidates;
    if (hits.isEmpty) {
      return <String, Object?>{
        'sessionId': session.sessionId,
        'selected': false,
        'reason': 'no_candidates',
      };
    }
    final resolvedIndex =
        index ??
        hits.indexWhere(
          (final candidate) =>
              (WidgetInspectorService.instance.toId(
                    candidate.element,
                    session.objectGroup,
                  ) ??
                  '') ==
              '$nodeId',
        );
    if (resolvedIndex < 0 || resolvedIndex >= hits.length) {
      return <String, Object?>{
        'sessionId': session.sessionId,
        'selected': false,
        'reason': 'candidate_not_found',
      };
    }
    final hit = hits[resolvedIndex];
    final selection = _setSelection(
      session: session,
      element: hit.element,
      ancestry: hit.ancestry,
    );
    _syncSelectionCandidates(session);
    notifyListeners();
    return <String, Object?>{
      'sessionId': session.sessionId,
      'selected': true,
      'selection': selection.toJson(),
      'selectionCandidates': session.selectionCandidates
          .map((final candidate) => candidate.toJson())
          .toList(growable: false),
    };
  }

  Map<String, Object?> selectParent({final String? sessionId}) {
    final session = _requireSession(sessionId);
    final activeIndex = session.selectionCandidates.indexWhere(
      (final candidate) => candidate.active,
    );
    if (activeIndex < 0 ||
        activeIndex + 1 >= session.selectionHitCandidates.length) {
      return <String, Object?>{
        'sessionId': session.sessionId,
        'selected': false,
        'reason': 'parent_unavailable',
      };
    }
    return selectCandidate(
      sessionId: session.sessionId,
      index: activeIndex + 1,
    );
  }

  Map<String, Object?> setOverlay({
    required final bool enabled,
    final String? sessionId,
  }) {
    final session = _requireSession(sessionId);
    session.overlayEnabled = enabled;
    session.lastTouchedAt = DateTime.now().toUtc();
    notifyListeners();
    return <String, Object?>{
      'sessionId': session.sessionId,
      'overlayEnabled': session.overlayEnabled,
      'selectionMode': session.overlayEnabled,
    };
  }

  Map<String, Object?> startSession({final String? requestedSessionId}) {
    final sessionId = requestedSessionId?.trim().isNotEmpty == true
        ? requestedSessionId!.trim()
        : 'live_edit_${DateTime.now().millisecondsSinceEpoch}';

    _activeSessionId = sessionId;
    final session = _sessions.putIfAbsent(
      sessionId,
      () => _LiveEditSessionState(
        sessionId: sessionId,
        objectGroup: 'live_edit_group_$sessionId',
      ),
    );
    session.lastTouchedAt = DateTime.now().toUtc();
    notifyListeners();
    return <String, Object?>{
      'sessionId': sessionId,
      'active': true,
      'overlayEnabled': session.overlayEnabled,
      'selectionCandidates': session.selectionCandidates
          .map((final candidate) => candidate.toJson())
          .toList(growable: false),
    };
  }

  Map<String, Object?> updateDraft({
    required final LiveEditDraftChange change,
    final String? sessionId,
  }) {
    final session = _requireSession(sessionId);
    final selection = session.selection;
    if (selection == null || selection.nodeId != change.nodeId) {
      return <String, Object?>{
        'sessionId': session.sessionId,
        'updated': false,
        'reason': 'selection_mismatch',
      };
    }

    final existingIndex = session.draftChanges.indexWhere(
      (final candidate) =>
          candidate.nodeId == change.nodeId &&
          candidate.propertyId == change.propertyId,
    );
    if (existingIndex >= 0) {
      session.draftChanges[existingIndex] = change;
    } else {
      session.draftChanges.add(change);
    }

    final appliedExact = _applyExactPreviewIfSupported(session, change);
    session.lastTouchedAt = DateTime.now().toUtc();
    notifyListeners();
    return <String, Object?>{
      'sessionId': session.sessionId,
      'updated': true,
      'selection': selection.toJson(),
      'draftChanges': session.draftChanges
          .map((final draft) => draft.toJson())
          .toList(),
      'appliedPreviewMode': appliedExact
          ? LiveEditPreviewMode.exact.wireName
          : LiveEditPreviewMode.ghost.wireName,
    };
  }

  _LiveEditSessionState? _activeSessionOrNull() {
    final activeSessionId = _activeSessionId;
    if (activeSessionId == null) {
      return null;
    }
    return _sessions[activeSessionId];
  }

  bool _applyExactPreviewIfSupported(
    final _LiveEditSessionState session,
    final LiveEditDraftChange change,
  ) {
    final selection = session.selection;
    final element = session.selectedElement;
    if (selection == null || element == null || !element.mounted) {
      return false;
    }

    void captureOriginal(final String propertyId, final Object? currentValue) {
      session.originalExactValues.putIfAbsent(propertyId, () => currentValue);
    }

    final renderObject = element.renderObject;
    switch (change.propertyId) {
      case 'flexFactor':
        final parentData = renderObject?.parentData;
        if (parentData is FlexParentData) {
          captureOriginal(change.propertyId, parentData.flex);
          parentData.flex = _asNullableInt(change.targetValue);
          renderObject?.markNeedsLayout();
          return true;
        }
      case 'flexFit':
        final parentData = renderObject?.parentData;
        if (parentData is FlexParentData) {
          captureOriginal(change.propertyId, parentData.fit?.name ?? 'tight');
          parentData.fit = '$change.targetValue'.trim() == 'loose'
              ? FlexFit.loose
              : FlexFit.tight;
          renderObject?.markNeedsLayout();
          return true;
        }
      case 'mainAxisAlignment':
        if (renderObject is RenderFlex) {
          captureOriginal(
            change.propertyId,
            renderObject.mainAxisAlignment.name,
          );
          renderObject.mainAxisAlignment = MainAxisAlignment.values.firstWhere(
            (final candidate) => candidate.name == '$change.targetValue',
            orElse: () => renderObject.mainAxisAlignment,
          );
          renderObject.markNeedsLayout();
          renderObject.markNeedsPaint();
          return true;
        }
      case 'crossAxisAlignment':
        if (renderObject is RenderFlex) {
          captureOriginal(
            change.propertyId,
            renderObject.crossAxisAlignment.name,
          );
          renderObject.crossAxisAlignment = CrossAxisAlignment.values
              .firstWhere(
                (final candidate) => candidate.name == '$change.targetValue',
                orElse: () => renderObject.crossAxisAlignment,
              );
          renderObject.markNeedsLayout();
          renderObject.markNeedsPaint();
          return true;
        }
    }
    return false;
  }

  _LiveEditSessionState _requireSession(final String? sessionId) {
    final resolvedId = sessionId?.trim().isNotEmpty == true
        ? sessionId!.trim()
        : _activeSessionId;
    if (resolvedId == null) {
      final started = startSession();
      return _sessions[started['sessionId']! as String]!;
    }
    return _sessions.putIfAbsent(
      resolvedId,
      () => _LiveEditSessionState(
        sessionId: resolvedId,
        objectGroup: 'live_edit_group_$resolvedId',
      ),
    );
  }

  void _revertExactPreview(final _LiveEditSessionState session) {
    final element = session.selectedElement;
    if (element == null || !element.mounted) {
      session.originalExactValues.clear();
      return;
    }
    final renderObject = element.renderObject;
    if (renderObject == null) {
      session.originalExactValues.clear();
      return;
    }

    for (final entry in session.originalExactValues.entries) {
      switch (entry.key) {
        case 'flexFactor':
          final parentData = renderObject.parentData;
          if (parentData is FlexParentData) {
            parentData.flex = _asNullableInt(entry.value);
            renderObject.markNeedsLayout();
          }
        case 'flexFit':
          final parentData = renderObject.parentData;
          if (parentData is FlexParentData) {
            parentData.fit = '${entry.value ?? 'tight'}' == 'loose'
                ? FlexFit.loose
                : FlexFit.tight;
            renderObject.markNeedsLayout();
          }
        case 'mainAxisAlignment':
          if (renderObject is RenderFlex) {
            renderObject.mainAxisAlignment = MainAxisAlignment.values
                .firstWhere(
                  (final candidate) => candidate.name == '${entry.value}',
                  orElse: () => renderObject.mainAxisAlignment,
                );
            renderObject.markNeedsLayout();
            renderObject.markNeedsPaint();
          }
        case 'crossAxisAlignment':
          if (renderObject is RenderFlex) {
            renderObject.crossAxisAlignment = CrossAxisAlignment.values
                .firstWhere(
                  (final candidate) => candidate.name == '${entry.value}',
                  orElse: () => renderObject.crossAxisAlignment,
                );
            renderObject.markNeedsLayout();
            renderObject.markNeedsPaint();
          }
      }
    }
    session.originalExactValues.clear();
  }

  LiveEditSelection _setSelection({
    required final _LiveEditSessionState session,
    required final Element element,
    required final List<Map<String, Object?>> ancestry,
  }) {
    if (session.selectedElement != null && session.selectedElement != element) {
      _revertExactPreview(session);
      session.draftChanges.clear();
    }

    final nodeId =
        WidgetInspectorService.instance.toId(element, session.objectGroup) ??
        'live_edit_node_${DateTime.now().microsecondsSinceEpoch}';
    WidgetInspectorService.instance.setSelection(element, session.objectGroup);

    final detailsTree = _decodeObject(
      WidgetInspectorService.instance.getDetailsSubtree(
        nodeId,
        session.objectGroup,
      ),
    );
    final propertiesList = _decodeList(
      WidgetInspectorService.instance.getProperties(
        nodeId,
        session.objectGroup,
      ),
    );
    final parentChain = _decodeList(
      WidgetInspectorService.instance.getParentChain(
        nodeId,
        session.objectGroup,
      ),
    );
    final renderObject = element.renderObject;
    final selection = LiveEditSelection(
      sessionId: session.sessionId,
      nodeId: nodeId,
      widgetType: element.widget.runtimeType.toString(),
      renderObjectType: renderObject?.runtimeType.toString(),
      bounds: _boundsForRenderObject(renderObject),
      source: _extractSourceLocation(detailsTree, element),
      propertyGroups: _buildPropertyDescriptors(element),
      layoutContext: _layoutContextForElement(element),
      parentChain: parentChain
          .whereType<Map>()
          .map(Map<String, Object?>.from)
          .toList(growable: false),
      detailsTree: detailsTree,
      propertiesTree: <String, Object?>{'items': propertiesList},
      rawNode: detailsTree,
    );

    session.selectedElement = element;
    session.selection = selection;
    session.ancestry = ancestry;
    session.lastTouchedAt = DateTime.now().toUtc();
    return selection;
  }

  void _syncSelectionCandidates(final _LiveEditSessionState session) {
    final activeElement = session.selectedElement;
    session.selectionCandidates = session.selectionHitCandidates.indexed
        .map((final entry) {
          final index = entry.$1;
          final hit = entry.$2;
          final renderObject = hit.element.renderObject;
          final nodeId =
              WidgetInspectorService.instance.toId(
                hit.element,
                session.objectGroup,
              ) ??
              'live_edit_candidate_${session.sessionId}_$index';
          return LiveEditSelectionCandidate(
            nodeId: nodeId,
            widgetType: hit.element.widget.runtimeType.toString(),
            bounds: _boundsForRenderObject(renderObject),
            depth: index,
            source: _extractSourceLocation(
              _decodeObject(
                WidgetInspectorService.instance.getDetailsSubtree(
                  nodeId,
                  session.objectGroup,
                ),
              ),
              hit.element,
            ),
            active: identical(hit.element, activeElement),
          );
        })
        .toList(growable: false);
  }
}

final class _ElementHit {
  const _ElementHit({required this.element, required this.ancestry});

  final Element element;
  final List<Map<String, Object?>> ancestry;
}

final class _LiveEditSessionState {
  _LiveEditSessionState({required this.sessionId, required this.objectGroup});

  final String sessionId;
  final String objectGroup;
  bool overlayEnabled = false;
  Element? selectedElement;
  LiveEditSelection? selection;
  List<Map<String, Object?>> ancestry = const <Map<String, Object?>>[];
  List<_ElementHit> selectionHitCandidates = const <_ElementHit>[];
  List<LiveEditSelectionCandidate> selectionCandidates =
      const <LiveEditSelectionCandidate>[];
  final List<LiveEditDraftChange> draftChanges = <LiveEditDraftChange>[];
  final Map<String, Object?> originalExactValues = <String, Object?>{};
  DateTime lastTouchedAt = DateTime.now().toUtc();
}
