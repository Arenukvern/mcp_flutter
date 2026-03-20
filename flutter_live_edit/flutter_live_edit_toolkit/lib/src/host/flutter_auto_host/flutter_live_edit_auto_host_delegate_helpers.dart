part of 'flutter_live_edit_auto_host_delegate.dart';

String? _resolveLiveEditWorkingDirectory(
  final LiveEditApplyDraftRequest request, {
  required final FlutterLiveEditAutoConfig config,
}) {
  final requested = _trimToNull(request.workingDirectory);
  if (requested != null) {
    return requested;
  }
  final configured = _trimToNull(config.workingDirectory);
  if (configured != null) {
    return configured;
  }
  final inferred = _workingDirectoryFromSelection(request.selection);
  if (inferred != null) {
    return inferred;
  }
  final cwd = Directory.current.path;
  return File('$cwd/pubspec.yaml').existsSync() ? cwd : null;
}

String? _workingDirectoryFromSelection(final LiveEditSelection? selection) {
  final sourceFile = _trimToNull(selection?.source?.file);
  if (sourceFile == null) {
    return null;
  }
  final normalized = _normalizePath(sourceFile);
  final file = File(normalized);
  Directory? cursor = file.existsSync() ? file.parent : Directory(normalized);
  while (cursor != null) {
    final pubspec = File('${cursor.path}/pubspec.yaml');
    if (pubspec.existsSync()) {
      return cursor.path;
    }
    final parent = cursor.parent;
    if (parent.path == cursor.path) {
      break;
    }
    cursor = parent;
  }
  return null;
}

String _normalizePath(final String rawPath) {
  final uri = Uri.tryParse(rawPath);
  if (uri != null && uri.scheme == 'file') {
    return uri.toFilePath();
  }
  return rawPath;
}

String? _trimToNull(final String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

Future<LiveEditRuntimeRefreshResult> _refreshRuntimeAfterApply(
  final LiveEditApplyDraftRequest request,
) async {
  if (kIsWeb || kReleaseMode) {
    return const LiveEditRuntimeRefreshResult(
      validation: <String, Object?>{
        'validated': false,
        'reason': 'runtime_refresh_unavailable',
      },
    );
  }

  final info = await developer.Service.getInfo();
  final wsUri =
      info.serverWebSocketUri ??
      (info.serverUri == null
          ? null
          : convertToWebSocketUrl(serviceProtocolUrl: info.serverUri!));
  if (wsUri == null) {
    return const LiveEditRuntimeRefreshResult(
      validation: <String, Object?>{
        'validated': false,
        'reason': 'vm_service_uri_unavailable',
      },
    );
  }

  final service = await vmServiceConnectUri(wsUri.toString());
  try {
    final vm = await service.getVM();
    final isolateId = vm.isolates != null && vm.isolates!.isNotEmpty
        ? vm.isolates!.first.id
        : null;
    if (isolateId == null || isolateId.isEmpty) {
      return const LiveEditRuntimeRefreshResult(
        validation: <String, Object?>{
          'validated': false,
          'reason': 'isolate_unavailable',
        },
      );
    }

    request.onEvent?.call(
      const LiveEditRuntimeEvent(
        kind: LiveEditRuntimeEventKind.codex,
        message: 'Triggering hot reload after apply.',
      ),
    );
    final hotReload = await _triggerOwnHotReload(service, isolateId: isolateId);
    if (hotReload['ok'] == true) {
      return LiveEditRuntimeRefreshResult(
        action: LiveEditRuntimeAction.hotReload,
        validation: <String, Object?>{
          'validated': true,
          'reason': '${hotReload['reason'] ?? 'hot_reload_succeeded'}',
        },
        hotReload: hotReload,
      );
    }

    if (!_shouldAutoRestartAfterApply(request)) {
      request.onEvent?.call(
        const LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.codex,
          message:
              'Hot reload did not confirm success. Skipping auto-restart for a widget-scoped edit.',
        ),
      );
      return LiveEditRuntimeRefreshResult(
        validation: <String, Object?>{
          'validated': false,
          'reason': 'hot_reload_failed_restart_skipped',
        },
        hotReload: hotReload,
      );
    }

    request.onEvent?.call(
      const LiveEditRuntimeEvent(
        kind: LiveEditRuntimeEventKind.codex,
        message:
            'Hot reload did not confirm success for a broad edit. Triggering hot restart.',
      ),
    );
    final hotRestart = await _triggerOwnHotRestart(service);
    return LiveEditRuntimeRefreshResult(
      action: hotRestart['ok'] == true
          ? LiveEditRuntimeAction.hotRestart
          : LiveEditRuntimeAction.none,
      validation: <String, Object?>{
        'validated': hotRestart['ok'] == true,
        'reason': hotRestart['ok'] == true
            ? 'hot_restart_after_reload_failure'
            : 'hot_restart_failed',
      },
      hotReload: hotReload,
      hotRestart: hotRestart,
      validationRecovery: const <String, Object?>{'attempted': true},
    );
  } finally {
    await service.dispose();
  }
}

