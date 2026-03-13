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

String _semanticsId(final String value) => value
    .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '')
    .toLowerCase();

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

class _FlutterLiveEditHostState extends State<FlutterLiveEditHost> {
  late final LiveEditOrchestrator _orchestrator;
  late final bool _ownsOrchestrator;
  final GlobalKey _contentKey = GlobalKey();

  @override
  Widget build(final BuildContext context) => AnimatedBuilder(
    animation: _orchestrator,
    builder: (final context, final _) => LayoutBuilder(
      builder: (final context, final constraints) => Stack(
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
          if (_orchestrator.overlayVisible &&
              _orchestrator.activeSelection != null)
            _SelectionBubble(
              orchestrator: _orchestrator,
              viewportSize: constraints.biggest,
            ),
          if (_orchestrator.overlayVisible)
            Positioned(
              right: 16,
              top: 16,
              bottom: 16,
              width: 360,
              child: _PropertyPanel(orchestrator: _orchestrator),
            ),
        ],
      ),
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

class _ApplyActions extends StatelessWidget {
  const _ApplyActions({required this.orchestrator, this.compact = false});

  final LiveEditOrchestrator orchestrator;
  final bool compact;

  @override
  Widget build(final BuildContext context) {
    final draftCount = orchestrator.activeDraftChanges.length;
    final busy =
        orchestrator.applyPhase == LiveEditApplyPhase.preparing ||
        orchestrator.applyPhase == LiveEditApplyPhase.applying;
    final needsApproval = orchestrator.needsApproval;
    final canApply = draftCount > 0 && !busy;
    final buttons = _buttons(canApply, busy, needsApproval);
    final wrap = compact
        ? Wrap(spacing: 8, runSpacing: 8, children: buttons)
        : Row(
            children: <Widget>[
              for (
                var index = 0;
                index < buttons.length;
                index += 1
              ) ...<Widget>[
                Expanded(child: buttons[index]),
                if (index + 1 < buttons.length) const SizedBox(width: 8),
              ],
            ],
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Draft changes: $draftCount',
          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 8),
        wrap,
      ],
    );
  }

  List<Widget> _buttons(
    final bool canApply,
    final bool busy,
    final bool needsApproval,
  ) => <Widget>[
    Semantics(
      identifier: 'live_edit_discard_button',
      button: true,
      child: OutlinedButton(
        onPressed: canApply ? orchestrator.undoDraft : null,
        child: const Text('Discard'),
      ),
    ),
    if (orchestrator.hasAgentBackedDrafts ||
        orchestrator.editMode == LiveEditEditMode.ai)
      OutlinedButton(
        onPressed: busy ? null : orchestrator.openAiBubble,
        child: const Text('AI'),
      ),
    Semantics(
      identifier: needsApproval
          ? 'live_edit_approve_apply_button'
          : 'live_edit_apply_button',
      button: true,
      child: FilledButton(
        onPressed: !canApply
            ? null
            : () async {
                if (needsApproval) {
                  await orchestrator.applyDraft(approve: true);
                  return;
                }
                await orchestrator.applyDraft(
                  message: orchestrator.editMode == LiveEditEditMode.ai
                      ? orchestrator.aiComposer
                      : null,
                );
              },
        child: Text(
          busy
              ? 'Working...'
              : needsApproval
              ? 'Approve & Apply'
              : (orchestrator.hasAgentBackedDrafts ? 'Resolve' : 'Apply'),
        ),
      ),
    ),
  ];
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
  const _PropertyPanel({required this.orchestrator});

  final LiveEditOrchestrator orchestrator;

