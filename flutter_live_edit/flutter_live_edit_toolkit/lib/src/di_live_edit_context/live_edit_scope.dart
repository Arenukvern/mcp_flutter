import 'package:flutter/material.dart';

import '../ai/backend/live_edit_backend_utils.dart';
import '../live_edit_runtime.dart';
import '../models/models.dart';
import '../resources/live_edit_backend_config.src.data.dart';
import '../resources/resources.dart';
import '../services/services.dart';
import '../types/live_edit_types.dart';
import 'live_edit_context.dart';
import 'tools/live_edit_controller_adapter.dart';

/// Provides [LiveEditContext] and [LiveEditController] to descendants via [LiveEditScope.of].
/// Create once at the root of the live-edit subtree; children use [LiveEditScope.of](context).
final class LiveEditScope extends StatefulWidget {
  const LiveEditScope({
    required this.child,
    super.key,
    this.applyDraftDelegate,
    this.backendId,
    this.availableBackends = const <LiveEditAgentBackend>[],
    this.workingDirectory,
    this.intentText,
  });

  final Widget child;
  final LiveEditApplyDraftDelegate? applyDraftDelegate;
  final String? backendId;
  final List<LiveEditAgentBackend> availableBackends;
  final String? workingDirectory;
  final String? intentText;

  static LiveEditScopeData of(final BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_InheritedLiveEditScope>();
    assert(scope != null, 'No LiveEditScope found in context');
    return scope!.data;
  }

  /// Returns scope data if a [LiveEditScope] is in the widget tree, else null.
  static LiveEditScopeData? maybeOf(final BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_InheritedLiveEditScope>()
      ?.data;

  @override
  State<LiveEditScope> createState() => _LiveEditScopeState();
}

final class LiveEditScopeData {
  LiveEditScopeData({
    required this.context,
    required this.controller,
    required this.sessionResource,
    required this.selectionResource,
    required this.draftResource,
    required this.bubbleResource,
    required this.panelViewResource,
    required this.backendConfigResource,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final LiveEditSessionResource sessionResource;
  final LiveEditSelectionResource selectionResource;
  final LiveEditDraftResource draftResource;
  final LiveEditBubbleResource bubbleResource;
  final LiveEditPanelViewResource panelViewResource;
  final LiveEditBackendConfigResource backendConfigResource;
}

class _LiveEditScopeState extends State<LiveEditScope> {
  late final LiveEditSessionResource _sessionResource;
  late final LiveEditSelectionResource _selectionResource;
  late final LiveEditDraftResource _draftResource;
  late final LiveEditBubbleResource _bubbleResource;
  late final LiveEditPanelViewResource _panelViewResource;
  late final LiveEditBackendConfigResource _backendConfigResource;
  late final LiveEditSessionService _sessionService;
  late final LiveEditApplyService _applyService;
  late final LiveEditBubbleStateService _bubbleStateService;
  late final LiveEditContext _context;
  late final LiveEditController _controller;
  late final LiveEditScopeData _data;

  @override
  void initState() {
    super.initState();
    _sessionResource = LiveEditSessionResource();
    _selectionResource = LiveEditSelectionResource();
    _draftResource = LiveEditDraftResource();
    _bubbleResource = LiveEditBubbleResource();
    _panelViewResource = LiveEditPanelViewResource();
    final backends = List<LiveEditAgentBackend>.unmodifiable(
      widget.availableBackends,
    );
    final configByBackend = <String, LiveEditInferenceConfig>{};
    for (final backend in backends) {
      final config = backendEffectiveConfig(backend);
      if (config != null) configByBackend[backend.id] = config;
    }
    _backendConfigResource = LiveEditBackendConfigResource(
      LiveEditBackendConfigResourceData(
        globalBackendId: resolveInitialBackendId(
          availableBackends: backends,
          backendId: widget.backendId,
        ),
        availableBackends: backends,
        inferenceConfigByBackendId: configByBackend,
      ),
    );
    _sessionService = LiveEditSessionService();
    LiveEditRuntime.onSessionServiceCreated?.call(_sessionService);
    _applyService = LiveEditApplyService(
      applyDraftDelegate: widget.applyDraftDelegate,
    );
    _bubbleStateService = LiveEditBubbleStateService();
    void onBubbleEvent(final String? bubbleId, final LiveEditRuntimeEvent ev) {
      _bubbleStateService.emitEventForBubble(
        _context,
        bubbleId,
        ev,
        getBackendLabel: (final id) => backendLabelFromContext(_context, id),
      );
    }

    _context = LiveEditContext(
      sessionResource: _sessionResource,
      selectionResource: _selectionResource,
      draftResource: _draftResource,
      bubbleResource: _bubbleResource,
      panelViewResource: _panelViewResource,
      backendConfigResource: _backendConfigResource,
      sessionService: _sessionService,
      applyService: _applyService,
      bubbleStateService: _bubbleStateService,
      applyEventSink: onBubbleEvent,
    );
    _controller = LiveEditController(_context);
    LiveEditRuntime.contextAccessor = () => _context;
    _data = LiveEditScopeData(
      context: _context,
      controller: _controller,
      sessionResource: _sessionResource,
      selectionResource: _selectionResource,
      draftResource: _draftResource,
      bubbleResource: _bubbleResource,
      panelViewResource: _panelViewResource,
      backendConfigResource: _backendConfigResource,
    );
  }

  @override
  void dispose() {
    LiveEditRuntime.contextAccessor = null;
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) =>
      _InheritedLiveEditScope(data: _data, child: widget.child);
}

class _InheritedLiveEditScope extends InheritedWidget {
  const _InheritedLiveEditScope({required this.data, required super.child});

  final LiveEditScopeData data;

  @override
  bool updateShouldNotify(final _InheritedLiveEditScope oldWidget) =>
      data != oldWidget.data;
}
