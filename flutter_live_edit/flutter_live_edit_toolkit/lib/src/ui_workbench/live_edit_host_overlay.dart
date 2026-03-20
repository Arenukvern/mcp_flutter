import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../commands/commands.dart';
import '../di_live_edit_context/live_edit_context.dart';
import '../di_live_edit_context/tools/live_edit_controller_adapter.dart';
import '../di_live_edit_context/live_edit_orchestrator.dart';

double _overlayMathMax(final double a, final double b) => a > b ? a : b;

double _overlayMathMin(final double a, final double b) => a < b ? a : b;

double _overlayAsDouble(final Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

void _overlayDrawDashedRect(
  final Canvas canvas,
  final Rect rect,
  final Paint paint,
) {
  const dash = 8.0;
  const gap = 4.0;
  for (double x = rect.left; x < rect.right; x += dash + gap) {
    canvas.drawLine(
      Offset(x, rect.top),
      Offset(_overlayMathMin(x + dash, rect.right), rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(x, rect.bottom),
      Offset(_overlayMathMin(x + dash, rect.right), rect.bottom),
      paint,
    );
  }
  for (double y = rect.top; y < rect.bottom; y += dash + gap) {
    canvas.drawLine(
      Offset(rect.left, y),
      Offset(rect.left, _overlayMathMin(y + dash, rect.bottom)),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, y),
      Offset(rect.right, _overlayMathMin(y + dash, rect.bottom)),
      paint,
    );
  }
}

class _HitTestExclusionScope extends SingleChildRenderObjectWidget {
  const _HitTestExclusionScope({
    required this.excludedRects,
    required super.child,
  });

  final List<Rect> excludedRects;

  @override
  RenderObject createRenderObject(final BuildContext context) =>
      _RenderHitTestExclusionScope(excludedRects);

  @override
  void updateRenderObject(
    final BuildContext context,
    final _RenderHitTestExclusionScope renderObject,
  ) {
    renderObject.excludedRects = excludedRects;
  }
}

class LiveEditOverlay extends StatefulWidget {
  const LiveEditOverlay({
    required this.context,
    required this.controller,
    required this.contentKey,
    required this.targetDomain,
    required this.interactive,
    super.key,
    this.excludedRects = const <Rect>[],
    this.openBubbleOnSelect = false,
    this.orchestrator,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final GlobalKey contentKey;
  final LiveEditTargetDomain targetDomain;
  final bool interactive;
  final List<Rect> excludedRects;
  final bool openBubbleOnSelect;
  final LiveEditOrchestrator? orchestrator;

  @override
  State<LiveEditOverlay> createState() => _LiveEditOverlayState();
}

class _LiveEditOverlayPainter extends CustomPainter {
  const _LiveEditOverlayPainter({
    required this.selection,
    required this.hoverSelection,
    required this.multiSelection,
    required this.marqueeRect,
    required this.deeperPickActive,
    required this.draftChanges,
  });

  final LiveEditSelection? selection;
  final LiveEditSelection? hoverSelection;
  final List<LiveEditSelection> multiSelection;
  final Rect? marqueeRect;
  final bool deeperPickActive;
  final List<LiveEditDraftChange> draftChanges;

  @override
  void paint(final Canvas canvas, final Size size) {
    _paintHover(canvas);
    _paintMultiSelection(canvas);
    _paintMarquee(canvas);
    final currentSelection = selection;
    if (currentSelection == null || currentSelection.bounds == null) return;

    final bounds = currentSelection.bounds!;
    final baseRect = Rect.fromLTRB(
      bounds.left,
      bounds.top,
      bounds.right,
      bounds.bottom,
    );
    final selectionPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = deeperPickActive
          ? const Color(0xFF2563EB)
          : const Color(0xFF00A77F);
    canvas.drawRect(baseRect, selectionPaint);

    final ghostRect = _ghostRectFromDrafts(baseRect);
    if (ghostRect != null) {
      final ghostPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFF7A18);
      _overlayDrawDashedRect(canvas, ghostRect, ghostPaint);
    }

    final labelText = _buildLabelText();
    if (labelText.isEmpty) return;

    final paragraphBuilder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(fontSize: 12, fontWeight: FontWeight.w600),
          )
          ..pushStyle(ui.TextStyle(color: const Color(0xFF111827)))
          ..addText(labelText);

    final paragraph = paragraphBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: 260));
    final labelRect = Rect.fromLTWH(
      baseRect.left,
      _overlayMathMax(0, baseRect.top - paragraph.height - 10),
      paragraph.width + 12,
      paragraph.height + 8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(10)),
      Paint()..color = const Color(0xFFFDE68A),
    );
    canvas.drawParagraph(
      paragraph,
      Offset(labelRect.left + 6, labelRect.top + 4),
    );
  }

  @override
  bool shouldRepaint(final _LiveEditOverlayPainter oldDelegate) =>
      oldDelegate.selection != selection ||
      oldDelegate.hoverSelection != hoverSelection ||
      oldDelegate.multiSelection != multiSelection ||
      oldDelegate.marqueeRect != marqueeRect ||
      oldDelegate.deeperPickActive != deeperPickActive ||
      oldDelegate.draftChanges != draftChanges;

  String _buildLabelText() {
    if (draftChanges.isEmpty) return '';
    return draftChanges
        .map((final draft) => '${draft.propertyId}: ${draft.targetValue}')
        .join(' | ');
  }

  Rect? _ghostRectFromDrafts(final Rect baseRect) {
    double? width;
    double? height;
    for (final draft in draftChanges) {
      if (draft.propertyId == 'width') {
        width = _overlayAsDouble(draft.targetValue);
      } else if (draft.propertyId == 'height') {
        height = _overlayAsDouble(draft.targetValue);
      }
    }
    if (width == null && height == null) return null;
    return Rect.fromLTWH(
      baseRect.left,
      baseRect.top,
      width ?? baseRect.width,
      height ?? baseRect.height,
    );
  }

  void _paintHover(final Canvas canvas) {
    final hovered = hoverSelection?.bounds;
    if (hovered == null) return;
    final rect = Rect.fromLTRB(
      hovered.left,
      hovered.top,
      hovered.right,
      hovered.bottom,
    );
    canvas.drawRect(rect, Paint()..color = const Color(0x220EA5E9));
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = deeperPickActive
            ? const Color(0xFF2563EB)
            : const Color(0xFF0EA5E9),
    );
  }

  void _paintMarquee(final Canvas canvas) {
    final rect = marqueeRect;
    if (rect == null) return;
    canvas.drawRect(rect, Paint()..color = const Color(0x1A2563EB));
    _overlayDrawDashedRect(
      canvas,
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF2563EB),
    );
  }

  void _paintMultiSelection(final Canvas canvas) {
    if (multiSelection.length < 2) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFF97316);
    for (final selection in multiSelection) {
      final bounds = selection.bounds;
      if (bounds == null) continue;
      canvas.drawRect(
        Rect.fromLTRB(bounds.left, bounds.top, bounds.right, bounds.bottom),
        paint,
      );
    }
  }
}

