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
  static const getViewDetailsFailed = 'get_view_details_failed';
  static const debugDumpFailed = 'debug_dump_failed';

  static const dynamicRegistryDisabled = 'dynamic_registry_disabled';
  static const dynamicRegistryListFailed = 'dynamic_registry_list_failed';
  static const missingToolName = 'missing_tool_name';
  static const dynamicToolFailed = 'dynamic_tool_failed';
  static const missingResourceUri = 'missing_resource_uri';
  static const dynamicResourceFailed = 'dynamic_resource_failed';

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
  static const bundleBuildFailed = 'bundle_build_failed';

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
      CoreErrorCode.bundleBuildFailed: CoreErrorDescriptor(
        code: CoreErrorCode.bundleBuildFailed,
        category: CoreErrorCategory.io,
        retryable: true,
        exitCode: 74,
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

int exitCodeForErrorCode(final String? code) {
  return descriptorForErrorCode(code).exitCode;
}
