import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import 'live_edit_controller.dart';
import 'live_edit_overlay_theme.dart';
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
    case LiveEditPropertyKind.string:
    case LiveEditPropertyKind.color:
    case LiveEditPropertyKind.enumValue:
    case LiveEditPropertyKind.edgeInsets:
    case LiveEditPropertyKind.alignment:
    case LiveEditPropertyKind.bounds:
    case LiveEditPropertyKind.object:
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

String _basename(final String value) {
  final normalized = value.replaceAll('\\', '/');
  final slashIndex = normalized.lastIndexOf('/');
  if (slashIndex < 0 || slashIndex + 1 >= normalized.length) {
    return normalized;
  }
  return normalized.substring(slashIndex + 1);
}

String _sourceLocationLabel(
  final LiveEditSourceLocation? source, {
  final bool compact = false,
}) {
  if (source == null) {
    return '';
  }
  final file = source.file.trim();
  if (file.isNotEmpty) {
    final label = compact ? _basename(file) : file;
    if (source.line != null) {
      return '$label:${source.line}';
    }
    return label;
  }
  return source.sourceHint?.trim() ?? '';
}

String _semanticsId(final String value) => value
    .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '')
    .toLowerCase();

String _previewLabel(final LiveEditPropertyDescriptor property) {
  if (property.requiresAgentForPersistence) {
    return 'AI only';
  }
  if (property.canPreviewExactly) {
    return 'Live';
  }
  return 'Preview';
}

Color _previewColor(final LiveEditPropertyDescriptor property) {
  if (property.requiresAgentForPersistence) {
    return const Color(0xFF7C2D12);
  }
  if (property.canPreviewExactly) {
    return const Color(0xFF065F46);
  }
  return const Color(0xFF92400E);
}

String _persistLabel(
  final LiveEditPropertyDescriptor property,
  final LiveEditOrchestrator orchestrator,
) => property.requiresAgentForPersistence
    ? orchestrator.currentBackendLabel
    : property.persistable
    ? 'Direct'
    : 'Preview only';

String _bubbleStatusLabel(final LiveEditBubbleStatus status) =>
    switch (status) {
      LiveEditBubbleStatus.editing => 'Draft ready',
      LiveEditBubbleStatus.waiting => 'Applying',
      LiveEditBubbleStatus.needsApproval => 'Applying',
      LiveEditBubbleStatus.applied => 'Applied',
      LiveEditBubbleStatus.failed => 'Failed',
    };

Color _bubbleStatusColor(final LiveEditBubbleStatus status) => switch (status) {
  LiveEditBubbleStatus.editing => const Color(0xFF0F766E),
  LiveEditBubbleStatus.waiting => const Color(0xFF1D4ED8),
  LiveEditBubbleStatus.needsApproval => const Color(0xFF92400E),
  LiveEditBubbleStatus.applied => const Color(0xFF166534),
  LiveEditBubbleStatus.failed => const Color(0xFFB91C1C),
};

String _activityElapsedLabel(final LiveEditActivityEntry activity) {
  final elapsed = DateTime.now().toUtc().difference(activity.timestamp);
  if (elapsed.inSeconds < 5) {
    return activity.inProgress ? 'In progress' : 'Just now';
  }
  if (elapsed.inMinutes < 1) {
    return '${elapsed.inSeconds}s ago';
  }
  return '${elapsed.inMinutes}m ago';
}

class _SelectParentIntent extends Intent {
  const _SelectParentIntent();
}

class _SelectChildIntent extends Intent {
  const _SelectChildIntent();
}

class _CycleCandidateIntent extends Intent {
  const _CycleCandidateIntent(this.delta);

  final int delta;
}

class FlutterLiveEditHost extends StatefulWidget {
  const FlutterLiveEditHost({
    required this.child,
    super.key,
    this.controller,
    this.orchestrator,
    this.applyDraftDelegate,
    this.backendId,
    this.availableBackends = const <LiveEditAgentBackend>[],
    this.workingDirectory,
    this.intentText,
  });

  final Widget child;
  final LiveEditController? controller;
  final LiveEditOrchestrator? orchestrator;
  final LiveEditApplyDraftDelegate? applyDraftDelegate;
  final String? backendId;
  final List<LiveEditAgentBackend> availableBackends;
  final String? workingDirectory;
  final String? intentText;

  @override
  State<FlutterLiveEditHost> createState() => _FlutterLiveEditHostState();
}

class _FlutterLiveEditHostState extends State<FlutterLiveEditHost> {
  late final LiveEditOrchestrator _orchestrator;
  late final bool _ownsOrchestrator;
  final GlobalKey _contentKey = GlobalKey();
  final LiveEditOverlayThemeModel _overlayTheme =
      LiveEditOverlayThemeModel.instance;

  bool get _editableTextHasPrimaryFocus {
    final focus = FocusManager.instance.primaryFocus;
    final context = focus?.context;
    if (context == null) {
      return false;
    }
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null ||
        context.findAncestorStateOfType<EditableTextState>() != null;
  }