class _LiveEditOverlayState extends State<LiveEditOverlay> {
  static const double _dragThreshold = 8;
  static const Duration _marqueeThrottle = Duration(milliseconds: 50);
  Offset? _pointerDown;
  bool _dragging = false;
  DateTime? _lastMarqueeUpdate;
  int _pendingMarqueeX = 0;
  int _pendingMarqueeY = 0;
  bool _hasPendingMarquee = false;

  void _flushMarqueeUpdate() {
    if (!_hasPendingMarquee) return;
    UpdateMarqueeCommand(
      x: _pendingMarqueeX,
      y: _pendingMarqueeY,
      contentRoot: _contentRoot,
    ).execute(widget.context);
    _lastMarqueeUpdate = DateTime.now();
    _hasPendingMarquee = false;
  }

  String? get _sessionId =>
      widget.orchestrator?.context.sessionResource.value.activeSessionId ??
      widget.context.sessionResource.value.activeSessionId;

  List<LiveEditDraftChange> get _draftChangesForDomain =>
      widget.controller.draftChangesForDomain(
        targetDomain: widget.targetDomain,
        sessionId: _sessionId,
      );

  LiveEditSelection? get _hoverForDomain =>
      widget.controller.hoverSelectionForDomain(
        targetDomain: widget.targetDomain,
        sessionId: _sessionId,
      );

  Rect? get _marqueeRectForDomain => widget.controller.marqueeRectForDomain(
    targetDomain: widget.targetDomain,
    sessionId: _sessionId,
  );

  List<LiveEditSelection> get _marqueeSelectionsForDomain =>
      widget.controller.marqueeSelectionsForDomain(
        targetDomain: widget.targetDomain,
        sessionId: _sessionId,
      );

  List<LiveEditSelection> get _multiSelectionForDomain =>
      widget.controller.multiSelectionForDomain(
        targetDomain: widget.targetDomain,
        sessionId: _sessionId,
      );

  LiveEditSelection? get _selectionForDomain =>
      widget.controller.selectionForDomain(
        targetDomain: widget.targetDomain,
        sessionId: _sessionId,
      );

  bool get _deeperPickEnabled =>
      (widget.orchestrator?.context ?? widget.context)
          .panelViewResource
          .value
          .deeperPickEnabled;

  Element? get _contentRoot => widget.contentKey.currentContext is Element
      ? widget.contentKey.currentContext! as Element
      : null;

