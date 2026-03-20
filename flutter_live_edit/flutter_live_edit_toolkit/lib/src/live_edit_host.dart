import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';
import 'package:live_edit_tooling_ui_kit/live_edit_tooling_ui_kit.dart';

import 'commands/commands.dart';
import 'live_edit_backend_utils.dart';
import 'live_edit_context.dart';
import 'live_edit_controller_adapter.dart';
import 'live_edit_host_overlay.dart';
import 'live_edit_orchestrator.dart';
import 'live_edit_overlay_theme.dart';
import 'live_edit_scope.dart';
import 'live_edit_tool_layer_glue.dart';
import 'live_edit_types.dart';
import 'selectors/live_edit_selectors.dart';
import 'widgets/backend_switcher.dart';

part 'widgets/live_edit_host_bubbles.dart';
part 'widgets/live_edit_host_bubbles_waiting.dart';
part 'widgets/live_edit_host_overlay.dart';
part 'widgets/live_edit_host_panel.dart';
part 'widgets/live_edit_host_panel_body.dart';

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

Color _bubbleStatusColor(final LiveEditBubbleStatus status) => switch (status) {
  LiveEditBubbleStatus.editing => const Color(0xFF0F766E),
  LiveEditBubbleStatus.waiting => const Color(0xFF1D4ED8),
  LiveEditBubbleStatus.needsApproval => const Color(0xFF92400E),
  LiveEditBubbleStatus.applied => const Color(0xFF166534),
  LiveEditBubbleStatus.failed => const Color(0xFFB91C1C),
};

String _bubbleStatusLabel(final LiveEditBubbleStatus status) =>
    switch (status) {
      LiveEditBubbleStatus.editing => 'Draft ready',
      LiveEditBubbleStatus.waiting => 'Applying',
      LiveEditBubbleStatus.needsApproval => 'Applying',
      LiveEditBubbleStatus.applied => 'Applied',
      LiveEditBubbleStatus.failed => 'Failed',
    };

String _domainLabel(final LiveEditTargetDomain domain) => switch (domain) {
  LiveEditTargetDomain.appScene => 'App',
  LiveEditTargetDomain.toolScene => 'Tool',
};

bool _hasText(final String? value) => value != null && value.trim().isNotEmpty;

Rect _panelRectForViewport({
  required final LiveEditContext ctx,
  required final LiveEditOverlayThemeModel overlayTheme,
  required final Size viewport,
}) {
  final panelExpanded = selectPanelExpanded(ctx);
  final panelSurfaceId = panelExpanded
      ? kLiveEditPanelExpandedSurfaceId
      : kLiveEditPanelRailSurfaceId;
  final panelSurfaceTheme = overlayTheme.styleFor(panelSurfaceId);
  final panelWidth = math.max(
    selectPanelWidth(ctx),
    overlayTheme.panelWidth(expanded: panelExpanded),
  );
  final panelHeight = math.max(
    selectPanelHeight(ctx),
    panelSurfaceTheme.height ?? selectPanelHeight(ctx),
  );
  final panelOffset = selectPanelPlacement(ctx, viewport);
  return Rect.fromLTWH(panelOffset.dx, panelOffset.dy, panelWidth, panelHeight);
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
    this.childIsToolLayer = false,
  });

  final Widget child;
  final LiveEditController? controller;
  final LiveEditOrchestrator? orchestrator;
  final LiveEditApplyDraftDelegate? applyDraftDelegate;
  final String? backendId;
  final List<LiveEditAgentBackend> availableBackends;
  final String? workingDirectory;
  final String? intentText;
  final bool childIsToolLayer;

  @override
  State<FlutterLiveEditHost> createState() => _FlutterLiveEditHostState();
}

/// Reusable tool layer (pinned pills, expanded bubbles, panel) for the live-edit
/// overlay. Used by [FlutterLiveEditHost] and by [live_edit_tooling_ui_kit].
class LiveEditToolLayer extends StatelessWidget {
  const LiveEditToolLayer({
    required this.context,
    required this.controller,
    required this.viewportSize,
    super.key,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final Size viewportSize;

  @override
  Widget build(final BuildContext buildContext) {
    final overlayTheme = LiveEditOverlayThemeModel.instance;
    final panelRect = _panelRectForViewport(
      ctx: context,
      overlayTheme: overlayTheme,
      viewport: viewportSize,
    );
    final theme = buildToolingThemeData();
    final bubbleViewModel = buildBubbleLayerViewModel(
      context,
      controller,
      viewportSize,
      theme,
    );
    final panelViewModel = buildPanelViewModel(
      context,
      controller,
      viewportSize,
      theme,
    );
    final bubbleCallbacks = ToolLayerBubbleCallbacks(
      context: context,
      controller: controller,
    );
    final panelCallbacks = ToolLayerPanelCallbacks(context: context);
    final expanded = selectExpandedBubbleSummaries(
      context,
      controller,
      presentationDomain: selectPresentedLayer(context),
      sessionId: context.sessionResource.value.activeSessionId,
    );
    // Only show the active bubble (first in list, sorted by active).
    final activeBubble = expanded.isEmpty ? null : expanded.first;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ...bubbleViewModel.pinnedSummaries.map(
          (final summary) => PinnedBubblePill(
            summary: summary,
            viewportSize: viewportSize,
            callbacks: bubbleCallbacks,
            theme: bubbleViewModel.theme,
          ),
        ),
        if (activeBubble != null)
          _SelectionBubble(
            context: context,
            controller: controller,
            viewportSize: viewportSize,
            bubbleSummary: activeBubble,
          ),
        Positioned(
          left: panelRect.left,
          top: panelRect.top,
          width: panelRect.width,
          height: panelRect.height,
          child: _EditorPanelSurface(
            context: context,
            controller: controller,
            railPanelViewModel: panelViewModel,
            panelCallbacks: panelCallbacks,
            bubbleCallbacks: bubbleCallbacks,
          ),
        ),
      ],
    );
  }
}

