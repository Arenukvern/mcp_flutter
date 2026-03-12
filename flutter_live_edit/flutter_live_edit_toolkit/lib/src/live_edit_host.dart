import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import 'live_edit_controller.dart';
import 'live_edit_orchestrator.dart';

double mathMax(final double left, final double right) =>
    left > right ? left : right;

double mathMin(final double left, final double right) =>
    left < right ? left : right;

double _asDouble(final Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse('$value') ?? 0;
}

Object? _coerceValueForProperty(
  final LiveEditPropertyDescriptor property,
  final String value,
) {
  switch (property.kind) {
    case LiveEditPropertyKind.integer:
      return int.tryParse(value) ?? property.value;
    case LiveEditPropertyKind.number:
      return double.tryParse(value) ?? property.value;
    case LiveEditPropertyKind.boolean:
      final normalized = value.toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    default:
      return value;
  }
}

void _drawDashedRect(final Canvas canvas, final Rect rect, final Paint paint) {
  const dash = 8.0;
  const gap = 4.0;
  for (double x = rect.left; x < rect.right; x += dash + gap) {
    canvas.drawLine(
      Offset(x, rect.top),
      Offset(mathMin(x + dash, rect.right), rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(x, rect.bottom),
      Offset(mathMin(x + dash, rect.right), rect.bottom),
      paint,
    );
  }
  for (double y = rect.top; y < rect.bottom; y += dash + gap) {
    canvas.drawLine(
      Offset(rect.left, y),
      Offset(rect.left, mathMin(y + dash, rect.bottom)),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, y),
      Offset(rect.right, mathMin(y + dash, rect.bottom)),
      paint,
    );
  }
}

bool _hasText(final String? value) => value != null && value.trim().isNotEmpty;

/// Resolves a [BuildContext] that has a [Navigator] in its ancestry, by taking
/// the first child of the [contentKey]'s element (e.g. the Navigator when the
/// host wraps MaterialApp's child). Used so the Live Edit panel can show
/// dialogs and bottom sheets.
BuildContext? _navigatorContextFromContentKey(final GlobalKey contentKey) {
  final contentContext = contentKey.currentContext;
  if (contentContext is! Element || !contentContext.mounted) {
    return null;
  }
  Element? navigatorElement;
  contentContext.visitChildElements((final el) {
    navigatorElement ??= el;
  });
  return navigatorElement;
}

class FlutterLiveEditHost extends StatefulWidget {
  const FlutterLiveEditHost({
    required this.child,
    super.key,
    this.controller,
    this.orchestrator,
    this.applyDraftDelegate,
    this.backendId,
    this.workingDirectory,
    this.intentText,
  });

  final Widget child;
  final LiveEditController? controller;
  final LiveEditOrchestrator? orchestrator;
  final LiveEditApplyDraftDelegate? applyDraftDelegate;
  final String? backendId;
  final String? workingDirectory;
  final String? intentText;

  @override
  State<FlutterLiveEditHost> createState() => _FlutterLiveEditHostState();
}

class _ApplyBar extends StatelessWidget {
  const _ApplyBar({required this.orchestrator, required this.contentKey});

  final LiveEditOrchestrator orchestrator;
  final GlobalKey contentKey;

