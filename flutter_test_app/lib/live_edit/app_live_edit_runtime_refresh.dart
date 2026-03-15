import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';
import 'package:vm_service/utils.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

Future<LiveEditRuntimeRefreshResult> refreshRuntimeAfterApply(
  final LiveEditApplyDraftRequest request,
) async {
  if (kReleaseMode) {
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
  if (request.draftChanges.isNotEmpty ||
      request.effectiveStagedPropertyChanges.isNotEmpty) {
    return false;
  }
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