  @override
  Widget build(final BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge(<Listenable>[_orchestrator, _overlayTheme]),
    builder: (final context, final _) => Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowUp): _SelectParentIntent(),
        SingleActivator(LogicalKeyboardKey.arrowDown): _SelectChildIntent(),
        SingleActivator(LogicalKeyboardKey.arrowLeft): _CycleCandidateIntent(
          -1,
        ),
        SingleActivator(LogicalKeyboardKey.arrowRight): _CycleCandidateIntent(
          1,
        ),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SelectParentIntent: CallbackAction<_SelectParentIntent>(
            onInvoke: (final _) {
              if (_orchestrator.overlayVisible &&
                  !_editableTextHasPrimaryFocus) {
                _orchestrator.selectParentCandidate();
              }
              return null;
            },
          ),
          _SelectChildIntent: CallbackAction<_SelectChildIntent>(
            onInvoke: (final _) {
              if (_orchestrator.overlayVisible &&
                  !_editableTextHasPrimaryFocus) {
                _orchestrator.selectChildCandidate();
              }
              return null;
            },
          ),
          _CycleCandidateIntent: CallbackAction<_CycleCandidateIntent>(
            onInvoke: (final intent) {
              if (_orchestrator.overlayVisible &&
                  !_editableTextHasPrimaryFocus) {
                _orchestrator.cycleSelectionCandidate(intent.delta);
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Overlay(
            initialEntries: <OverlayEntry>[
              OverlayEntry(
                builder: (final context) => LayoutBuilder(
                  builder: (final context, final constraints) => Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      KeyedSubtree(key: _contentKey, child: widget.child),
                      if (_orchestrator.overlayVisible &&
                          _orchestrator.editingToolScene)
                        _ToolOverlayTarget(
                          orchestrator: _orchestrator,
                          viewportSize: constraints.biggest,
                        ),
                      if (_orchestrator.overlayVisible)
                        _LiveEditOverlay(
                          orchestrator: _orchestrator,
                          contentKey: _contentKey,
                          targetDomain: LiveEditTargetDomain.appScene,
                          interactive: !_orchestrator.editingToolScene,
                        ),
                      if (_orchestrator.overlayVisible &&
                          _orchestrator.editingToolScene)
                        _LiveEditOverlay(
                          orchestrator: _orchestrator,
                          contentKey: _contentKey,
                          targetDomain: LiveEditTargetDomain.toolScene,
                          interactive: true,
                        ),
                      if (_orchestrator.overlayVisible)
                        ..._orchestrator.pinnedBubbleSummaries.map(
                          (final summary) => _PinnedBubblePill(
                            orchestrator: _orchestrator,
                            summary: summary,
                            viewportSize: constraints.biggest,
                          ),
                        ),
                      Positioned(
                        left: 16,
                        bottom: 16,
                        child: _LauncherChip(orchestrator: _orchestrator),
                      ),
                      if (_orchestrator.overlayVisible &&
                          _orchestrator.activeSelection != null &&
                          !_orchestrator.activeBubbleResolved)
                        _SelectionBubble(
                          orchestrator: _orchestrator,
                          viewportSize: constraints.biggest,
                        ),
                      if (_orchestrator.overlayVisible)
                        Builder(
                          builder: (final context) {
                            if (_orchestrator.editingToolScene) {
                              final panelOffset = _orchestrator.panelPlacement(
                                viewport: constraints.biggest,
                              );
                              return Positioned(
                                left: panelOffset.dx,
                                top: panelOffset.dy,
                                width: _orchestrator.panelWidth,
                                height: _orchestrator.panelHeight,
                                child: _EditorPanelSurface(
                                  orchestrator: _orchestrator,
                                ),
                              );
                            }
                            return Positioned(
                              right: 16,
                              top: 16,
                              bottom: 16,
                              width: _overlayTheme.panelWidth(
                                expanded: _orchestrator.panelExpanded,
                              ),
                              child: _PanelSurface(orchestrator: _orchestrator),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
        availableBackends: widget.availableBackends,
        workingDirectory: widget.workingDirectory,
        intentText: widget.intentText,
      );
      _ownsOrchestrator = true;
    }
  }

  @override
  void didUpdateWidget(covariant final FlutterLiveEditHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.availableBackends != oldWidget.availableBackends) {
      _orchestrator.setAvailableBackends(widget.availableBackends);
    }
    if (_ownsOrchestrator &&
        widget.backendId != oldWidget.backendId &&
        widget.backendId != null) {
      _orchestrator.setBackend(widget.backendId!);
    }
  }
}

class _ApplyActions extends StatelessWidget {
  const _ApplyActions({
    required this.orchestrator,
    this.compact = false,
    this.semanticsPrefix,
  });

  final LiveEditOrchestrator orchestrator;
  final bool compact;
  final String? semanticsPrefix;

  @override
  Widget build(final BuildContext context) {
    final draftCount = orchestrator.activeDraftChanges.length;
    final stagedSummary = orchestrator.stagedRequestSummary;
    final busy = orchestrator.isApplyingBusy;
    final canApply = orchestrator.canTriggerApply && !busy;
    final buttons = _buttons(canApply, busy);
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
        if (_hasText(stagedSummary)) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            stagedSummary!,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 8),
        wrap,
      ],
    );
  }

  List<Widget> _buttons(final bool canApply, final bool busy) => <Widget>[
    Semantics(
      identifier: _actionId('discard_button'),
      button: true,
      child: OutlinedButton(
        onPressed: canApply ? orchestrator.undoDraft : null,
        child: const Text('Discard'),
      ),
    ),
    if (orchestrator.hasAgentBackedDrafts ||
        orchestrator.editMode == LiveEditEditMode.ai ||
        orchestrator.activeSelection != null)
      OutlinedButton(
        onPressed: busy ? null : orchestrator.openAiBubble,
        child: const Text('AI'),
      ),
    Semantics(
      identifier: _actionId('apply_button'),
      button: true,
      child: FilledButton(
        onPressed: !canApply
            ? null
            : () async {
                await orchestrator.applyDraft(
                  message: orchestrator.canSubmitAiPrompt
                      ? orchestrator.aiComposer
                      : null,
                );
              },
        child: Text(
          busy
              ? 'Working...'
              : (orchestrator.canSubmitAiPrompt &&
                    !orchestrator.hasDraftChanges)
              ? 'Send'
              : 'Apply',
        ),
      ),
    ),
    if (orchestrator.canApplyAllBubbles)
      Semantics(
        identifier: _actionId('apply_all_button'),
        button: true,
        child: OutlinedButton(
          onPressed: orchestrator.applyAllBubbles,
          child: Text('Apply all (${orchestrator.pendingBubbleCount})'),
        ),
      ),
    if (orchestrator.canResolveActiveBubble)
      Semantics(
        identifier: _actionId('done_button'),
        button: true,
        child: FilledButton.tonal(
          onPressed: orchestrator.resolveActiveBubble,
          child: const Text('Done'),
        ),
      ),
  ];

  String _actionId(final String suffix) {
    final prefix = semanticsPrefix;
    if (_hasText(prefix)) {
      return '${prefix!}_$suffix';
    }
    return 'live_edit_$suffix';
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

class _ToolOverlayTarget extends StatelessWidget {
  const _ToolOverlayTarget({
    required this.orchestrator,
    required this.viewportSize,
  });

  final LiveEditOrchestrator orchestrator;
  final Size viewportSize;

  @override
  Widget build(final BuildContext context) {
    final theme = LiveEditOverlayThemeModel.instance;
    final bubbleSurfaceId = orchestrator.editMode == LiveEditEditMode.ai
        ? kLiveEditAiBubbleSurfaceId
        : kLiveEditSelectionBubbleSurfaceId;
    final bubbleStyle = theme.styleFor(bubbleSurfaceId);
    final bubblePosition = theme.positionFor(bubbleSurfaceId);
    final panelSurfaceId = orchestrator.panelExpanded
        ? kLiveEditPanelExpandedSurfaceId
        : kLiveEditPanelRailSurfaceId;
    final panelStyle = theme.styleFor(panelSurfaceId);
    final panelPosition = theme.positionFor(panelSurfaceId);
    final panelHeight = panelStyle.height ?? (viewportSize.height - 96);

    return IgnorePointer(
      ignoring: true,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: bubblePosition.dx,
            top: bubblePosition.dy,
            width: bubbleStyle.width ?? 300,
            child: Material(
              key: theme.keyFor(bubbleSurfaceId),
              color: bubbleStyle.backgroundColor.withOpacity(0.92),
              elevation: 2,
              borderRadius: BorderRadius.circular(bubbleStyle.cornerRadius),
              child: Container(
                height: bubbleStyle.height ?? 340,
                padding: bubbleStyle.padding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(bubbleStyle.cornerRadius),
                  border: Border.all(color: bubbleStyle.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (bubbleStyle.showDragHandle)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 28,
                          height: 3,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF94A3B8),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    Text(
                      bubbleSurfaceId == kLiveEditAiBubbleSurfaceId
                          ? 'AI Bubble'
                          : 'Selection Bubble',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      key: theme.keyFor(kLiveEditStatusBadgeSurfaceId),
                      width: 88,
                      padding: theme
                          .styleFor(kLiveEditStatusBadgeSurfaceId)
                          .padding,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(
                          theme
                              .styleFor(kLiveEditStatusBadgeSurfaceId)
                              .cornerRadius,
                        ),
                      ),
                      child: const Text(
                        'Live',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Container(
                        key: theme.keyFor(kLiveEditPropertyEditorRowSurfaceId),
                        padding: theme
                            .styleFor(kLiveEditPropertyEditorRowSurfaceId)
                            .padding,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            theme
                                .styleFor(kLiveEditPropertyEditorRowSurfaceId)
                                .cornerRadius,
                          ),
                          border: Border.all(
                            color: theme
                                .styleFor(kLiveEditPropertyEditorRowSurfaceId)
                                .borderColor,
                          ),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Property Row',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Overlay target draft preview',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: panelPosition.dx,
            top: panelPosition.dy,
            width: panelStyle.width ?? 312,
            height: panelHeight,
            child: Material(
              key: theme.keyFor(panelSurfaceId),
              color: panelStyle.backgroundColor.withOpacity(0.94),
              elevation: 2,
              borderRadius: BorderRadius.circular(panelStyle.cornerRadius),
              child: Container(
                padding: panelStyle.padding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(panelStyle.cornerRadius),
                  border: Border.all(color: panelStyle.borderColor),
                ),
                child: orchestrator.panelExpanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Text(
                            'Tool Overlay Panel',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            key: theme.keyFor(
                              kLiveEditBackendSwitcherSurfaceId,
                            ),
                            padding: theme
                                .styleFor(kLiveEditBackendSwitcherSurfaceId)
                                .padding,
                            decoration: BoxDecoration(
                              color: theme
                                  .styleFor(kLiveEditBackendSwitcherSurfaceId)
                                  .backgroundColor,
                              borderRadius: BorderRadius.circular(
                                theme
                                    .styleFor(kLiveEditBackendSwitcherSurfaceId)
                                    .cornerRadius,
                              ),
                              border: Border.all(
                                color: theme
                                    .styleFor(kLiveEditBackendSwitcherSurfaceId)
                                    .borderColor,
                              ),
                            ),
                            child: Text(
                              'Backend: ${orchestrator.currentBackendLabel}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Icon(
                          Icons.tune,
                          size: 18,
                          color: theme
                              .styleFor(kLiveEditPanelRailSurfaceId)
                              .borderColor,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveEditOverlay extends StatefulWidget {
  const _LiveEditOverlay({
    required this.orchestrator,
    required this.contentKey,
    required this.targetDomain,
    required this.interactive,
  });

  final LiveEditOrchestrator orchestrator;
  final GlobalKey contentKey;
  final LiveEditTargetDomain targetDomain;
  final bool interactive;

  @override
  State<_LiveEditOverlay> createState() => _LiveEditOverlayState();
}

class _LiveEditOverlayState extends State<_LiveEditOverlay> {
  static const double _dragThreshold = 8;
  Offset? _pointerDown;
  bool _dragging = false;

  LiveEditSelection? get _selectionForDomain =>
      widget.orchestrator.controller.selectionForDomain(
        targetDomain: widget.targetDomain,
        sessionId: widget.orchestrator.activeSessionId,
      );

  LiveEditSelection? get _hoverForDomain =>
      widget.orchestrator.controller.hoverSelectionForDomain(
        targetDomain: widget.targetDomain,
        sessionId: widget.orchestrator.activeSessionId,
      );

  Rect? get _marqueeRectForDomain =>
      widget.orchestrator.controller.marqueeRectForDomain(
        targetDomain: widget.targetDomain,
        sessionId: widget.orchestrator.activeSessionId,
      );

  List<LiveEditSelection> get _marqueeSelectionsForDomain =>
      widget.orchestrator.controller.marqueeSelectionsForDomain(
        targetDomain: widget.targetDomain,
        sessionId: widget.orchestrator.activeSessionId,
      );

  List<LiveEditDraftChange> get _draftChangesForDomain =>
      widget.orchestrator.controller.draftChangesForDomain(
        targetDomain: widget.targetDomain,
        sessionId: widget.orchestrator.activeSessionId,
      );

  List<LiveEditSelection> get _multiSelectionForDomain =>
      widget.orchestrator.controller.multiSelectionForDomain(
        targetDomain: widget.targetDomain,
        sessionId: widget.orchestrator.activeSessionId,
      );

  @override
  Widget build(final BuildContext context) => Positioned.fill(
    child: Focus(
      autofocus: true,
      child: MouseRegion(
        onHover: widget.interactive
            ? (final event) {
                widget.orchestrator.hoverNode(
                  event.position,
                  contentKey: widget.contentKey,
                  deeperMode: widget.orchestrator.deeperPickEnabled,
                );
              }
            : null,
        onExit: widget.interactive ? (_) => widget.orchestrator.clearHover() : null,
        child: IgnorePointer(
          ignoring: !widget.interactive,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (final event) {
              _pointerDown = event.position;
              _dragging = false;
              widget.orchestrator.hoverNode(
                event.position,
                contentKey: widget.contentKey,
                deeperMode: widget.orchestrator.deeperPickEnabled,
              );
            },
            onPointerMove: (final event) {
              final start = _pointerDown;
              if (start == null) {
                widget.orchestrator.hoverNode(
                  event.position,
                  contentKey: widget.contentKey,
                  deeperMode: widget.orchestrator.deeperPickEnabled,
                );
                return;
              }
              if (!_dragging &&
                  (event.position - start).distance >= _dragThreshold) {
                _dragging = true;
                widget.orchestrator.startMarquee(start);
              }
              if (_dragging) {
                widget.orchestrator.updateMarquee(
                  event.position,
                  contentKey: widget.contentKey,
                );
                return;
              }
              widget.orchestrator.hoverNode(
                event.position,
                contentKey: widget.contentKey,
                deeperMode: widget.orchestrator.deeperPickEnabled,
              );
            },
            onPointerUp: (final event) {
              if (_dragging) {
                widget.orchestrator.commitMarquee();
              } else {
                widget.orchestrator.selectNode(
                  event.position,
                  contentKey: widget.contentKey,
                  preferHoverPreview: widget.orchestrator.deeperPickEnabled,
                );
              }
              _pointerDown = null;
              _dragging = false;
            },
            onPointerCancel: (_) {
              if (_dragging) {
                widget.orchestrator.cancelMarquee();
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
                deeperPickActive:
                    widget.interactive &&
                    widget.orchestrator.deeperPickEnabled,
                draftChanges: _draftChangesForDomain,
              ),
            ),
          ),
        ),
      ),
    ),
  );
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
      oldDelegate.hoverSelection != hoverSelection ||
      oldDelegate.multiSelection != multiSelection ||
      oldDelegate.marqueeRect != marqueeRect ||
      oldDelegate.deeperPickActive != deeperPickActive ||
      oldDelegate.draftChanges != draftChanges;

  void _paintHover(final Canvas canvas) {
    final hovered = hoverSelection?.bounds;
    if (hovered == null) {
      return;
    }
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

  void _paintMultiSelection(final Canvas canvas) {
    if (multiSelection.length < 2) {
      return;
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFF97316);
    for (final selection in multiSelection) {
      final bounds = selection.bounds;
      if (bounds == null) {
        continue;
      }
      canvas.drawRect(
        Rect.fromLTRB(bounds.left, bounds.top, bounds.right, bounds.bottom),
        paint,
      );
    }
  }

  void _paintMarquee(final Canvas canvas) {
    final rect = marqueeRect;
    if (rect == null) {
      return;
    }
    canvas.drawRect(rect, Paint()..color = const Color(0x1A2563EB));
    _drawDashedRect(
      canvas,
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF2563EB),
    );
  }

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

class _PanelSurface extends StatelessWidget {
  const _PanelSurface({required this.orchestrator});

  final LiveEditOrchestrator orchestrator;

  @override
  Widget build(final BuildContext context) => orchestrator.panelExpanded
      ? _PropertyPanel(
          key: const ValueKey<String>('expanded_panel'),
          orchestrator: orchestrator,
        )
      : _PanelRail(
          key: const ValueKey<String>('rail_panel'),
          orchestrator: orchestrator,
        );
}

class _EditorPanelSurface extends StatelessWidget {
  const _EditorPanelSurface({required this.orchestrator});

  final LiveEditOrchestrator orchestrator;

  @override
  Widget build(final BuildContext context) => Stack(
    children: <Widget>[
      Positioned.fill(child: _PanelSurface(orchestrator: orchestrator)),
      Positioned(
        top: 6,
        left: 0,
        right: 0,
        child: _PanelDragHandle(
          onPanUpdate: (final details) => orchestrator.dragPanel(details.delta),
        ),
      ),
      Positioned(
        right: 6,
        bottom: 6,
        child: _PanelResizeHandle(
          onPanUpdate: (final details) => orchestrator.resizePanel(
            width: orchestrator.panelWidth + details.delta.dx,
            height: orchestrator.panelHeight + details.delta.dy,
          ),
        ),
      ),
    ],
  );
}

class _PanelRail extends StatelessWidget {
  const _PanelRail({required this.orchestrator, super.key});

  final LiveEditOrchestrator orchestrator;

  @override
  Widget build(final BuildContext context) {
    final theme = LiveEditOverlayThemeModel.instance.styleFor(
      kLiveEditPanelRailSurfaceId,
    );
    return Card(
      color: theme.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.cornerRadius),
        side: BorderSide(color: theme.borderColor),
      ),
      child: Semantics(
        identifier: 'live_edit_panel_rail',
        child: Padding(
          padding: theme.padding,
          child: Column(
            children: <Widget>[
              Semantics(
                identifier: 'live_edit_panel_expand_button',
                button: true,
                child: IconButton(
                  tooltip: 'Expand inspector',
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  onPressed: orchestrator.expandPanel,
                  icon: const Icon(Icons.chevron_left),
                ),
              ),
              Transform.scale(
                scale: 0.72,
                child: Switch(
                  value: orchestrator.debugModeEnabled,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: orchestrator.setDebugModeEnabled,
                ),
              ),
              Text(
                orchestrator.hasBackendChoice
                    ? orchestrator.currentBackendLabel
                          .substring(0, 1)
                          .toUpperCase()
                    : 'DBG',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: orchestrator.hasBackendChoice
                      ? const Color(0xFF1D4ED8)
                      : orchestrator.debugModeEnabled
                      ? const Color(0xFF0F766E)
                      : const Color(0xFF64748B),
                ),
              ),
              if (orchestrator.hasBackendChoice) ...<Widget>[
                const SizedBox(height: 6),
                _BackendSwitcher(orchestrator: orchestrator, rail: true),
              ],
              const SizedBox(height: 6),
              if (orchestrator.activeSelection != null)
                Column(
                  children: <Widget>[
                    _RailStatusDot(
                      label: orchestrator.activeSelection!.widgetType,
                      status: orchestrator.bubbleStatusForActiveSelection,
                      active: true,
                      onTap: () => orchestrator.selectTrackedBubble(
                        orchestrator.activeSelection!.nodeId,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        orchestrator.currentActivity?.label ??
                            _bubbleStatusLabel(
                              orchestrator.bubbleStatusForActiveSelection,
                            ),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  itemBuilder: (final context, final index) {
                    final summary = orchestrator.bubbleSummaries[index];
                    return _RailStatusDot(
                      label: summary.label,
                      status: summary.status,
                      active: summary.active,
                      onTap: () =>
                          orchestrator.selectTrackedBubble(summary.nodeId),
                    );
                  },
                  separatorBuilder: (final context, final index) =>
                      const SizedBox(height: 6),
                  itemCount: orchestrator.bubbleSummaries.length,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailStatusDot extends StatelessWidget {
  const _RailStatusDot({
    required this.label,
    required this.status,
    required this.active,
    required this.onTap,
  });

  final String label;
  final LiveEditBubbleStatus status;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) => Tooltip(
    message: '$label • ${_bubbleStatusLabel(status)}',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE0F2FE) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? const Color(0xFF0EA5E9) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          children: <Widget>[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _bubbleStatusColor(status),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label.isEmpty ? '?' : label[0].toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PropertyPanel extends StatelessWidget {
  const _PropertyPanel({required this.orchestrator, super.key});

  final LiveEditOrchestrator orchestrator;

  List<LiveEditSelectionCandidate> get _visibleCandidates =>
      orchestrator.activeSelectionCandidates.take(3).toList(growable: false);

  @override
  Widget build(final BuildContext context) {
    final theme = LiveEditOverlayThemeModel.instance.styleFor(
      kLiveEditPanelExpandedSurfaceId,
    );
    final selection = orchestrator.activeSelection;
    final properties = orchestrator.effectiveProperties;
    final error = orchestrator.lastError;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: theme.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.cornerRadius),
        side: BorderSide(color: theme.borderColor),
      ),
      child: Semantics(
        identifier: 'live_edit_panel',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Live Edit',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selection == null
                              ? 'Tap a widget'
                              : orchestrator.hasMultiSelection
                              ? '${orchestrator.activeMultiSelection.length} widgets • ${orchestrator.currentActivity?.label ?? _bubbleStatusLabel(orchestrator.bubbleStatusForActiveSelection)}'
                              : '${selection.widgetType} • ${orchestrator.currentActivity?.label ?? _bubbleStatusLabel(orchestrator.bubbleStatusForActiveSelection)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (orchestrator.debugModeEnabled &&
                            _hasText(_sourceLocationLabel(selection?.source)))
                          Text(
                            _sourceLocationLabel(
                              selection?.source,
                              compact: true,
                            ),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (orchestrator.debugModeEnabled &&
                            !_hasText(_sourceLocationLabel(selection?.source)))
                          const Text(
                            'No concrete source context',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        if (orchestrator.hasBackendChoice) ...<Widget>[
                          const SizedBox(height: 6),
                          _ToolDomainSwitch(orchestrator: orchestrator),
                          const SizedBox(height: 6),
                          _BackendSwitcher(orchestrator: orchestrator),
                        ],
                        if (!orchestrator.hasBackendChoice) ...<Widget>[
                          const SizedBox(height: 6),
                          _ToolDomainSwitch(orchestrator: orchestrator),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.bug_report_outlined,
                        color: Colors.white70,
                        size: 14,
                      ),
                      Transform.scale(
                        scale: 0.72,
                        child: Switch(
                          value: orchestrator.debugModeEnabled,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: orchestrator.setDebugModeEnabled,
                        ),
                      ),
                    ],
                  ),
                  Semantics(
                    identifier: 'live_edit_panel_collapse_button',
                    button: true,
                    child: IconButton(
                      tooltip: 'Collapse inspector',
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      color: Colors.white,
                      onPressed: orchestrator.collapsePanel,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ),
                ],
              ),
            ),
            if (_hasText(error))
              Container(
                color: const Color(0xFFFEF2F2),
                padding: const EdgeInsets.all(8),
                child: Text(
                  error!,
                  style: const TextStyle(
                    color: Color(0xFF991B1B),
                    fontSize: 11,
                  ),
                ),
              ),
            Expanded(
              child: selection == null
                  ? const Center(
                      child: Text(
                        'Tap any widget in the app',
                        style: TextStyle(fontSize: 11),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(8),
                      children: <Widget>[
                        _PanelSection(
                          title: 'Bubbles',
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: <Widget>[
                              for (final summary
                                  in orchestrator.bubbleSummaries)
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _bubbleStatusColor(summary.status),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  label: Text(
                                    summary.active
                                        ? '${summary.label} • active'
                                        : summary.label,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () => orchestrator
                                      .selectTrackedBubble(summary.nodeId),
                                ),
                            ],
                          ),
                        ),
                        _PanelSection(
                          title: 'Agent',
                          child: _InferenceConfigEditor(
                            orchestrator: orchestrator,
                          ),
                        ),
                        _PanelSection(
                          title: 'Selection',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              SwitchListTile.adaptive(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Deeper pick',
                                  style: TextStyle(fontSize: 11),
                                ),
                                value: orchestrator.deeperPickEnabled,
                                onChanged: orchestrator.setDeeperPickEnabled,
                              ),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: <Widget>[
                                  for (final candidate
                                      in _visibleCandidates.indexed)
                                    Semantics(
                                      identifier:
                                          'live_edit_candidate_chip_${candidate.$1}',
                                      child: ChoiceChip(
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        label: Text(
                                          _candidateLabel(candidate.$1),
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        selected: candidate.$2.active,
                                        onSelected: (_) => orchestrator
                                            .selectCandidateAt(candidate.$1),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Semantics(
                                      identifier:
                                          'live_edit_select_parent_button',
                                      button: true,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                        ),
                                        onPressed:
                                            orchestrator
                                                    .activeSelectionCandidates
                                                    .length >
                                                1
                                            ? orchestrator.selectParentCandidate
                                            : null,
                                        icon: const Icon(
                                          Icons.arrow_upward,
                                          size: 14,
                                        ),
                                        label: const Text(
                                          'Parent',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                      ),
                                      onPressed:
                                          orchestrator
                                                  .activeSelectionCandidates
                                                  .length >
                                              1
                                          ? orchestrator.selectChildCandidate
                                          : null,
                                      icon: const Icon(
                                        Icons.arrow_downward,
                                        size: 14,
                                      ),
                                      label: const Text(
                                        'Child',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (orchestrator.debugModeEnabled &&
                                  _hasText(
                                    _sourceLocationLabel(selection.source),
                                  )) ...<Widget>[
                                const SizedBox(height: 6),
                                Text(
                                  'Code: ${_sourceLocationLabel(selection.source)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_hasText(selection.source?.sourceHint))
                                  Text(
                                    selection.source!.sourceHint!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF64748B),
                                    ),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                              if (orchestrator.debugModeEnabled &&
                                  !_hasText(
                                    _sourceLocationLabel(selection.source),
                                  )) ...<Widget>[
                                const SizedBox(height: 6),
                                const Text(
                                  'Code: No concrete source context',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        _PanelSection(
                          title: 'Activity',
                          child: _AgentActivityPanel(
                            orchestrator: orchestrator,
                            dense: true,
                          ),
                        ),
                        _PanelSection(
                          title: 'Properties',
                          child: Column(
                            children: <Widget>[
                              if (orchestrator.hasMultiSelection &&
                                  properties.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    'No shared editable properties for this selection.',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              for (final property in properties)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
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
                          title: 'Thread',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              _AiComposer(orchestrator: orchestrator),
                              if (_hasText(
                                orchestrator.stagedRequestSummary,
                              )) ...<Widget>[
                                const SizedBox(height: 6),
                                _PendingRequestCard(
                                  summary: orchestrator.stagedRequestSummary!,
                                ),
                              ],
                              const SizedBox(height: 6),
                              for (final entry
                                  in orchestrator
                                      .historyForActiveSelection
                                      .reversed
                                      .take(5))
                                _TimelineBubble(entry: entry),
                            ],
                          ),
                        ),
                        if (orchestrator.debugModeEnabled)
                          _PanelSection(
                            title: 'Prompt',
                            child: _SelectedPromptCard(
                              promptText:
                                  orchestrator.debugPromptForActiveSelection,
                            ),
                          ),
                        if (orchestrator.debugModeEnabled)
                          _PanelSection(
                            title: 'Debug Log',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                for (final entry
                                    in orchestrator
                                        .debugTimelineForActiveSelection
                                        .reversed
                                        .take(10))
                                  _TimelineBubble(entry: entry, debug: true),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _candidateLabel(final int index) => switch (index) {
    0 => 'Selected',
    1 => 'Parent',
    2 => 'Child',
    _ => 'Alt ${index + 1}',
  };
}

class _PanelSection extends StatelessWidget {
  const _PanelSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(final BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
    ),
  );
}

class _PinnedBubblePill extends StatelessWidget {
  const _PinnedBubblePill({
    required this.orchestrator,
    required this.summary,
    required this.viewportSize,
  });

  final LiveEditOrchestrator orchestrator;
  final LiveEditBubbleSummary summary;
  final Size viewportSize;

  @override
  Widget build(final BuildContext context) {
    final bounds = summary.bounds;
    if (bounds == null) {
      return const SizedBox.shrink();
    }
    final left = mathMin(viewportSize.width - 28, mathMax(8, bounds.right + 6));
    final top = mathMin(viewportSize.height - 28, mathMax(8, bounds.top));
    return Positioned(
      left: left,
      top: top,
      child: Semantics(
        identifier: 'live_edit_pinned_bubble_${summary.nodeId}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => orchestrator.selectTrackedBubble(summary.nodeId),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: _bubbleStatusColor(summary.status),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionBubble extends StatelessWidget {
  const _SelectionBubble({
    required this.orchestrator,
    required this.viewportSize,
  });

  final LiveEditOrchestrator orchestrator;
  final Size viewportSize;

  List<LiveEditSelectionCandidate> get _visibleCandidates =>
      orchestrator.activeSelectionCandidates.take(3).toList(growable: false);

  @override
  Widget build(final BuildContext context) {
    final overlayTheme = LiveEditOverlayThemeModel.instance;
    final selection = orchestrator.activeSelection;
    final bounds = selection?.bounds;
    if (selection == null || bounds == null) {
      return const SizedBox.shrink();
    }

    final status = orchestrator.bubbleStatusForActiveSelection;
    final aiMode = orchestrator.editMode == LiveEditEditMode.ai;
    final surfaceId = aiMode
        ? kLiveEditAiBubbleSurfaceId
        : kLiveEditSelectionBubbleSurfaceId;
    final surfaceTheme = overlayTheme.styleFor(surfaceId);
    final bubbleWidth = overlayTheme.selectionBubbleWidth(aiMode: aiMode);
    final bubbleHeight = overlayTheme.selectionBubbleHeight(aiMode: aiMode);
    final autoPlacement = orchestrator.autoBubblePlacement(
      bounds: bounds,
      viewport: viewportSize,
    );
    final placement = orchestrator.bubblePlacement(
      bounds: bounds,
      viewport: viewportSize,
    );

    return Positioned(
      left: placement.dx,
      top: placement.dy,
      width: bubbleWidth,
      child: Semantics(
        identifier: aiMode
            ? 'live_edit_ai_bubble'
            : 'live_edit_selection_bubble',
        child: Material(
          elevation: 10,
          borderRadius: BorderRadius.circular(surfaceTheme.cornerRadius),
          color: surfaceTheme.backgroundColor,
          child: Container(
            height: bubbleHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(surfaceTheme.cornerRadius),
              border: Border.all(color: surfaceTheme.borderColor),
            ),
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: surfaceTheme.padding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (surfaceTheme.showDragHandle)
                        _BubbleDragHandle(
                          alignment: autoPlacement.dx > bounds.left
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          onPanUpdate: (final details) {
                            orchestrator.dragBubble(details.delta);
                          },
                        ),
                      if (status == LiveEditBubbleStatus.applied)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Text(
                            'Last apply succeeded. Review the updated node or discard the session draft state.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF065F46),
                            ),
                          ),
                        ),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  orchestrator.hasMarqueePreview
                                      ? 'Selecting ${orchestrator.marqueePreviewSelections.length}'
                                      : orchestrator.currentActivity?.label ??
                                            _bubbleStatusLabel(status),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  orchestrator.hasMultiSelection
                                      ? '${orchestrator.activeMultiSelection.length} widgets • ${orchestrator.activeProperty?.label ?? 'shared'}'
                                      : orchestrator.hasMarqueePreview
                                      ? 'Drag selection preview • ${orchestrator.marqueePreviewSelections.length} hits'
                                      : '${selection.widgetType} • ${orchestrator.activeProperty?.label ?? 'node'}',
                                  style: const TextStyle(
                                    color: Color(0xFF475569),
                                    fontSize: 12,
                                  ),
                                ),
                                if (orchestrator.debugModeEnabled &&
                                    _hasText(
                                      _sourceLocationLabel(
                                        selection.source,
                                        compact: true,
                                      ),
                                    ))
                                  Text(
                                    _sourceLocationLabel(
                                      selection.source,
                                      compact: true,
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (orchestrator.debugModeEnabled &&
                                    !_hasText(
                                      _sourceLocationLabel(
                                        selection.source,
                                        compact: true,
                                      ),
                                    ))
                                  const Text(
                                    'No concrete source context',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 11,
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
                                  orchestrator
                                          .activeSelectionCandidates
                                          .length >
                                      1
                                  ? orchestrator.selectParentCandidate
                                  : null,
                              icon: const Icon(
                                Icons.vertical_align_top,
                                size: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Sticky deeper pick',
                            onPressed: () => orchestrator.setDeeperPickEnabled(
                              !orchestrator.deeperPickEnabled,
                            ),
                            icon: Icon(
                              orchestrator.deeperPickEnabled
                                  ? Icons.layers
                                  : Icons.layers_outlined,
                              size: 18,
                            ),
                          ),
                          IconButton(
                            onPressed:
                                orchestrator.activeSelectionCandidates.length >
                                    1
                                ? orchestrator.selectChildCandidate
                                : null,
                            icon: const Icon(
                              Icons.vertical_align_bottom,
                              size: 18,
                            ),
                          ),
                          Semantics(
                            identifier: 'live_edit_bubble_hide_button',
                            button: true,
                            child: IconButton(
                              tooltip: 'Hide bubble',
                              onPressed: orchestrator.hideActiveBubble,
                              icon: const Icon(Icons.visibility_off_outlined),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: surfaceTheme.gap),
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
                                    _candidateLabel(candidate.$1),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  selected: candidate.$2.active,
                                  onSelected: (_) => orchestrator
                                      .selectCandidateAt(candidate.$1),
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
                      SizedBox(height: surfaceTheme.gap),
                      Expanded(
                        child: switch (status) {
                          LiveEditBubbleStatus.waiting => _WaitingBubbleBody(
                            orchestrator: orchestrator,
                          ),
                          LiveEditBubbleStatus.failed => _WaitingBubbleBody(
                            orchestrator: orchestrator,
                          ),
                          LiveEditBubbleStatus.applied => _AppliedBubbleBody(
                            orchestrator: orchestrator,
                          ),
                          _ when orchestrator.editMode == LiveEditEditMode.ai =>
                            _AiBubbleBody(orchestrator: orchestrator),
                          _ => _SelectionBubbleBody(orchestrator: orchestrator),
                        },
                      ),
                    ],
                  ),
                ),
                if (surfaceTheme.showResizeHandle)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: _BubbleResizeHandle(
                      onPanUpdate: (final details) {
                        orchestrator.resizeBubble(
                          width: bubbleWidth + details.delta.dx,
                          height: bubbleHeight + details.delta.dy,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _candidateLabel(final int index) => switch (index) {
    0 => 'Selected',
    1 => 'Parent',
    2 => 'Child',
    _ => 'Alt ${index + 1}',
  };
}

class _BubbleDragHandle extends StatelessWidget {
  const _BubbleDragHandle({required this.alignment, required this.onPanUpdate});

  final Alignment alignment;
  final ValueChanged<DragUpdateDetails> onPanUpdate;

  @override
  Widget build(final BuildContext context) => Semantics(
    identifier: 'live_edit_bubble_drag_handle',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      child: SizedBox(
        height: 12,
        child: Align(
          alignment: alignment,
          child: Container(
            width: 28,
            height: 3,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF94A3B8),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    ),
  );
}

class _BubbleResizeHandle extends StatelessWidget {
  const _BubbleResizeHandle({required this.onPanUpdate});

  final ValueChanged<DragUpdateDetails> onPanUpdate;

  @override
  Widget build(final BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onPanUpdate: onPanUpdate,
    child: Padding(
      padding: const EdgeInsets.only(top: 6, left: 6),
      child: Icon(Icons.open_in_full, size: 14, color: const Color(0xFF64748B)),
    ),
  );
}

class _PanelDragHandle extends StatelessWidget {
  const _PanelDragHandle({required this.onPanUpdate});

  final ValueChanged<DragUpdateDetails> onPanUpdate;

  @override
  Widget build(final BuildContext context) => Semantics(
    identifier: 'live_edit_panel_drag_handle',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      child: const SizedBox(
        height: 18,
        child: Center(child: _HandleBar(width: 34)),
      ),
    ),
  );
}

class _PanelResizeHandle extends StatelessWidget {
  const _PanelResizeHandle({required this.onPanUpdate});

  final ValueChanged<DragUpdateDetails> onPanUpdate;

  @override
  Widget build(final BuildContext context) => Semantics(
    identifier: 'live_edit_panel_resize_handle',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      child: Padding(
        padding: const EdgeInsets.only(top: 6, left: 6),
        child: Icon(
          Icons.open_in_full,
          size: 14,
          color: const Color(0xFF64748B),
        ),
      ),
    ),
  );
}

class _HandleBar extends StatelessWidget {
  const _HandleBar({required this.width});

  final double width;

  @override
  Widget build(final BuildContext context) => Container(
    width: width,
    height: 3,
    decoration: BoxDecoration(
      color: const Color(0xFF94A3B8),
      borderRadius: BorderRadius.circular(999),
    ),
  );
}

class _SelectionBubbleBody extends StatelessWidget {
  const _SelectionBubbleBody({required this.orchestrator});

  final LiveEditOrchestrator orchestrator;

  @override
  Widget build(final BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            orchestrator.stagedDraftSummary ??
                'Describe the change in plain English. Use the inspector on the right for detailed properties.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
          ),
        ),
        const SizedBox(height: 12),
        _BubbleComposerSection(orchestrator: orchestrator),
        const SizedBox(height: 12),
        _ApplyActions(
          orchestrator: orchestrator,
          compact: true,
          semanticsPrefix: 'live_edit_bubble',
        ),
      ],
    ),
  );
}

class _WaitingBubbleBody extends StatelessWidget {
  const _WaitingBubbleBody({required this.orchestrator});

  final LiveEditOrchestrator orchestrator;

  @override
  Widget build(final BuildContext context) {
    final status = orchestrator.bubbleStatusForActiveSelection;
    final color = _bubbleStatusColor(status);
    final plan = orchestrator.pendingExecutionPlan;
    final property = orchestrator.activeProperty;
    final failure = status == LiveEditBubbleStatus.failed;
    return ListView(
      shrinkWrap: true,
      children: <Widget>[
        Container(
          key: ValueKey<String>('waiting_${status.name}'),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                failure
                    ? (orchestrator.lastError ?? 'Agent request failed.')
                    : orchestrator.currentActivity?.summary ??
                          '${orchestrator.currentBackendLabel} is working on ${property?.label ?? 'this change'}.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              _AgentActivityPanel(orchestrator: orchestrator),
              const SizedBox(height: 8),
              Text(
                orchestrator.currentActivity?.summary ??
                    plan?.summary ??
                    orchestrator.activeDraftChanges
                        .map(
                          (final draft) =>
                              '${draft.propertyId}=${draft.targetValue}',
                        )
                        .join(' • '),
                style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _BubbleComposerSection(orchestrator: orchestrator),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: orchestrator.expandPanel,
                child: const Text('Inspector'),
              ),
            ),
            if (failure) ...<Widget>[
              const SizedBox(width: 6),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: orchestrator.retryApply,
                  child: const Text('Retry'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _AppliedBubbleBody extends StatelessWidget {
  const _AppliedBubbleBody({required this.orchestrator});

  final LiveEditOrchestrator orchestrator;

  @override
  Widget build(final BuildContext context) => ListView(
    shrinkWrap: true,
    children: <Widget>[
      Container(
        key: const ValueKey<String>('applied_bubble'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Text(
          '${orchestrator.currentActivity?.summary ?? 'Applied live-edit changes.'} ${orchestrator.pendingExecutionPlan?.affectedFiles.join(', ') ?? 'Source updated.'}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF166534),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(height: 10),
      _BubbleComposerSection(orchestrator: orchestrator),
      const SizedBox(height: 10),
      _ApplyActions(
        orchestrator: orchestrator,
        compact: true,
        semanticsPrefix: 'live_edit_bubble',
      ),
    ],
  );
}

class _AiBubbleBody extends StatelessWidget {
  const _AiBubbleBody({required this.orchestrator});

  final LiveEditOrchestrator orchestrator;

  @override
  Widget build(final BuildContext context) => ListView(
    shrinkWrap: true,
    children: <Widget>[
      _AgentActivityPanel(orchestrator: orchestrator),
      const SizedBox(height: 8),
      if (_hasText(orchestrator.stagedRequestSummary) &&
          !orchestrator.needsApproval &&
          orchestrator.applyPhase != LiveEditApplyPhase.success) ...<Widget>[
        _PendingRequestCard(summary: orchestrator.stagedRequestSummary!),
        const SizedBox(height: 10),
      ],
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
      _BubbleComposerSection(orchestrator: orchestrator, autofocus: true),
      const SizedBox(height: 10),
      _ApplyActions(
        orchestrator: orchestrator,
        compact: true,
        semanticsPrefix: 'live_edit_bubble',
      ),
    ],
  );
}

class _BubbleComposerSection extends StatelessWidget {
  const _BubbleComposerSection({
    required this.orchestrator,
    this.autofocus = false,
  });

  final LiveEditOrchestrator orchestrator;
  final bool autofocus;

  @override
  Widget build(final BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      _BackendSwitcher(orchestrator: orchestrator, bubble: true),
      const SizedBox(height: 6),
      _AiComposer(orchestrator: orchestrator, autofocus: autofocus),
      if (_hasText(orchestrator.stagedRequestSummary)) ...<Widget>[
        const SizedBox(height: 8),
        _PendingRequestCard(summary: orchestrator.stagedRequestSummary!),
      ],
    ],
  );
}

class _PendingRequestCard extends StatelessWidget {
  const _PendingRequestCard({required this.summary});

  final String summary;

  @override
  Widget build(final BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBEB),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFFDE68A)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          'Pending request',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF92400E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          summary,
          style: const TextStyle(fontSize: 11, color: Color(0xFF78350F)),
        ),
      ],
    ),
  );
}

class _SelectedPromptCard extends StatelessWidget {
  const _SelectedPromptCard({required this.promptText});

  final String? promptText;

  @override
  Widget build(final BuildContext context) {
    final hasPrompt = _hasText(promptText);
    return Semantics(
      identifier: 'live_edit_selected_prompt',
      child: ExpansionTile(
        key: const PageStorageKey<String>('live_edit_selected_prompt_tile'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text(
          'Agent request',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          hasPrompt
              ? 'Exact request sent to the agent for this bubble.'
              : 'No agent request sent for this bubble yet.',
          style: const TextStyle(fontSize: 10),
        ),
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SelectionArea(
              child: Text(
                hasPrompt
                    ? promptText!.trim()
                    : 'No agent request sent for this bubble yet.',
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineBubble extends StatelessWidget {
  const _TimelineBubble({required this.entry, this.debug = false});

  final LiveEditTimelineEntry entry;
  final bool debug;

  @override
  Widget build(final BuildContext context) {
    final isAssistant = entry.role == 'assistant' || entry.role == 'debug';
    return Align(
      alignment: isAssistant ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: entry.role == 'debug'
              ? const Color(0xFF111827)
              : isAssistant
              ? const Color(0xFFE2E8F0)
              : const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              entry.message,
              style: TextStyle(
                fontSize: 12,
                color: entry.role == 'debug' ? Colors.white : null,
              ),
            ),
            if (debug || entry.role == 'debug') ...<Widget>[
              const SizedBox(height: 4),
              Text(
                entry.timestamp.toLocal().toIso8601String(),
                style: TextStyle(
                  fontSize: 10,
                  color: entry.role == 'debug'
                      ? Colors.white70
                      : const Color(0xFF64748B),
                ),
              ),
            ],
            if (entry.details.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              for (final detail in entry.details.take(4))
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 11,
                    color: entry.role == 'debug'
                        ? Colors.white70
                        : const Color(0xFF475569),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolDomainSwitch extends StatelessWidget {
  const _ToolDomainSwitch({required this.orchestrator});

  final LiveEditOrchestrator orchestrator;

  @override
  Widget build(final BuildContext context) {
    final toolScene = orchestrator.editingToolScene;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        ChoiceChip(
          label: const Text('Edit App', style: TextStyle(fontSize: 11)),
          selected: !toolScene,
          onSelected: (final selected) {
            if (selected) {
              orchestrator.setTargetDomain(LiveEditTargetDomain.appScene);
            }
          },
        ),
        ChoiceChip(
          label: const Text('Edit Tools', style: TextStyle(fontSize: 11)),
          selected: toolScene,
          onSelected: (final selected) {
            if (selected) {
              orchestrator.setTargetDomain(LiveEditTargetDomain.toolScene);
            }
          },
        ),
      ],
    );
  }
}

class _BackendSwitcher extends StatelessWidget {
  const _BackendSwitcher({
    required this.orchestrator,
    this.rail = false,
    this.bubble = false,
  });

  final LiveEditOrchestrator orchestrator;
  final bool rail;
  final bool bubble;

  @override
  Widget build(final BuildContext context) {
    final surfaceTheme = LiveEditOverlayThemeModel.instance.styleFor(
      kLiveEditBackendSwitcherSurfaceId,
    );
    final backends = orchestrator.availableBackends;
    if (backends.length < 2) {
      return const SizedBox.shrink();
    }
    final selected = orchestrator.currentBackendId;
    if (rail) {
      return PopupMenuButton<String>(
        tooltip: 'Select backend',
        onSelected: orchestrator.setBackend,
        itemBuilder: (final context) => backends
            .map(
              (final backend) => PopupMenuItem<String>(
                value: backend.id,
                enabled: backend.available,
                child: Text(
                  backend.available
                      ? backend.label
                      : '${backend.label} offline',
                  style: TextStyle(
                    fontSize: 11,
                    color: backend.available
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF94A3B8),
                    fontWeight: backend.id == selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            )
            .toList(growable: false),
        child: Semantics(
          identifier: 'live_edit_backend_switcher_rail',
          button: true,
          child: Container(
            width: 40,
            padding: surfaceTheme.padding,
            decoration: BoxDecoration(
              color: surfaceTheme.backgroundColor,
              borderRadius: BorderRadius.circular(surfaceTheme.cornerRadius),
              border: Border.all(color: surfaceTheme.borderColor),
            ),
            child: Column(
              children: <Widget>[
                const Icon(Icons.sync_alt, size: 14),
                const SizedBox(height: 4),
                Text(
                  orchestrator.currentBackendLabel
                      .substring(0, 1)
                      .toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (bubble) {
      return Semantics(
        identifier: 'live_edit_bubble_backend_switcher',
        child: Row(
          children: <Widget>[
            for (var index = 0; index < backends.length; index += 1)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == backends.length - 1 ? 0 : 6,
                  ),
                  child: ChoiceChip(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      backends[index].label,
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: backends[index].id == selected,
                    onSelected: backends[index].available
                        ? (final value) {
                            if (value) {
                              orchestrator.setBackend(backends[index].id);
                            }
                          }
                        : null,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return Semantics(
      identifier: 'live_edit_backend_switcher',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Backend',
            style: TextStyle(
              color: rail ? Colors.white70 : const Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final backend in backends)
                ChoiceChip(
                  label: Text(
                    backend.available
                        ? backend.label
                        : '${backend.label} offline',
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: backend.id == selected,
                  onSelected: backend.available
                      ? (final value) {
                          if (value) {
                            orchestrator.setBackend(backend.id);
                          }
                        }
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InferenceConfigEditor extends StatelessWidget {
  const _InferenceConfigEditor({required this.orchestrator});

  final LiveEditOrchestrator orchestrator;

  @override
  Widget build(final BuildContext context) {
    final backend = orchestrator.currentBackend;
    if (backend == null) {
      return const Text(
        'No backend selected.',
        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
      );
    }
    final model = orchestrator.currentModel ?? '';
    final reasoning = orchestrator.currentReasoningEffort;
    final freeform = orchestrator.currentBackendUsesFreeformModel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Backend: ${backend.label}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        if (freeform)
          Semantics(
            identifier: 'live_edit_model_input',
            child: TextFormField(
              key: ValueKey<String>('model-${backend.id}'),
              initialValue: model,
              decoration: const InputDecoration(
                labelText: 'Model',
                hintText: 'auto',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 12),
              onChanged: (final value) {
                orchestrator.setInferenceConfig(model: value);
              },
            ),
          )
        else
          Semantics(
            identifier: 'live_edit_model_dropdown',
            child: DropdownButtonFormField<String>(
              value: model.isEmpty ? null : model,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Model',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: orchestrator.currentSupportedModels
                  .map(
                    (final option) => DropdownMenuItem<String>(
                      value: option.id,
                      child: Text(
                        option.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (final value) {
                orchestrator.setInferenceConfig(
                  model: value,
                  reasoningEffort: reasoning,
                );
              },
            ),
          ),
        if (!freeform) ...<Widget>[
          const SizedBox(height: 8),
          Semantics(
            identifier: 'live_edit_reasoning_dropdown',
            child: DropdownButtonFormField<String>(
              value: reasoning,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Reasoning',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: orchestrator.currentSupportedReasoningEfforts
                  .map(
                    (final effort) => DropdownMenuItem<String>(
                      value: effort,
                      child: Text(effort, style: const TextStyle(fontSize: 12)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (final value) {
                orchestrator.setInferenceConfig(
                  model: model,
                  reasoningEffort: value,
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _AgentActivityPanel extends StatelessWidget {
  const _AgentActivityPanel({required this.orchestrator, this.dense = false});

  final LiveEditOrchestrator orchestrator;
  final bool dense;

  @override
  Widget build(final BuildContext context) {
    final latest = orchestrator.currentActivity;
    if (latest == null) {
      return Container(
        padding: EdgeInsets.all(dense ? 8 : 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Text(
          'No activity yet.',
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      );
    }
    final details = latest.details.take(dense ? 2 : 4).toList(growable: false);
    return Container(
      padding: EdgeInsets.all(dense ? 8 : 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  latest.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
              Text(
                _activityElapsedLabel(latest),
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            latest.summary,
            style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
          ),
          if (orchestrator.lastError case final error?) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              error,
              style: const TextStyle(fontSize: 10, color: Color(0xFF991B1B)),
              maxLines: dense ? 2 : 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (orchestrator.debugModeEnabled || details.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            if (orchestrator.debugModeEnabled)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text(
                  'Technical details',
                  style: TextStyle(fontSize: 10, color: Color(0xFF334155)),
                ),
                children: <Widget>[
                  if (details.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          'No technical details yet.',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  for (final detail in details)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          detail,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                ],
              )
            else if (details.isNotEmpty)
              Text(
                details.first,
                style: const TextStyle(fontSize: 10, color: Color(0xFF334155)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ],
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
            enableInteractiveSelection: true,
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(
              hintText:
                  'Talk to ${widget.orchestrator.currentBackendLabel} about this selected element',
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
    final rowTheme = LiveEditOverlayThemeModel.instance.styleFor(
      kLiveEditPropertyEditorRowSurfaceId,
    );
    final isActive = orchestrator.activePropertyId == property.id;
    final disabled = !property.editable;
    final effectiveValue = orchestrator.effectiveValueForProperty(property);

    final cardChild = Ink(
      padding: rowTheme.padding,
      decoration: BoxDecoration(
        color: isActive ? rowTheme.backgroundColor : Colors.white,
        borderRadius: BorderRadius.circular(rowTheme.cornerRadius),
        border: Border.all(
          color: isActive ? const Color(0xFF0EA5E9) : rowTheme.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: surface == LiveEditEditSurface.panel ? 78 : 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      property.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _propertySubtitle(property, effectiveValue),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF475569),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: rowTheme.gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: <Widget>[
                        _PropertyBadge(
                          label: _previewLabel(property),
                          textColor: _previewColor(property),
                          backgroundColor: _previewColor(
                            property,
                          ).withOpacity(0.12),
                          captureSurfaceKey: isActive,
                        ),
                        _PropertyBadge(
                          label: _persistLabel(property, orchestrator),
                          textColor: property.requiresAgentForPersistence
                              ? const Color(0xFF7C2D12)
                              : const Color(0xFF1D4ED8),
                          backgroundColor: property.requiresAgentForPersistence
                              ? const Color(0xFFFFEDD5)
                              : const Color(0xFFDBEAFE),
                        ),
                        if (orchestrator.hasDraftForProperty(property))
                          _PropertyBadge(
                            label: orchestrator.isPropertyWaiting(property)
                                ? 'Waiting'
                                : 'Dirty',
                            textColor: orchestrator.isPropertyWaiting(property)
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFF0F766E),
                            backgroundColor:
                                orchestrator.isPropertyWaiting(property)
                                ? const Color(0xFFDBEAFE)
                                : const Color(0xFFCCFBF1),
                          ),
                      ],
                    ),
                    SizedBox(height: rowTheme.gap),
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
              ),
              SizedBox(width: rowTheme.gap),
              _PropertyActionColumn(
                orchestrator: orchestrator,
                property: property,
                surface: surface,
              ),
            ],
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

  String _propertySubtitle(
    final LiveEditPropertyDescriptor property,
    final Object? value,
  ) {
    final resolved = '$value'.isEmpty ? 'unset' : '$value';
    final editor = property.preferredEditor.isEmpty
        ? property.kind.wireName
        : property.preferredEditor;
    return '$resolved • $editor';
  }
}

class _PropertyBadge extends StatelessWidget {
  const _PropertyBadge({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    this.captureSurfaceKey = false,
  });

  final String label;
  final Color textColor;
  final Color backgroundColor;
  final bool captureSurfaceKey;

  @override
  Widget build(final BuildContext context) {
    final theme = LiveEditOverlayThemeModel.instance.styleFor(
      kLiveEditStatusBadgeSurfaceId,
    );
    return Container(
      padding: theme.padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(theme.cornerRadius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _PropertyActionColumn extends StatelessWidget {
  const _PropertyActionColumn({
    required this.orchestrator,
    required this.property,
    required this.surface,
  });

  final LiveEditOrchestrator orchestrator;
  final LiveEditPropertyDescriptor property;
  final LiveEditEditSurface surface;

  @override
  Widget build(final BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (surface == LiveEditEditSurface.panel) ...<Widget>[
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            onPressed: () {
              if (property.requiresAgentForPersistence) {
                orchestrator.openAiBubble(property: property);
              } else {
                orchestrator.focusProperty(property);
              }
            },
            icon: Icon(
              property.requiresAgentForPersistence
                  ? Icons.smart_toy_outlined
                  : Icons.ads_click_outlined,
            ),
          ),
        ],
      ],
    );
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
    final waiting = orchestrator.isPropertyWaiting(property);
    if (!property.editable) {
      return Text(
        '${property.value ?? 'Not editable'}',
        style: const TextStyle(fontSize: 11),
      );
    }
    if (property.requiresAgentForPersistence &&
        surface == LiveEditEditSurface.inline) {
      return Row(
        children: <Widget>[
          const Expanded(
            child: Text('Use Apply', style: TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 4),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            onPressed: () => orchestrator.openAiBubble(property: property),
            child: const Text('AI', style: TextStyle(fontSize: 11)),
          ),
        ],
      );
    }

    if (property.kind == LiveEditPropertyKind.boolean) {
      final current = orchestrator.effectiveValueForProperty(property) == true;
      return Align(
        alignment: Alignment.centerLeft,
        child: Switch(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          value: current,
          onChanged: waiting
              ? null
              : (final value) => orchestrator.updateDraft(
                  property: property,
                  targetValue: value,
                  surface: surface,
                ),
        ),
      );
    }

    if (property.options.isNotEmpty ||
        property.kind == LiveEditPropertyKind.enumValue) {
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        children: <Widget>[
          for (final option in property.options)
            ChoiceChip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelStyle: const TextStyle(fontSize: 11),
              label: Text(option),
              selected:
                  '$option' ==
                  '${orchestrator.effectiveValueForProperty(property)}',
              onSelected: waiting
                  ? null
                  : (_) => orchestrator.updateDraft(
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
    final text =
        '${widget.orchestrator.effectiveValueForProperty(widget.property) ?? ''}';
    final waiting = widget.orchestrator.isPropertyWaiting(widget.property);
    if (_controller.text != text) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    return Row(
      children: <Widget>[
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 14,
          onPressed: waiting
              ? null
              : () => _applyDelta(-widget.property.numericStep),
          icon: const Icon(Icons.remove),
        ),
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: widget.surface == LiveEditEditSurface.inline,
            enableInteractiveSelection: true,
            enabled: !waiting,
            style: const TextStyle(fontSize: 11),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            onSubmitted: (final value) => _submit(value),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 14,
          onPressed: waiting
              ? null
              : () => _applyDelta(widget.property.numericStep),
          icon: const Icon(Icons.add),
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
    final base = _asDouble(
      widget.orchestrator.effectiveValueForProperty(widget.property),
    );
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
    final text =
        '${widget.orchestrator.effectiveValueForProperty(widget.property) ?? ''}';
    final waiting = widget.orchestrator.isPropertyWaiting(widget.property);
    if (_controller.text != text) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    return TextField(
      controller: _controller,
      autofocus: widget.surface == LiveEditEditSurface.inline,
      enableInteractiveSelection: true,
      enabled: !waiting,
      maxLines: widget.multiline ? 4 : 1,
      minLines: widget.multiline ? 3 : 1,
      style: const TextStyle(fontSize: 11),
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
