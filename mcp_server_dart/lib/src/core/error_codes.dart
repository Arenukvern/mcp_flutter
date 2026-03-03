// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

/// Stable error-code catalog for core command execution.
abstract final class CoreErrorCode {
  static const unexpectedExecutorError = 'unexpected_executor_error';

  static const connectFailed = 'connect_failed';
  static const vmNotConnected = 'vm_not_connected';

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

  static const sessionManagerNotConfigured = 'session_manager_not_configured';
  static const sessionNotFound = 'session_not_found';
  static const invalidCommand = 'invalid_command';
  static const stateStoreReadFailed = 'state_store_read_failed';
  static const stateStoreWriteFailed = 'state_store_write_failed';

  static const diagnoseFailed = 'diagnose_failed';
  static const explainErrorsFailed = 'explain_errors_failed';
  static const unsupportedSummaryProvider = 'unsupported_summary_provider';
}