  @override
  Widget build(final BuildContext context) => Positioned.fill(
    child: _HitTestExclusionScope(
      excludedRects: widget.excludedRects,
      child: Focus(
        autofocus: true,
        child: MouseRegion(
          onHover: widget.interactive
              ? (final event) {
                  HoverAtPointCommand(
                    x: event.position.dx.round(),
                    y: event.position.dy.round(),
                    contentRoot: _contentRoot,
                    deeperMode: _deeperPickEnabled,
                    targetDomain: widget.targetDomain,
                  ).execute(widget.context);
                }
              : null,
          onExit: widget.interactive
              ? (_) => ClearHoverCommand().execute(widget.context)
              : null,
          child: IgnorePointer(
            ignoring: !widget.interactive,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (final event) {
                _pointerDown = event.position;
                _dragging = false;
                HoverAtPointCommand(
                  x: event.position.dx.round(),
                  y: event.position.dy.round(),
                  contentRoot: _contentRoot,
                  deeperMode: _deeperPickEnabled,
                  targetDomain: widget.targetDomain,
                ).execute(widget.context);
              },
              onPointerMove: (final event) {
                final start = _pointerDown;
                if (start == null) {
                  HoverAtPointCommand(
                    x: event.position.dx.round(),
                    y: event.position.dy.round(),
                    contentRoot: _contentRoot,
                    deeperMode: _deeperPickEnabled,
                    targetDomain: widget.targetDomain,
                  ).execute(widget.context);
                  return;
                }
                if (!_dragging &&
                    (event.position - start).distance >= _dragThreshold) {
                  _dragging = true;
                  StartMarqueeCommand(
                    x: start.dx.round(),
                    y: start.dy.round(),
                  ).execute(widget.context);
                }
                if (_dragging) {
                  _pendingMarqueeX = event.position.dx.round();
                  _pendingMarqueeY = event.position.dy.round();
                  _hasPendingMarquee = true;
                  final now = DateTime.now();
                  if (_lastMarqueeUpdate == null ||
                      now.difference(_lastMarqueeUpdate!) >= _marqueeThrottle) {
                    _flushMarqueeUpdate();
                  }
                  return;
                }
                HoverAtPointCommand(
                  x: event.position.dx.round(),
                  y: event.position.dy.round(),
                  contentRoot: _contentRoot,
                  deeperMode: _deeperPickEnabled,
                  targetDomain: widget.targetDomain,
                ).execute(widget.context);
              },
              onPointerUp: (final event) {
                if (_dragging) {
                  _pendingMarqueeX = event.position.dx.round();
                  _pendingMarqueeY = event.position.dy.round();
                  _hasPendingMarquee = true;
                  _flushMarqueeUpdate();
                  CommitMarqueeCommand(
                    controller: widget.controller,
                  ).execute(widget.context);
                } else {
                  SelectNodeCommand(
                    x: event.position.dx.round(),
                    y: event.position.dy.round(),
                    controller: widget.controller,
                    contentRoot: _contentRoot,
                    preferHoverPreview: _deeperPickEnabled,
                    targetDomain: widget.targetDomain,
                    openBubbleOnSelect: widget.openBubbleOnSelect,
                  ).execute(widget.context);
                }
                _pointerDown = null;
                _dragging = false;
              },
              onPointerCancel: (_) {
                if (_dragging) {
                  CancelMarqueeCommand().execute(widget.context);
                }
                _pointerDown = null;
                _dragging = false;
              },
              child: CustomPaint(
                painter: _LiveEditOverlayPainter(
                  selection: _selectionForDomain,
                  hoverSelection: _hoverForDomain,
                  multiSelection: _marqueeRectForDomain != null
                      ? _marqueeSelectionsForDomain
                      : _multiSelectionForDomain,
                  marqueeRect: _marqueeRectForDomain,
                  deeperPickActive: widget.interactive && _deeperPickEnabled,
                  draftChanges: _draftChangesForDomain,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _RenderHitTestExclusionScope extends RenderProxyBox {
  _RenderHitTestExclusionScope(this._excludedRects);

  List<Rect> _excludedRects;

  set excludedRects(final List<Rect> value) {
    if (_excludedRects.length == value.length) {
      var changed = false;
      for (var index = 0; index < value.length; index += 1) {
        if (_excludedRects[index] != value[index]) {
          changed = true;
          break;
        }
      }
      if (!changed) return;
    }
    _excludedRects = value;
  }

  @override
  bool hitTest(
    final BoxHitTestResult result, {
    required final Offset position,
  }) {
    for (final rect in _excludedRects) {
      if (rect.contains(position)) return false;
    }
    return super.hitTest(result, position: position);
  }
}
