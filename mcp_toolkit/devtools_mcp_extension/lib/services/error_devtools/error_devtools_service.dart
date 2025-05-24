part of '../custom_devtools_service.dart';

/// Service for analyzing and detecting visual errors in Flutter applications
/// using the VM Service and Widget Inspector.
final class ErrorDevtoolsService extends BaseDevtoolsService {
  ErrorDevtoolsService({required super.devtoolsService});
  late final _flutterErrorMonitor = FlutterErrorMonitor(
    serviceManager: devtoolsService.serviceManager,
  );

  Future<void> init() async {
    await _flutterErrorMonitor.initialize();
  }

  Future<void> dispose() async {
    await _flutterErrorMonitor.dispose();
  }

  /// Returns a list of visual errors in the Flutter application.
  ///
  /// Before calling this function, make sure it was launched before the error
  /// happened.
  Future<RPCResponse> getAppErrors(final Map<String, dynamic> params) async {
    final count = params['count'] ?? 10;
    final serviceManager = devtoolsService.serviceManager;
    if (!serviceManager.connectedState.value.connected) {
      return RPCResponse.error('Not connected to VM service');
    }
    final errors = _flutterErrorMonitor.errors;

    if (errors.isEmpty) {
      /// Make sure it is written stylistically FOR AI, not for users.
      return RPCResponse.successMap({
        'message':
            'No errors found. Here are possible reasons: \n'
            '1) There were really no errors. \n'
            '2) Errors occurred before they were captured by MCP server. \n'
            'What you can do (choose wisely): \n'
            '1) Try to reproduce action, which expected to cause errors. \n'
            '2) If errors still not visible, try to navigate to another screen and back. \n'
            '3) If even then errors still not visible, try to restart app.',
      });
    }

    return RPCResponse.successMap({
      'message':
          'Errors found. \n'
          'Take a notice: the error message may have contain '
          'a path to file and line number. \n'
          'Use it to find the error in codebase.',
      'errors': errors.take(count).map((final e) => e.toJson()).toList(),
    });
  }
}