  @override
  Widget build(final BuildContext context) {
    final draftCount = orchestrator.activeDraftChanges.length;
    final busy =
        orchestrator.applyPhase == LiveEditApplyPhase.preparing ||
        orchestrator.applyPhase == LiveEditApplyPhase.applying;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Draft changes: $draftCount',
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: draftCount == 0 || busy
                      ? null
                      : orchestrator.undoDraft,
                  child: const Text('Discard'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: draftCount == 0 || busy
                      ? null
                      : () => orchestrator.showApprovalSheet(
                          _navigatorContextFromContentKey(contentKey) ??
                              context,
                        ),
                  child: Text(busy ? 'Working...' : 'Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlutterLiveEditHostState extends State<FlutterLiveEditHost> {
  late final LiveEditOrchestrator _orchestrator;
  late final bool _ownsOrchestrator;
  final GlobalKey _contentKey = GlobalKey();

  @override
  Widget build(final BuildContext context) => AnimatedBuilder(
    animation: _orchestrator,
    builder: (final context, final _) => Stack(
      fit: StackFit.expand,
      children: <Widget>[
        KeyedSubtree(key: _contentKey, child: widget.child),
        if (_orchestrator.overlayVisible)
          _LiveEditOverlay(
            orchestrator: _orchestrator,
            contentKey: _contentKey,
          ),
        Positioned(
          left: 16,
          bottom: 16,
          child: _LauncherChip(orchestrator: _orchestrator),
        ),
        if (_orchestrator.overlayVisible)
          Positioned(
            right: 16,
            top: 16,
            bottom: 16,
            width: 320,
            child: _PropertyPanel(
              orchestrator: _orchestrator,
              contentKey: _contentKey,
            ),
          ),
      ],
    ),
  );

  @override
  void dispose() {
    if (_ownsOrchestrator) {
      _orchestrator.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.orchestrator != null) {
      _orchestrator = widget.orchestrator!;
      _ownsOrchestrator = false;
    } else {
      _orchestrator = LiveEditOrchestrator(
        controller: widget.controller,
        applyDraftDelegate: widget.applyDraftDelegate,
        backendId: widget.backendId,
        workingDirectory: widget.workingDirectory,
        intentText: widget.intentText,
      );
      _ownsOrchestrator = true;
    }
  }
}

class _LauncherChip extends StatelessWidget {
  const _LauncherChip({required this.orchestrator});

  final LiveEditOrchestrator orchestrator;

  @override
  Widget build(final BuildContext context) => Material(
    color: Colors.transparent,
    child: Semantics(
      identifier: 'live_edit_launcher_chip',
      child: ActionChip(
        label: Text(
          orchestrator.overlayVisible ? 'Live Edit: ON' : 'Live Edit',
        ),
        avatar: Icon(
          orchestrator.overlayVisible ? Icons.tune : Icons.tune_outlined,
          size: 18,
        ),
        onPressed: () {
          orchestrator.setOverlayEnabled(!orchestrator.overlayVisible);
        },
      ),
    ),
  );
}

class _LiveEditOverlay extends StatelessWidget {
  const _LiveEditOverlay({
    required this.orchestrator,
    required this.contentKey,
  });

  final LiveEditOrchestrator orchestrator;
  final GlobalKey contentKey;

  @override
  Widget build(final BuildContext context) => Positioned.fill(
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (final details) {
        orchestrator.selectNode(details.globalPosition, contentKey: contentKey);
      },
      child: CustomPaint(
        painter: _LiveEditOverlayPainter(
          selection: orchestrator.activeSelection,
          draftChanges: orchestrator.activeDraftChanges,
        ),
      ),
    ),
  );
}

class _LiveEditOverlayPainter extends CustomPainter {
  const _LiveEditOverlayPainter({
    required this.selection,
    required this.draftChanges,
  });

  final LiveEditSelection? selection;
  final List<LiveEditDraftChange> draftChanges;

  @override
  void paint(final Canvas canvas, final Size size) {
    final currentSelection = selection;
    if (currentSelection == null || currentSelection.bounds == null) {
      return;
    }

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
      ..color = const Color(0xFF00A77F);
    canvas.drawRect(baseRect, selectionPaint);

    final ghostRect = _ghostRectFromDrafts(baseRect);
    if (ghostRect != null) {
      final ghostPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFF7A18);
      _drawDashedRect(canvas, ghostRect, ghostPaint);
    }

    final labelText = _buildLabelText();
    if (labelText.isEmpty) {
      return;
    }

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
      mathMax(0, baseRect.top - paragraph.height - 10),
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
      oldDelegate.draftChanges != draftChanges;

  String _buildLabelText() {
    if (draftChanges.isEmpty) {
      return '';
    }
    return draftChanges
        .map((final draft) => '${draft.propertyId}: ${draft.targetValue}')
        .join(' | ');
  }

  Rect? _ghostRectFromDrafts(final Rect baseRect) {
    double? width;
    double? height;
    for (final draft in draftChanges) {
      if (draft.propertyId == 'width') {
        width = _asDouble(draft.targetValue);
      } else if (draft.propertyId == 'height') {
        height = _asDouble(draft.targetValue);
      }
    }
    if (width == null && height == null) {
      return null;
    }
    return Rect.fromLTWH(
      baseRect.left,
      baseRect.top,
      width ?? baseRect.width,
      height ?? baseRect.height,
    );
  }
}

class _PropertyPanel extends StatelessWidget {
  const _PropertyPanel({required this.orchestrator, required this.contentKey});

  final LiveEditOrchestrator orchestrator;
  final GlobalKey contentKey;

  @override
  Widget build(final BuildContext context) {
    final selection = orchestrator.activeSelection;
    final error = orchestrator.lastError;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Live Edit',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selection == null
                      ? 'Tap a widget to select'
                      : '${selection.widgetType} (${selection.nodeId})',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_hasText(error))
            Container(
              color: const Color(0xFFFEF2F2),
              padding: const EdgeInsets.all(10),
              child: Text(
                error!,
                style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12),
              ),
            ),
          Expanded(
            child: selection == null
                ? const Center(child: Text('Tap any widget in the app'))
                : ListView(
                    padding: const EdgeInsets.all(8),
                    children: <Widget>[
                      for (final property in selection.propertyGroups)
                        _PropertyTile(
                          orchestrator: orchestrator,
                          property: property,
                          contentKey: contentKey,
                        ),
                    ],
                  ),
          ),
          _ApplyBar(orchestrator: orchestrator, contentKey: contentKey),
        ],
      ),
    );
  }
}