class _CycleCandidateIntent extends Intent {
  const _CycleCandidateIntent(this.delta);

  final int delta;
}

class _SelectChildIntent extends Intent {
  const _SelectChildIntent();
}

class _SelectParentIntent extends Intent {
  const _SelectParentIntent();
}

class _FlutterLiveEditHostState extends State<FlutterLiveEditHost> {
  LiveEditOrchestrator? _orchestrator;
  bool _ownsOrchestrator = false;
  final GlobalKey _contentKey = GlobalKey();
  final GlobalKey _toolOverlayKey = GlobalKey();
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
  Widget build(final BuildContext context) {
    if (_orchestrator != null) {
      return AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[
          _orchestrator!,
          _overlayTheme,
        ]),
        builder: (final _, final _) => _buildBody(
          context,
          _orchestrator!.context,
          _orchestrator!.controller,
        ),
      );
    }
    return Builder(
      builder: (final c) {
        final scope = LiveEditScope.maybeOf(c);
        assert(
          scope != null,
          'FlutterLiveEditHost requires LiveEditScope when orchestrator is null',
        );
        final data = scope!;
        return AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[
            data.sessionResource,
            data.selectionResource,
            data.draftResource,
            data.bubbleResource,
            data.panelViewResource,
            data.backendConfigResource,
            _overlayTheme,
          ]),
          builder: (final _, final _) =>
              _buildBody(c, data.context, data.controller),
        );
      },
    );
  }

  Widget _buildBody(
    final BuildContext context,
    final LiveEditContext ctx,
    final LiveEditController ctrl,
  ) => Shortcuts(
    shortcuts: const <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.arrowUp): _SelectParentIntent(),
      SingleActivator(LogicalKeyboardKey.arrowDown): _SelectChildIntent(),
      SingleActivator(LogicalKeyboardKey.arrowLeft): _CycleCandidateIntent(-1),
      SingleActivator(LogicalKeyboardKey.arrowRight): _CycleCandidateIntent(1),
    },
    child: Actions(
      actions: <Type, Action<Intent>>{
        _SelectParentIntent: CallbackAction<_SelectParentIntent>(
          onInvoke: (final _) {
            if (selectOverlayVisible(ctx) && !_editableTextHasPrimaryFocus) {
              SelectParentCandidateCommand(controller: ctrl).execute(ctx);
            }
            return null;
          },
        ),
        _SelectChildIntent: CallbackAction<_SelectChildIntent>(
          onInvoke: (final _) {
            if (selectOverlayVisible(ctx) && !_editableTextHasPrimaryFocus) {
              SelectChildCandidateCommand(controller: ctrl).execute(ctx);
            }
            return null;
          },
        ),
        _CycleCandidateIntent: CallbackAction<_CycleCandidateIntent>(
          onInvoke: (final intent) {
            if (selectOverlayVisible(ctx) && !_editableTextHasPrimaryFocus) {
              CycleSelectionCandidateCommand(
                controller: ctrl,
                delta: intent.delta,
              ).execute(ctx);
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
              builder: (final overlayContext) => LayoutBuilder(
                builder: (final _, final constraints) => Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    KeyedSubtree(key: _contentKey, child: widget.child),
                    if (selectOverlayVisible(ctx))
                      LiveEditOverlay(
                        context: ctx,
                        controller: ctrl,
                        contentKey: _contentKey,
                        targetDomain: LiveEditTargetDomain.appScene,
                        interactive: true,
                        openBubbleOnSelect: widget.childIsToolLayer,
                        orchestrator: _orchestrator,
                      ),
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: _LauncherChip(context: ctx, controller: ctrl),
                    ),
                    if (selectOverlayVisible(ctx) && !widget.childIsToolLayer)
                      Positioned.fill(
                        child: KeyedSubtree(
                          key: _toolOverlayKey,
                          child: LiveEditToolLayer(
                            context: ctx,
                            controller: ctrl,
                            viewportSize: constraints.biggest,
                          ),
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
  );

  @override
  void didUpdateWidget(covariant final FlutterLiveEditHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_orchestrator == null) return;
    if (widget.availableBackends != oldWidget.availableBackends) {
      SetAvailableBackendsCommand(
        availableBackends: widget.availableBackends,
        initialBackendId:
            _orchestrator!.context.backendConfigResource.value.globalBackendId,
      ).execute(_orchestrator!.context);
    }
    if (_ownsOrchestrator &&
        widget.backendId != oldWidget.backendId &&
        widget.backendId != null) {
      SetBackendCommand(
        backendId: widget.backendId!,
      ).execute(_orchestrator!.context);
    }
  }

  @override
  void dispose() {
    if (_ownsOrchestrator && _orchestrator != null) {
      _orchestrator!.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.orchestrator != null) {
      _orchestrator = widget.orchestrator;
      _ownsOrchestrator = false;
    }
    // When orchestrator is null, host must be under LiveEditScope (checked in build).
  }
}