bool _shouldAutoRestartAfterApply(final LiveEditApplyDraftRequest request) {
  if (request.effectivePrimarySelection != null ||
      request.effectiveSelectedWidgets.isNotEmpty ||
      request.selection != null ||
      request.sourceTargets.isNotEmpty) {
    return false;
  }
  return true;
}

Future<Map<String, Object?>> _triggerOwnHotReload(
  final VmService service, {
  required final String isolateId,
}) async {
  StreamSubscription<Event>? serviceStreamSubscription;
  try {
    final hotReloadMethodNameCompleter = Completer<String?>();
    serviceStreamSubscription = service.onEvent(EventStreams.kService).listen((
      final event,
    ) {
      if (event.kind == EventKind.kServiceRegistered &&
          event.service == 'reloadSources' &&
          !hotReloadMethodNameCompleter.isCompleted) {
        hotReloadMethodNameCompleter.complete(event.method);
      }
    });

    await service.streamListen(EventStreams.kService);
    final hotReloadMethodName = await hotReloadMethodNameCompleter.future
        .timeout(const Duration(milliseconds: 1000), onTimeout: () => null);

    if (hotReloadMethodName == null) {
      final report = await service.reloadSources(isolateId, force: true);
      final json = report.toJson();
      final success =
          report.success == true ||
          '${json['type'] ?? ''}'.trim().toLowerCase() == 'success';
      return <String, Object?>{
        'ok': success,
        'reason': success ? 'reload_report_success' : 'reload_report_failed',
        'report': json,
      };
    }

    final response = await service.callMethod(
      hotReloadMethodName,
      isolateId: isolateId,
      args: <String, Object?>{'force': true},
    );
    final json = response.json ?? const <String, Object?>{};
    final responseType = '${json['type'] ?? ''}'.trim().toLowerCase();
    final success =
        responseType == 'success' ||
        (responseType == 'reloadreport' && json['success'] == true);
    return <String, Object?>{
      'ok': success,
      'reason': success
          ? 'reload_service_extension_success'
          : 'reload_service_extension_failed',
      'report': json,
    };
  } on Exception catch (error) {
    return <String, Object?>{
      'ok': false,
      'reason': 'hot_reload_exception',
      'error': '$error',
    };
  } finally {
    try {
      await serviceStreamSubscription?.cancel();
      await service.streamCancel(EventStreams.kService);
    } catch (_) {
      // Ignore shutdown races.
    }
  }
}

