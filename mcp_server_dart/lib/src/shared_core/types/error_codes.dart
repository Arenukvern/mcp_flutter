// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:meta/meta.dart';

@immutable
final class CoreErrorDescriptor {
  const CoreErrorDescriptor({
    required this.code,
    required this.category,
    required this.retryable,
    required this.exitCode,
    required this.httpLikeStatus,
  });

  final String code;
  final String category;
  final bool retryable;
  final int exitCode;
  final int httpLikeStatus;

  Map<String, Object?> toJson() => {
    'code': code,
    'category': category,
    'retryable': retryable,
    'exitCode': exitCode,
    'httpLikeStatus': httpLikeStatus,
  };
}

abstract final class CoreErrorCategory {
  static const connectivity = 'connectivity';
  static const vm = 'vm';
  static const validation = 'validation';
  static const state = 'state';
  static const dynamicRegistry = 'dynamic_registry';
  static const execution = 'execution';
  static const internal = 'internal';
  static const capability = 'capability';
  static const timeout = 'timeout';
  static const io = 'io';
}

/// Stable error-code catalog for core command execution.
abstract final class CoreErrorCode {
  static const unexpectedExecutorError = 'unexpected_executor_error';

  static const connectFailed = 'connect_failed';
  static const vmNotConnected = 'vm_not_connected';
  static const connectionSelectionRequired = 'connection_selection_required';

  static const discoverDebugAppsFailed = 'discover_debug_apps_failed';
  static const getVmFailed = 'get_vm_failed';
  static const getExtensionRpcsFailed = 'get_extension_rpcs_failed';
  static const hotReloadFailed = 'hot_reload_failed';
  static const hotRestartFailed = 'hot_restart_failed';
  static const getActivePortsFailed = 'get_active_ports_failed';
  static const getAppErrorsFailed = 'get_app_errors_failed';
  static const getScreenshotsFailed = 'get_screenshots_failed';
  static const visualCapturePermissionDenied =
      'visual_capture_permission_denied';
  static const visualCaptureUnsupported = 'visual_capture_unsupported';
  static const getViewDetailsFailed = 'get_view_details_failed';
  static const debugDumpFailed = 'debug_dump_failed';

  static const dynamicRegistryDisabled = 'dynamic_registry_disabled';
  static const dynamicRegistryListFailed = 'dynamic_registry_list_failed';
  static const missingToolName = 'missing_tool_name';
  static const dynamicToolFailed = 'dynamic_tool_failed';
  static const missingResourceUri = 'missing_resource_uri';
  static const dynamicResourceFailed = 'dynamic_resource_failed';
  static const liveEditBackendFailed = 'live_edit_backend_failed';
  static const liveEditProposalNotFound = 'live_edit_proposal_not_found';
  static const liveEditApplyFailed = 'live_edit_apply_failed';
  static const liveEditValidationFailed = 'live_edit_validation_failed';
  static const liveEditDisabled = 'live_edit_disabled';

  static const sessionManagerNotConfigured = 'session_manager_not_configured';
  static const sessionNotFound = 'session_not_found';
  static const invalidCommand = 'invalid_command';
  static const stateStoreReadFailed = 'state_store_read_failed';
  static const stateStoreWriteFailed = 'state_store_write_failed';
  static const stateLockTimeout = 'state_lock_timeout';
  static const stateLockConflict = 'state_lock_conflict';

  static const diagnoseFailed = 'diagnose_failed';
  static const explainErrorsFailed = 'explain_errors_failed';
  static const unsupportedSummaryProvider = 'unsupported_summary_provider';

  static const snapshotNotFound = 'snapshot_not_found';
  static const snapshotInvalid = 'snapshot_invalid';
  static const staleSnapshot = 'stale_snapshot';
  static const bundleBuildFailed = 'bundle_build_failed';
  static const writeBlocked = 'write_blocked';
  static const doctorCriticalFailed = 'doctor_critical_failed';

  static const interactionFailed = 'interaction_failed';
  static const semanticSnapshotFailed = 'semantic_snapshot_failed';
  static const evaluateExpressionFailed = 'evaluate_expression_failed';
  static const getRecentLogsFailed = 'get_recent_logs_failed';