class _PropertyTile extends StatelessWidget {
  const _PropertyTile({
    required this.orchestrator,
    required this.property,
    required this.contentKey,
  });

  final LiveEditOrchestrator orchestrator;
  final LiveEditPropertyDescriptor property;
  final GlobalKey contentKey;

  @override
  Widget build(final BuildContext context) {
    final disabled = !property.editable;
    final subtitle = StringBuffer()
      ..write('${property.value ?? 'unset'}')
      ..write(' | ')
      ..write(
        property.canPreviewExactly
            ? 'exact preview'
            : property.previewMode.wireName,
      )
      ..write(' | ')
      ..write(
        property.requiresAgentForPersistence ? 'agent persist' : 'safe persist',
      );

    return ListTile(
      enabled: !disabled,
      dense: true,
      title: Text(property.label),
      subtitle: Text(
        subtitle.toString(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: disabled
          ? const Icon(Icons.lock_outline, size: 16)
          : const Icon(Icons.edit_outlined, size: 16),
      onTap: disabled ? null : () => _editProperty(context),
    );
  }

  Future<void> _editProperty(final BuildContext context) async {
    final navContext = _navigatorContextFromContentKey(contentKey) ?? context;
    if (property.options.isNotEmpty) {
      final selected = await showModalBottomSheet<String>(
        context: navContext,
        builder: (final context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: property.options
                .map(
                  (final option) => ListTile(
                    title: Text(option),
                    trailing: option == '${property.value}'
                        ? const Icon(Icons.check, size: 16)
                        : null,
                    onTap: () => Navigator.of(context).pop(option),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      );
      if (selected != null) {
        orchestrator.updateDraft(property: property, targetValue: selected);
      }
      return;
    }

    final controller = TextEditingController(text: '${property.value ?? ''}');
    final entered = await showDialog<String>(
      context: navContext,
      builder: (final context) => AlertDialog(
        title: Text('Edit ${property.label}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (entered == null) {
      return;
    }
    orchestrator.updateDraft(
      property: property,
      targetValue: _coerceValueForProperty(property, entered),
    );
  }
}