Future<Map<String, Object?>> _triggerOwnHotRestart(
  final VmService service,
) async {
  String? hotRestartMethodName;
  StreamSubscription<Event>? eventSubscription;
  try {
    final completer = Completer<String?>();
    eventSubscription = service.onEvent(EventStreams.kService).listen((
      final event,
    ) {
      if (event.kind == EventKind.kServiceRegistered &&
          event.service == 'hotRestart' &&
          !completer.isCompleted) {
        completer.complete(event.method);
      }
    });

    await service.streamListen(EventStreams.kService);
    hotRestartMethodName = await completer.future.timeout(
      const Duration(milliseconds: 800),
      onTimeout: () => null,
    );
  } finally {
    try {
      await eventSubscription?.cancel();
      await service.streamCancel(EventStreams.kService);
    } catch (_) {
      // Ignore shutdown races.
    }
  }

  try {
    final response = await service.callMethod(
      hotRestartMethodName ?? 'hotRestart',
    );
    return <String, Object?>{
      'ok': true,
      'report': <String, Object?>{
        'type': response.json?['type'] ?? 'Success',
        'success': response.json?['success'] ?? true,
      },
    };
  } on Exception catch (error) {
    return <String, Object?>{'ok': false, 'error': '$error'};
  }
}

List<String> _liveEditRequestDebugDetails(
  final LiveEditApplyDraftRequest request, {
  required final String backendId,
  required final String workingDirectory,
}) => <String>[
  'Session: ${request.sessionId}',
  'Backend: $backendId',
  if ((request.inferenceConfig?.model ?? '').trim().isNotEmpty)
    'Model: ${request.inferenceConfig!.model}',
  if ((request.inferenceConfig?.reasoningEffort ?? '').trim().isNotEmpty)
    'Reasoning: ${request.inferenceConfig!.reasoningEffort}',
  'Workspace: $workingDirectory',
  'Node: ${request.selection?.nodeId ?? '<none>'}',
  'Intent present: ${(request.intentText ?? '').trim().isNotEmpty}',
];

void _emitInferenceStreamEvent(
  final LiveEditApplyDraftRequest request,
  final InferenceStructuredTextStreamEvent event, {
  required final String backendId,
}) {
  final sink = request.onEvent;
  if (sink == null) {
    return;
  }

  final attempt = event.attempt == null ? null : 'Attempt: ${event.attempt}';
  final metadata = event.metadata.entries
      .where((final entry) => '${entry.value}'.trim().isNotEmpty)
      .take(4)
      .map((final entry) => '${entry.key}: ${entry.value}')
      .toList(growable: false);
  final backendLabel = _backendLabelForEvent(backendId);

  switch (event.type) {
    case InferenceStructuredTextStreamEventType.lifecycle:
      final lifecycleState = event.lifecycleState == null
          ? null
          : 'State: ${event.lifecycleState!.name}';
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.codex,
          message: event.message ?? '$backendLabel stream lifecycle updated.',
          details: _detailList(<String?>[attempt, lifecycleState, ...metadata]),
        ),
      );
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Inference lifecycle event.',
          details: _detailList(<String?>[
            event.message,
            attempt,
            lifecycleState,
            ...metadata,
          ]),
          debugOnly: true,
        ),
      );
    case InferenceStructuredTextStreamEventType.progress:
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.codex,
          message: _truncateForActivity(
            event.message ?? '$backendLabel reported progress.',
          ),
          details: _detailList(<String?>[attempt, ...metadata]),
        ),
      );
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Inference progress event.',
          details: _detailList(<String?>[event.message, attempt, ...metadata]),
          debugOnly: true,
        ),
      );
    case InferenceStructuredTextStreamEventType.partialOutput:
      final textDelta = (event.textDelta ?? '').trim().isEmpty
          ? null
          : event.textDelta!;
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.codex,
          message: '$backendLabel streamed output.',
          details: _detailList(<String?>[
            attempt,
            if (textDelta == null) null else _truncateForActivity(textDelta),
          ]),
        ),
      );
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Inference partial output event.',
          details: _detailList(<String?>[textDelta, attempt]),
          debugOnly: true,
        ),
      );
    case InferenceStructuredTextStreamEventType.raw:
      final rawText = (event.rawText ?? '').trim().isEmpty
          ? null
          : event.rawText!;
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message:
              'Raw ${event.rawChannel?.name ?? 'stream'} chunk from $backendLabel.',
          details: _detailList(<String?>[rawText, attempt, ...metadata]),
          debugOnly: true,
        ),
      );
    case InferenceStructuredTextStreamEventType.warning:
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.codex,
          message: event.message ?? '$backendLabel emitted a warning.',
          details: _detailList(<String?>[
            attempt,
            if (event.isTransient) 'Transient warning',
          ]),
        ),
      );
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Inference warning event.',
          details: _detailList(<String?>[
            event.message,
            attempt,
            if (event.isTransient) 'Transient warning',
          ]),
          debugOnly: true,
        ),
      );
    case InferenceStructuredTextStreamEventType.error:
      final errorCode = event.error == null
          ? null
          : 'Code: ${event.error!.code}';
      final errorDetails = event.error?.details == null
          ? null
          : '${event.error!.details}';
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.codex,
          message:
              event.message ?? event.error?.message ?? '$backendLabel failed.',
          details: _detailList(<String?>[attempt, errorCode]),
        ),
      );
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Inference error event.',
          details: _detailList(<String?>[
            event.message,
            errorCode,
            errorDetails,
            attempt,
          ]),
          debugOnly: true,
        ),
      );
    case InferenceStructuredTextStreamEventType.completion:
      final attemptCount = event.completion?.attemptCount == null
          ? null
          : 'Attempts: ${event.completion!.attemptCount}';
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.codex,
          message: event.completion?.result.success == true
              ? '$backendLabel stream completed.'
              : '$backendLabel stream failed.',
          details: _detailList(<String?>[attempt, attemptCount]),
        ),
      );
      sink(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Inference completion event.',
          details: _detailList(<String?>[
            'Success: ${event.completion?.result.success == true}',
            attempt,
            attemptCount,
          ]),
          debugOnly: true,
        ),
      );
  }
}