  static const waitTimeout = 'wait_timeout';
  static const waitForFailed = 'wait_for_failed';

  static const unknown = 'unknown_error';
}

const Map<String, CoreErrorDescriptor> _descriptorMap =
    <String, CoreErrorDescriptor>{
      CoreErrorCode.unexpectedExecutorError: CoreErrorDescriptor(
        code: CoreErrorCode.unexpectedExecutorError,
        category: CoreErrorCategory.internal,
        retryable: false,
        exitCode: 70,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.connectFailed: CoreErrorDescriptor(
        code: CoreErrorCode.connectFailed,
        category: CoreErrorCategory.connectivity,
        retryable: true,
        exitCode: 67,
        httpLikeStatus: 503,
      ),
      CoreErrorCode.vmNotConnected: CoreErrorDescriptor(
        code: CoreErrorCode.vmNotConnected,
        category: CoreErrorCategory.vm,
        retryable: true,
        exitCode: 68,
        httpLikeStatus: 503,
      ),
      CoreErrorCode.connectionSelectionRequired: CoreErrorDescriptor(
        code: CoreErrorCode.connectionSelectionRequired,
        category: CoreErrorCategory.validation,
        retryable: true,
        exitCode: 64,
        httpLikeStatus: 409,
      ),
      CoreErrorCode.discoverDebugAppsFailed: CoreErrorDescriptor(
        code: CoreErrorCode.discoverDebugAppsFailed,
        category: CoreErrorCategory.execution,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.getVmFailed: CoreErrorDescriptor(
        code: CoreErrorCode.getVmFailed,
        category: CoreErrorCategory.vm,
        retryable: true,
        exitCode: 68,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.getExtensionRpcsFailed: CoreErrorDescriptor(
        code: CoreErrorCode.getExtensionRpcsFailed,
        category: CoreErrorCategory.vm,
        retryable: true,
        exitCode: 68,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.hotReloadFailed: CoreErrorDescriptor(
        code: CoreErrorCode.hotReloadFailed,
        category: CoreErrorCategory.execution,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.hotRestartFailed: CoreErrorDescriptor(
        code: CoreErrorCode.hotRestartFailed,
        category: CoreErrorCategory.execution,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.getActivePortsFailed: CoreErrorDescriptor(
        code: CoreErrorCode.getActivePortsFailed,
        category: CoreErrorCategory.execution,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.getAppErrorsFailed: CoreErrorDescriptor(
        code: CoreErrorCode.getAppErrorsFailed,
        category: CoreErrorCategory.execution,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.getScreenshotsFailed: CoreErrorDescriptor(
        code: CoreErrorCode.getScreenshotsFailed,
        category: CoreErrorCategory.execution,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.visualCapturePermissionDenied: CoreErrorDescriptor(
        code: CoreErrorCode.visualCapturePermissionDenied,
        category: CoreErrorCategory.capability,
        retryable: true,
        exitCode: 77,
        httpLikeStatus: 403,
      ),
      CoreErrorCode.visualCaptureUnsupported: CoreErrorDescriptor(
        code: CoreErrorCode.visualCaptureUnsupported,
        category: CoreErrorCategory.capability,
        retryable: false,
        exitCode: 78,
        httpLikeStatus: 501,
      ),
      CoreErrorCode.getViewDetailsFailed: CoreErrorDescriptor(
        code: CoreErrorCode.getViewDetailsFailed,
        category: CoreErrorCategory.execution,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.debugDumpFailed: CoreErrorDescriptor(
        code: CoreErrorCode.debugDumpFailed,
        category: CoreErrorCategory.execution,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.dynamicRegistryDisabled: CoreErrorDescriptor(
        code: CoreErrorCode.dynamicRegistryDisabled,
        category: CoreErrorCategory.capability,
        retryable: false,
        exitCode: 78,
        httpLikeStatus: 501,
      ),
      CoreErrorCode.dynamicRegistryListFailed: CoreErrorDescriptor(
        code: CoreErrorCode.dynamicRegistryListFailed,
        category: CoreErrorCategory.dynamicRegistry,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.missingToolName: CoreErrorDescriptor(
        code: CoreErrorCode.missingToolName,
        category: CoreErrorCategory.validation,
        retryable: false,
        exitCode: 64,
        httpLikeStatus: 400,
      ),
      CoreErrorCode.dynamicToolFailed: CoreErrorDescriptor(
        code: CoreErrorCode.dynamicToolFailed,
        category: CoreErrorCategory.dynamicRegistry,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.missingResourceUri: CoreErrorDescriptor(
        code: CoreErrorCode.missingResourceUri,
        category: CoreErrorCategory.validation,
        retryable: false,
        exitCode: 64,
        httpLikeStatus: 400,
      ),
      CoreErrorCode.dynamicResourceFailed: CoreErrorDescriptor(
        code: CoreErrorCode.dynamicResourceFailed,
        category: CoreErrorCategory.dynamicRegistry,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.liveEditBackendFailed: CoreErrorDescriptor(
        code: CoreErrorCode.liveEditBackendFailed,
        category: CoreErrorCategory.execution,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.liveEditProposalNotFound: CoreErrorDescriptor(
        code: CoreErrorCode.liveEditProposalNotFound,
        category: CoreErrorCategory.state,
        retryable: false,
        exitCode: 66,
        httpLikeStatus: 404,
      ),
      CoreErrorCode.liveEditApplyFailed: CoreErrorDescriptor(
        code: CoreErrorCode.liveEditApplyFailed,
        category: CoreErrorCategory.io,
        retryable: false,
        exitCode: 74,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.liveEditValidationFailed: CoreErrorDescriptor(
        code: CoreErrorCode.liveEditValidationFailed,
        category: CoreErrorCategory.validation,
        retryable: false,
        exitCode: 65,
        httpLikeStatus: 409,
      ),
      CoreErrorCode.liveEditDisabled: CoreErrorDescriptor(
        code: CoreErrorCode.liveEditDisabled,
        category: CoreErrorCategory.capability,
        retryable: false,
        exitCode: 64,
        httpLikeStatus: 403,
      ),
      CoreErrorCode.sessionManagerNotConfigured: CoreErrorDescriptor(
        code: CoreErrorCode.sessionManagerNotConfigured,
        category: CoreErrorCategory.state,
        retryable: false,
        exitCode: 70,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.sessionNotFound: CoreErrorDescriptor(
        code: CoreErrorCode.sessionNotFound,
        category: CoreErrorCategory.state,
        retryable: false,
        exitCode: 66,
        httpLikeStatus: 404,
      ),
      CoreErrorCode.invalidCommand: CoreErrorDescriptor(
        code: CoreErrorCode.invalidCommand,
        category: CoreErrorCategory.validation,
        retryable: false,
        exitCode: 64,
        httpLikeStatus: 400,
      ),
      CoreErrorCode.stateStoreReadFailed: CoreErrorDescriptor(
        code: CoreErrorCode.stateStoreReadFailed,
        category: CoreErrorCategory.io,
        retryable: true,
        exitCode: 74,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.stateStoreWriteFailed: CoreErrorDescriptor(
        code: CoreErrorCode.stateStoreWriteFailed,
        category: CoreErrorCategory.io,
        retryable: true,
        exitCode: 74,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.stateLockTimeout: CoreErrorDescriptor(
        code: CoreErrorCode.stateLockTimeout,
        category: CoreErrorCategory.timeout,
        retryable: true,
        exitCode: 75,
        httpLikeStatus: 409,
      ),
      CoreErrorCode.stateLockConflict: CoreErrorDescriptor(
        code: CoreErrorCode.stateLockConflict,
        category: CoreErrorCategory.state,
        retryable: true,
        exitCode: 75,
        httpLikeStatus: 409,
      ),
      CoreErrorCode.diagnoseFailed: CoreErrorDescriptor(
        code: CoreErrorCode.diagnoseFailed,
        category: CoreErrorCategory.execution,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.explainErrorsFailed: CoreErrorDescriptor(
        code: CoreErrorCode.explainErrorsFailed,
        category: CoreErrorCategory.execution,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.unsupportedSummaryProvider: CoreErrorDescriptor(
        code: CoreErrorCode.unsupportedSummaryProvider,
        category: CoreErrorCategory.validation,
        retryable: false,
        exitCode: 64,
        httpLikeStatus: 400,
      ),
      CoreErrorCode.snapshotNotFound: CoreErrorDescriptor(
        code: CoreErrorCode.snapshotNotFound,
        category: CoreErrorCategory.state,
        retryable: false,
        exitCode: 66,
        httpLikeStatus: 404,
      ),
      CoreErrorCode.snapshotInvalid: CoreErrorDescriptor(
        code: CoreErrorCode.snapshotInvalid,
        category: CoreErrorCategory.validation,
        retryable: false,
        exitCode: 65,
        httpLikeStatus: 422,
      ),
      CoreErrorCode.staleSnapshot: CoreErrorDescriptor(
        code: CoreErrorCode.staleSnapshot,
        category: CoreErrorCategory.state,
        retryable: true,
        exitCode: 65,
        httpLikeStatus: 409,
      ),
      CoreErrorCode.bundleBuildFailed: CoreErrorDescriptor(
        code: CoreErrorCode.bundleBuildFailed,
        category: CoreErrorCategory.io,
        retryable: true,
        exitCode: 74,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.writeBlocked: CoreErrorDescriptor(
        code: CoreErrorCode.writeBlocked,
        category: CoreErrorCategory.state,
        retryable: false,
        exitCode: 73,
        httpLikeStatus: 409,
      ),
      CoreErrorCode.doctorCriticalFailed: CoreErrorDescriptor(
        code: CoreErrorCode.doctorCriticalFailed,
        category: CoreErrorCategory.validation,
        retryable: true,
        exitCode: 1,
        httpLikeStatus: 503,
      ),
      CoreErrorCode.interactionFailed: CoreErrorDescriptor(
        code: CoreErrorCode.interactionFailed,
        category: CoreErrorCategory.execution,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.semanticSnapshotFailed: CoreErrorDescriptor(
        code: CoreErrorCode.semanticSnapshotFailed,
        category: CoreErrorCategory.execution,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.evaluateExpressionFailed: CoreErrorDescriptor(
        code: CoreErrorCode.evaluateExpressionFailed,
        category: CoreErrorCategory.execution,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.getRecentLogsFailed: CoreErrorDescriptor(
        code: CoreErrorCode.getRecentLogsFailed,
        category: CoreErrorCategory.execution,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.waitTimeout: CoreErrorDescriptor(
        code: CoreErrorCode.waitTimeout,
        category: CoreErrorCategory.execution,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 408,
      ),
      CoreErrorCode.waitForFailed: CoreErrorDescriptor(
        code: CoreErrorCode.waitForFailed,
        category: CoreErrorCategory.execution,
        retryable: true,
        exitCode: 69,
        httpLikeStatus: 500,
      ),
      CoreErrorCode.unknown: CoreErrorDescriptor(
        code: CoreErrorCode.unknown,
        category: CoreErrorCategory.internal,
        retryable: false,
        exitCode: 70,
        httpLikeStatus: 500,
      ),
    };

CoreErrorDescriptor descriptorForErrorCode(final String? code) {
  if (code == null || code.isEmpty) {
    return _descriptorMap[CoreErrorCode.unknown]!;
  }

  return _descriptorMap[code] ??
      CoreErrorDescriptor(
        code: code,
        category: CoreErrorCategory.internal,
        retryable: false,
        exitCode: 70,
        httpLikeStatus: 500,
      );
}

int exitCodeForErrorCode(final String? code) =>
    descriptorForErrorCode(code).exitCode;

Map<String, Object?> recoveryForErrorCode(
  final String? code, {
  final Object? details,
}) {
  final resolvedCode = (code == null || code.isEmpty)
      ? CoreErrorCode.unknown
      : code;

  if (resolvedCode == CoreErrorCode.connectionSelectionRequired) {
    final detailMap = switch (details) {
      final Map<String, Object?> value => value,
      final Map value => value.cast<String, Object?>(),
      _ => const <String, Object?>{},
    };
    final targets = switch (detailMap['availableTargets']) {
      final List value => value,
      _ => const <Object?>[],
    };

    final firstTarget = targets.isNotEmpty && targets.first is Map
        ? (targets.first! as Map)['targetId']?.toString()
        : null;

    return {
      'summary': 'Select an explicit VM target and retry the command.',
      'fix_command': firstTarget == null
          ? """flutter_mcp_cli exec --name discover_debug_apps --args '{}'"""
          : 'flutter_mcp_cli exec --name get_vm --args '
                '\'{"connection":{"targetId":"$firstTarget"}}\'',
    };
  }

  return _defaultRecoveryMap[resolvedCode] ??
      _defaultRecoveryMap[CoreErrorCode.unknown]!;
}

const Map<String, Map<String, Object?>>
_defaultRecoveryMap = <String, Map<String, Object?>>{
  CoreErrorCode.connectFailed: <String, Object?>{
    'summary': 'Retry with an explicit VM URI target.',
    'fix_command':
        'flutter_mcp_cli exec --name get_vm --args '
        '\'{"connection":{"uri":"ws://127.0.0.1:8181/<token>/ws"}}\'',
  },
  CoreErrorCode.vmNotConnected: <String, Object?>{
    'summary': 'Connect to a running debug target before issuing VM commands.',
    'fix_command': """flutter_mcp_cli exec --name status --args '{}'""",
  },
  CoreErrorCode.invalidCommand: <String, Object?>{
    'summary': 'Validate command name, arguments, and schema types.',
    'fix_command': '''flutter_mcp_cli schema --name <command_name>''',
  },
  CoreErrorCode.dynamicRegistryDisabled: <String, Object?>{
    'summary': 'Enable dynamic registry support before dynamic tool calls.',
    'fix_command': "flutter_mcp_cli --dynamics exec --name status --args '{}'",
  },
  CoreErrorCode.liveEditBackendFailed: <String, Object?>{
    'summary': 'Check the configured live-edit backend and retry resolution.',
    'fix_command':
        'flutter_mcp_cli schema --name live_edit_resolve_draft && '
        "flutter_mcp_cli exec --name live_edit_list_agent_backends --args '{}'",
  },
  CoreErrorCode.liveEditProposalNotFound: <String, Object?>{
    'summary': 'Resolve a draft again or use a valid proposal id.',
    'fix_command':
        'flutter_mcp_cli exec --name live_edit_resolve_draft --args \'{"sessionId":"<live_edit_session>"}\'',
  },
  CoreErrorCode.liveEditApplyFailed: <String, Object?>{
    'summary':
        'Inspect the proposed file paths and write permissions, then retry.',
    'fix_command': 'flutter_mcp_cli schema --name live_edit_accept_resolution',
  },
  CoreErrorCode.liveEditValidationFailed: <String, Object?>{
    'summary':
        'The patch applied, but runtime validation did not match the draft intent.',
    'fix_command':
        'flutter_mcp_cli exec --name live_edit_get_selection --args \'{"sessionId":"<live_edit_session>"}\'',
  },
  CoreErrorCode.visualCapturePermissionDenied: <String, Object?>{
    'summary':
        'Grant Screen Recording or open settings before retrying truthful capture.',
    'fix_command': 'flutter_mcp_cli permissions open-settings',
  },
  CoreErrorCode.visualCaptureUnsupported: <String, Object?>{
    'summary': 'Use a supported target or capture mode.',
    'fix_command':
        'flutter_mcp_cli permissions status && flutter_mcp_cli doctor --json',
  },
  CoreErrorCode.snapshotNotFound: <String, Object?>{
    'summary': 'Create the snapshot before referencing it.',
    'fix_command':
        """flutter_mcp_cli snapshot create --name <snapshot_id> --args '{}'""",
  },
  CoreErrorCode.writeBlocked: <String, Object?>{
    'summary': 'Target exists and overwrite is disabled.',
    'fix_command': 'Retry without --no-overwrite or change --output/--name.',
  },
  CoreErrorCode.doctorCriticalFailed: <String, Object?>{
    'summary': 'Resolve critical environment checks before continuing.',
    'fix_command': '''flutter_mcp_cli doctor --json''',
  },
  CoreErrorCode.unknown: <String, Object?>{
    'summary': 'Inspect error details and retry once prerequisites are fixed.',
    'fix_command': '''flutter_mcp_cli doctor --json''',
  },
};
