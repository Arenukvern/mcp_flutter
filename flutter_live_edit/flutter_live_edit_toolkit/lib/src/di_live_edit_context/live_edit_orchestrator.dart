import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ai/backend/live_edit_backend_utils.dart';
import '../live_edit_runtime.dart';
import '../models/models.dart';
import '../resources/live_edit_backend_config.src.data.dart';
import '../resources/resources.dart';
import '../services/services.dart';
import '../types/live_edit_types.dart';
import 'live_edit_context.dart';
import 'live_edit_batch_notifier.dart';
import 'tools/live_edit_controller_adapter.dart';

final class LiveEditOrchestrator {
  LiveEditOrchestrator({
    this.applyDraftDelegate,
    final String? backendId,
    final List<LiveEditAgentBackend> availableBackends =
        const <LiveEditAgentBackend>[],
    this.workingDirectory,
    this.intentText,
  }) {
    _sessionResource = LiveEditSessionResource();
    _selectionResource = LiveEditSelectionResource();
    _draftResource = LiveEditDraftResource();
    _flowGraphResource = LiveEditFlowGraphResource();
    _bubbleResource = LiveEditBubbleResource();
    _panelViewResource = LiveEditPanelViewResource();
    _inFlightResource = LiveEditInFlightResource();
    final backends = List<LiveEditAgentBackend>.unmodifiable(availableBackends);
    final configByBackend = <String, LiveEditInferenceConfig>{};
    for (final backend in backends) {
      final config = backendEffectiveConfig(backend);
      if (config != null) {
        configByBackend[backend.id] = config;
      }
    }
    _backendConfigResource = LiveEditBackendConfigResource(
      LiveEditBackendConfigResourceData(
        globalBackendId: resolveInitialBackendId(
          availableBackends: backends,
          backendId: backendId,
        ),
        availableBackends: backends,
        inferenceConfigByBackendId: configByBackend,
      ),
    );
    _sessionService = LiveEditSessionService();
    LiveEditRuntime.onSessionServiceCreated?.call(_sessionService);
    _applyService = LiveEditApplyService(
      applyDraftDelegate: applyDraftDelegate,
    );
    _worktreeService = LiveEditWorktreeService();
    _bubbleStateService = LiveEditBubbleStateService();
    _context = LiveEditContext(
      sessionResource: _sessionResource,
      selectionResource: _selectionResource,
      draftResource: _draftResource,
      flowGraphResource: _flowGraphResource,
      bubbleResource: _bubbleResource,
      panelViewResource: _panelViewResource,
      backendConfigResource: _backendConfigResource,
      inFlightResource: _inFlightResource,
      sessionService: _sessionService,
      applyService: _applyService,
      bubbleStateService: _bubbleStateService,
      applyEventSink: _emitEventForBubble,
      worktreeService: _worktreeService,
      mainWorkingDirectory: workingDirectory,
    );
    _controller = LiveEditController(_context);
    LiveEditRuntime.contextAccessor = () => _context;
    _batchNotifier = LiveEditBatchNotifier(<Listenable>[
      _sessionResource,
      _selectionResource,
      _draftResource,
      _flowGraphResource,
      _bubbleResource,
      _panelViewResource,
      _backendConfigResource,
      _inFlightResource,
    ]);
  }

  late final LiveEditSessionResource _sessionResource;
  late final LiveEditSelectionResource _selectionResource;
  late final LiveEditDraftResource _draftResource;
  late final LiveEditFlowGraphResource _flowGraphResource;
  late final LiveEditBubbleResource _bubbleResource;
  late final LiveEditPanelViewResource _panelViewResource;
  late final LiveEditBackendConfigResource _backendConfigResource;
  late final LiveEditInFlightResource _inFlightResource;
  late final LiveEditBubbleStateService _bubbleStateService;
  late final LiveEditSessionService _sessionService;
  late final LiveEditApplyService _applyService;
  late final LiveEditWorktreeService _worktreeService;
  late final LiveEditContext _context;
  late final LiveEditController _controller;
  late final LiveEditBatchNotifier _batchNotifier;

  LiveEditController get controller => _controller;

  /// Exposes context for running Commands (e.g. from UI or MCP).
  LiveEditContext get context => _context;

  /// Aggregated notifier for widgets that need to rebuild on any resource change.
  LiveEditBatchNotifier get batchNotifier => _batchNotifier;

  final LiveEditApplyDraftDelegate? applyDraftDelegate;
  final String? workingDirectory;
  final String? intentText;

  static const Duration _eventThrottle = Duration(milliseconds: 80);
  final List<(String?, LiveEditRuntimeEvent)> _eventBuffer = [];
  DateTime? _lastEventFlush;
  Timer? _eventFlushTimer;

  void dispose() {
    _eventFlushTimer?.cancel();
    _eventFlushTimer = null;
    _batchNotifier.dispose();
    LiveEditRuntime.contextAccessor = null;
  }

  void _emitEventForBubble(
    final String? bubbleId,
    final LiveEditRuntimeEvent event,
  ) {
    _eventBuffer.add((bubbleId, event));
    final now = DateTime.now();
    if (_lastEventFlush == null ||
        now.difference(_lastEventFlush!) >= _eventThrottle) {
      _flushEventBuffer();
    } else if (_eventFlushTimer == null || !_eventFlushTimer!.isActive) {
      final remaining =
          _eventThrottle.inMilliseconds -
          now.difference(_lastEventFlush!).inMilliseconds;
      _eventFlushTimer = Timer(
        Duration(milliseconds: remaining > 0 ? remaining : 1),
        _flushEventBuffer,
      );
    }
  }

  void _flushEventBuffer() {
    _eventFlushTimer?.cancel();
    _eventFlushTimer = null;
    if (_eventBuffer.isEmpty) return;
    final toProcess = List<(String?, LiveEditRuntimeEvent)>.from(_eventBuffer);
    _eventBuffer.clear();
    _lastEventFlush = DateTime.now();
    String backendLabel(final String? id) =>
        backendLabelFromContext(_context, id);
    for (final (bid, evt) in toProcess) {
      _bubbleStateService.emitEventForBubble(
        _context,
        bid,
        evt,
        getBackendLabel: backendLabel,
      );
    }
  }
}