  List<LiveEditSelectionCandidate> get _visibleCandidates =>
      orchestrator.activeSelectionCandidates.take(5).toList(growable: false);

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
                if (_hasText(selection?.source?.file))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${selection!.source!.file}${selection.source?.line == null ? '' : ':${selection.source!.line}'}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
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
                    padding: const EdgeInsets.all(12),
                    children: <Widget>[
                      _PanelSection(
                        title: 'Selection',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              'Mode: ${orchestrator.editMode.wireName}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                for (final candidate
                                    in _visibleCandidates.indexed)
                                  Semantics(
                                    identifier:
                                        'live_edit_candidate_chip_${candidate.$1}',
                                    child: ChoiceChip(
                                      label: Text(candidate.$2.widgetType),
                                      selected: candidate.$2.active,
                                      onSelected: (_) => orchestrator
                                          .selectCandidateAt(candidate.$1),
                                    ),
                                  ),
                                if (orchestrator
                                        .activeSelectionCandidates
                                        .length >
                                    _visibleCandidates.length)
                                  Chip(
                                    label: Text(
                                      '+${orchestrator.activeSelectionCandidates.length - _visibleCandidates.length}',
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Semantics(
                                identifier: 'live_edit_select_parent_button',
                                button: true,
                                child: OutlinedButton.icon(
                                  onPressed:
                                      orchestrator
                                              .activeSelectionCandidates
                                              .length >
                                          1
                                      ? orchestrator.selectParentCandidate
                                      : null,
                                  icon: const Icon(
                                    Icons.arrow_upward,
                                    size: 16,
                                  ),
                                  label: const Text('Select Parent'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _PanelSection(
                        title: 'Properties',
                        child: Column(
                          children: <Widget>[
                            for (final property in selection.propertyGroups)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _PropertyEditorCard(
                                  orchestrator: orchestrator,
                                  property: property,
                                  surface: LiveEditEditSurface.panel,
                                ),
                              ),
                          ],
                        ),
                      ),
                      _PanelSection(
                        title: 'Draft',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (orchestrator.activeDraftChanges.isEmpty)
                              const Text(
                                'No draft changes.',
                                style: TextStyle(fontSize: 12),
                              ),
                            for (final draft in orchestrator.activeDraftChanges)
                              Text(
                                '${draft.propertyId}: ${draft.targetValue}',
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                      _PanelSection(
                        title: 'AI Thread',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _AiComposer(orchestrator: orchestrator),
                            const SizedBox(height: 8),
                            if (orchestrator.historyForActiveSelection.isEmpty)
                              const Text(
                                'No AI activity yet.',
                                style: TextStyle(fontSize: 12),
                              ),
                            for (final entry
                                in orchestrator
                                    .historyForActiveSelection
                                    .reversed
                                    .take(6))
                              _TimelineBubble(entry: entry),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: _ApplyActions(orchestrator: orchestrator),
          ),
        ],
      ),
    );
  }
}

class _PanelSection extends StatelessWidget {
  const _PanelSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(final BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

class _SelectionBubble extends StatelessWidget {
  const _SelectionBubble({
    required this.orchestrator,
    required this.viewportSize,
  });

  final LiveEditOrchestrator orchestrator;
  final Size viewportSize;

  List<LiveEditSelectionCandidate> get _visibleCandidates =>
      orchestrator.activeSelectionCandidates.take(4).toList(growable: false);

  @override
  Widget build(final BuildContext context) {
    final selection = orchestrator.activeSelection;
    final bounds = selection?.bounds;
    if (selection == null || bounds == null) {
      return const SizedBox.shrink();
    }

    const bubbleWidth = 320.0;
    const bubbleHeight = 340.0;
    final placement = _bubblePlacement(
      bounds,
      viewportSize,
      bubbleWidth,
      bubbleHeight,
    );

    return Positioned(
      left: placement.dx,
      top: placement.dy,
      width: bubbleWidth,
      child: Semantics(
        identifier: orchestrator.editMode == LiveEditEditMode.ai
            ? 'live_edit_ai_bubble'
            : 'live_edit_selection_bubble',
        child: Material(
          elevation: 10,
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFFF8FAFC),
          child: Container(
            height: bubbleHeight,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            orchestrator.editMode == LiveEditEditMode.ai
                                ? 'AI Bubble'
                                : 'Selection Bubble',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            selection.widgetType,
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      identifier: 'live_edit_select_parent_button',
                      button: true,
                      child: IconButton(
                        onPressed:
                            orchestrator.activeSelectionCandidates.length > 1
                            ? orchestrator.selectParentCandidate
                            : null,
                        icon: const Icon(Icons.vertical_align_top, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      for (final candidate
                          in _visibleCandidates.indexed) ...<Widget>[
                        Semantics(
                          identifier:
                              'live_edit_candidate_chip_${candidate.$1}',
                          child: ChoiceChip(
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            label: Text(
                              candidate.$2.widgetType,
                              overflow: TextOverflow.ellipsis,
                            ),
                            selected: candidate.$2.active,
                            onSelected: (_) =>
                                orchestrator.selectCandidateAt(candidate.$1),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (orchestrator.activeSelectionCandidates.length >
                          _visibleCandidates.length)
                        Chip(
                          label: Text(
                            '+${orchestrator.activeSelectionCandidates.length - _visibleCandidates.length}',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: orchestrator.editMode == LiveEditEditMode.ai
                        ? _AiBubbleBody(orchestrator: orchestrator)
                        : _SelectionBubbleBody(orchestrator: orchestrator),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Offset _bubblePlacement(
    final LiveEditBounds bounds,
    final Size viewport,
    final double width,
    final double height,
  ) {
    const gap = 12.0;
    final rightSpace = viewport.width - bounds.right - 16;
    final leftSpace = bounds.left - 16;
    double left;
    double top = mathMax(16, bounds.top);

    if (rightSpace >= width) {
      left = bounds.right + gap;
    } else if (leftSpace >= width) {
      left = bounds.left - width - gap;
    } else {
      left = mathMin(viewport.width - width - 16, mathMax(16, bounds.left));
      top = mathMin(viewport.height - height - 16, bounds.bottom + gap);
    }

    top = mathMin(top, viewport.height - height - 16);
    return Offset(left, mathMax(16, top));
  }
}

class _SelectionBubbleBody extends StatelessWidget {
  const _SelectionBubbleBody({required this.orchestrator});

  final LiveEditOrchestrator orchestrator;

  @override
  Widget build(final BuildContext context) {
    final property = orchestrator.activeProperty;
    if (property == null) {
      return const Text('Select a property in the panel to edit inline.');
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PropertyEditorCard(
            orchestrator: orchestrator,
            property: property,
            surface: property.requiresAgentForPersistence
                ? LiveEditEditSurface.aiBubble
                : LiveEditEditSurface.inline,
          ),
          const SizedBox(height: 12),
          _ApplyActions(orchestrator: orchestrator, compact: true),
        ],
      ),
    );
  }
}

class _AiBubbleBody extends StatelessWidget {
  const _AiBubbleBody({required this.orchestrator});

  final LiveEditOrchestrator orchestrator;

  @override
  Widget build(final BuildContext context) => ListView(
    shrinkWrap: true,
    children: <Widget>[
      if (orchestrator.pendingExecutionPlan case final plan?)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                plan.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(plan.summary, style: const TextStyle(fontSize: 12)),
              if (plan.requestedChanges.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                for (final change in plan.requestedChanges)
                  Text('• $change', style: const TextStyle(fontSize: 12)),
              ],
              if (plan.riskNotes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  'Warnings: ${plan.riskNotes.join(' | ')}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9A3412),
                  ),
                ),
              ],
            ],
          ),
        ),
      for (final entry in orchestrator.historyForActiveSelection.reversed.take(
        6,
      ))
        _TimelineBubble(entry: entry),
      const SizedBox(height: 8),
      _AiComposer(orchestrator: orchestrator, autofocus: true),
      const SizedBox(height: 10),
      _ApplyActions(orchestrator: orchestrator, compact: true),
    ],
  );
}

class _TimelineBubble extends StatelessWidget {
  const _TimelineBubble({required this.entry});

  final LiveEditTimelineEntry entry;

  @override
  Widget build(final BuildContext context) {
    final isAssistant = entry.role == 'assistant';
    return Align(
      alignment: isAssistant ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: isAssistant
              ? const Color(0xFFE2E8F0)
              : const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(entry.message, style: const TextStyle(fontSize: 12)),
            if (entry.details.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              for (final detail in entry.details.take(4))
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF475569),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AiComposer extends StatefulWidget {
  const _AiComposer({required this.orchestrator, this.autofocus = false});

  final LiveEditOrchestrator orchestrator;
  final bool autofocus;

  @override
  State<_AiComposer> createState() => _AiComposerState();
}

class _AiComposerState extends State<_AiComposer> {
  late final TextEditingController _controller;

  @override
  Widget build(final BuildContext context) {
    if (_controller.text != widget.orchestrator.aiComposer) {
      _controller.value = TextEditingValue(
        text: widget.orchestrator.aiComposer,
        selection: TextSelection.collapsed(
          offset: widget.orchestrator.aiComposer.length,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          identifier: 'live_edit_ai_prompt_field',
          child: TextField(
            controller: _controller,
            autofocus: widget.autofocus,
            maxLines: 3,
            minLines: 2,
            decoration: const InputDecoration(
              hintText: 'Talk to the agent about this selected element',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: widget.orchestrator.updateAiComposer,
            onSubmitted: (_) => widget.orchestrator.submitAiPrompt(),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.orchestrator.aiComposer);
  }
}

class _PropertyEditorCard extends StatelessWidget {
  const _PropertyEditorCard({
    required this.orchestrator,
    required this.property,
    required this.surface,
  });

  final LiveEditOrchestrator orchestrator;
  final LiveEditPropertyDescriptor property;
  final LiveEditEditSurface surface;

  @override
  Widget build(final BuildContext context) {
    final isActive = orchestrator.activePropertyId == property.id;
    final disabled = !property.editable;

    final cardChild = Ink(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? const Color(0xFF0EA5E9) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      property.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _propertySubtitle(property),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
              if (property.requiresAgentForPersistence)
                const Icon(Icons.smart_toy_outlined, size: 18)
              else if (disabled)
                const Icon(Icons.lock_outline, size: 16),
            ],
          ),
          const SizedBox(height: 10),
          (surface == LiveEditEditSurface.panel)
              ? Semantics(
                  identifier:
                      'live_edit_property_input_${_semanticsId(property.id)}',
                  child: _PropertyEditor(
                    orchestrator: orchestrator,
                    property: property,
                    surface: surface,
                  ),
                )
              : _PropertyEditor(
                  orchestrator: orchestrator,
                  property: property,
                  surface: surface,
                ),
        ],
      ),
    );

    return InkWell(
      onTap: disabled
          ? null
          : () {
              if (surface == LiveEditEditSurface.aiBubble ||
                  property.requiresAgentForPersistence) {
                orchestrator.openAiBubble(property: property);
              } else {
                orchestrator.focusProperty(property);
              }
            },
      borderRadius: BorderRadius.circular(14),
      child: surface == LiveEditEditSurface.panel
          ? Semantics(
              identifier: 'live_edit_property_${_semanticsId(property.id)}',
              child: cardChild,
            )
          : cardChild,
    );
  }

  String _propertySubtitle(final LiveEditPropertyDescriptor property) {
    final value = '${property.value ?? 'unset'}';
    final preview = property.canPreviewExactly
        ? 'exact preview'
        : property.previewMode.wireName;
    final persist = property.requiresAgentForPersistence
        ? 'agent persist'
        : (property.persistable ? 'safe persist' : 'preview only');
    return '$value | $preview | $persist';
  }
}

class _PropertyEditor extends StatelessWidget {
  const _PropertyEditor({
    required this.orchestrator,
    required this.property,
    required this.surface,
  });

  final LiveEditOrchestrator orchestrator;
  final LiveEditPropertyDescriptor property;
  final LiveEditEditSurface surface;

  @override
  Widget build(final BuildContext context) {
    if (!property.editable) {
      return Text(
        '${property.value ?? 'Not editable'}',
        style: const TextStyle(fontSize: 12),
      );
    }
    if (property.requiresAgentForPersistence &&
        surface == LiveEditEditSurface.inline) {
      return Row(
        children: <Widget>[
          const Expanded(
            child: Text(
              'This property needs AI-assisted persistence.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => orchestrator.openAiBubble(property: property),
            child: const Text('Open AI'),
          ),
        ],
      );
    }

    if (property.kind == LiveEditPropertyKind.boolean) {
      final current = property.value == true;
      return SwitchListTile(
        dense: true,
        value: current,
        contentPadding: EdgeInsets.zero,
        title: const Text('Enabled'),
        onChanged: (final value) => orchestrator.updateDraft(
          property: property,
          targetValue: value,
          surface: surface,
        ),
      );
    }

    if (property.options.isNotEmpty ||
        property.kind == LiveEditPropertyKind.enumValue) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final option in property.options)
            ChoiceChip(
              label: Text(option),
              selected: '$option' == '${property.value}',
              onSelected: (_) => orchestrator.updateDraft(
                property: property,
                targetValue: option,
                surface: surface,
              ),
            ),
        ],
      );
    }

    if (property.kind == LiveEditPropertyKind.integer ||
        property.kind == LiveEditPropertyKind.number) {
      return _NumericEditor(
        orchestrator: orchestrator,
        property: property,
        surface: surface,
      );
    }

    if (property.kind == LiveEditPropertyKind.string) {
      final multiline =
          property.prefersMultiline && surface == LiveEditEditSurface.panel;
      return _TextValueEditor(
        orchestrator: orchestrator,
        property: property,
        surface: surface,
        multiline: multiline,
      );
    }

    return Text(
      '${property.value ?? 'Unsupported inline editor'}',
      style: const TextStyle(fontSize: 12),
    );
  }
}

class _NumericEditor extends StatefulWidget {
  const _NumericEditor({
    required this.orchestrator,
    required this.property,
    required this.surface,
  });

  final LiveEditOrchestrator orchestrator;
  final LiveEditPropertyDescriptor property;
  final LiveEditEditSurface surface;

  @override
  State<_NumericEditor> createState() => _NumericEditorState();
}

class _NumericEditorState extends State<_NumericEditor> {
  late final TextEditingController _controller;

  @override
  Widget build(final BuildContext context) {
    final text = '${widget.property.value ?? ''}';
    if (_controller.text != text) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: () => _applyDelta(-widget.property.numericStep),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: widget.surface == LiveEditEditSurface.inline,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (final value) => _submit(value),
          ),
        ),
        IconButton(
          onPressed: () => _applyDelta(widget.property.numericStep),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.property.value ?? ''}');
  }

  void _applyDelta(final double delta) {
    final base = _asDouble(widget.property.value);
    final next = base + delta;
    final targetValue = widget.property.kind == LiveEditPropertyKind.integer
        ? next.round()
        : next;
    widget.orchestrator.updateDraft(
      property: widget.property,
      targetValue: targetValue,
      surface: widget.surface,
    );
  }

  void _submit(final String value) {
    widget.orchestrator.updateDraft(
      property: widget.property,
      targetValue: _coerceValueForProperty(widget.property, value.trim()),
      surface: widget.surface,
    );
  }
}

class _TextValueEditor extends StatefulWidget {
  const _TextValueEditor({
    required this.orchestrator,
    required this.property,
    required this.surface,
    required this.multiline,
  });

  final LiveEditOrchestrator orchestrator;
  final LiveEditPropertyDescriptor property;
  final LiveEditEditSurface surface;
  final bool multiline;

  @override
  State<_TextValueEditor> createState() => _TextValueEditorState();
}

class _TextValueEditorState extends State<_TextValueEditor> {
  late final TextEditingController _controller;

  @override
  Widget build(final BuildContext context) {
    final text = '${widget.property.value ?? ''}';
    if (_controller.text != text) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    return TextField(
      controller: _controller,
      autofocus: widget.surface == LiveEditEditSurface.inline,
      maxLines: widget.multiline ? 4 : 1,
      minLines: widget.multiline ? 3 : 1,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        isDense: true,
        hintText: widget.multiline
            ? 'Edit value here without leaving the panel'
            : 'Edit inline',
      ),
      onChanged: (final value) {
        widget.orchestrator.updateDraft(
          property: widget.property,
          targetValue: _coerceValueForProperty(widget.property, value.trim()),
          surface: widget.surface,
        );
      },
      onSubmitted: (final value) => _submit(value),
      onEditingComplete: () => _submit(_controller.text),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.property.value ?? ''}');
  }

  void _submit(final String value) {
    widget.orchestrator.updateDraft(
      property: widget.property,
      targetValue: _coerceValueForProperty(widget.property, value.trim()),
      surface: widget.surface,
    );
  }
}