String _backendLabelForEvent(final String backendId) => backendId;

List<String> _detailList(final List<String?> values) =>
    values.whereType<String>().toList(growable: false);

String _liveEditErrorMessage(final String message, {final Object? details}) {
  final normalizedMessage = message.trim().isEmpty
      ? 'Live edit failed.'
      : message.trim();
  String? salient;
  if (details is Map) {
    final map = details.map(
      (final key, final value) => MapEntry('$key', value),
    );
    final stderr = '${map['stderr'] ?? ''}'.trim();
    final rawDetails = '${map['rawDetails'] ?? ''}'.trim();
    if (stderr.isNotEmpty) {
      salient = stderr;
    } else if (rawDetails.isNotEmpty) {
      salient = rawDetails;
    }
  } else {
    final raw = '$details'.trim();
    if (raw.isNotEmpty && raw != 'null') {
      salient = raw;
    }
  }
  if (salient == null || salient == normalizedMessage) {
    return normalizedMessage;
  }
  return '$normalizedMessage\n$salient';
}

Map<String, Object?> _liveEditFailureResponse(
  final String message, {
  final Object? details,
  final Map<String, Object?> meta = const <String, Object?>{},
}) => <String, Object?>{
  'ok': false,
  'message': _liveEditErrorMessage(message, details: details),
  'details': details,
  if (meta.isNotEmpty) 'meta': meta,
  'error': <String, Object?>{
    'message': _liveEditErrorMessage(message, details: details),
    ..._optionalEntry('details', details),
    if (meta.isNotEmpty) 'meta': meta,
  },
};

Map<String, Object?> _optionalEntry(final String key, final Object? value) =>
    value == null ? const <String, Object?>{} : <String, Object?>{key: value};

String _truncateForActivity(final String value, {final int max = 140}) {
  final trimmed = value.trim();
  if (trimmed.length <= max) {
    return trimmed;
  }
  return '${trimmed.substring(0, max)}...';
}
