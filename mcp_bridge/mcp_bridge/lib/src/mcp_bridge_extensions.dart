// ignore_for_file: prefer_asserts_with_message, lines_longer_than_80_chars

import 'package:flutter/cupertino.dart';
import 'package:from_json_to_json/from_json_to_json.dart';

import 'mcp_bridge_binding_base.dart';
import 'services/application_info.dart';
import 'services/error_monitor.dart';
import 'services/screenshot_service.dart';

/// A mixin that adds MCP Bridge extensions to a binding.
mixin McpBridgeExtensions on McpBridgeBindingBase {
  var _debugServiceExtensionsRegistered = false;

  /// Called when the binding is initialized, to register service
  /// extensions.
  ///
  /// Bindings that want to expose service extensions should overload
  /// this method to register them using calls to
  /// [registerSignalServiceExtension],
  /// [registerBoolServiceExtension],
  /// [registerNumericServiceExtension], and
  /// [registerServiceExtension] (in increasing order of complexity).
  ///
  /// Implementations of this method must call their superclass
  /// implementation.
  ///
  /// {@macro flutter.foundation.BindingBase.registerServiceExtension}
  ///
  /// See also:
  ///
  ///  * <https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/service.md#rpcs-requests-and-responses>

  @protected
  @mustCallSuper
  void initializeServiceExtension({required final ErrorMonitor errorMonitor}) {
    assert(!_debugServiceExtensionsRegistered);
    // if (!kReleaseMode) {}
    assert(() {
      registerServiceExtension(
        name: 'apperrors',
        callback: (final parameters) async {
          final count = int.tryParse(parameters['count'] ?? '') ?? 10;
          final reversedErrors = errorMonitor.errors.take(count).toList();
          final errors = reversedErrors.map((final e) => e.toJson()).toList();
          final message = () {
            if (errors.isEmpty) {
              return 'No errors found. Here are possible reasons: \n'
                  '1) There were really no errors. \n'
                  '2) Errors occurred before they were captured by MCP server. \n'
                  'What you can do (choose wisely): \n'
                  '1) Try to reproduce action, which expected to cause errors. \n'
                  '2) If errors still not visible, try to navigate to another screen and back. \n'
                  '3) If even then errors still not visible, try to restart app.';
            }

            return 'Errors found. \n'
                'Take a notice: the error message may have contain '
                'a path to file and line number. \n'
                'Use it to find the error in codebase.';
          }();

          return {'message': message, 'errors': errors};
        },
      );

      registerServiceExtension(
        name: 'view_screenshots',
        callback: (final parameters) async {
          final compress = jsonDecodeBool(parameters['compress']);
          final images = await ScreenshotService.takeScreenshots(
            compress: compress,
          );
          return {
            'message':
                'Screenshots taken for each view. '
                'If you find visual errors, you can try to request errors '
                'to get more information with stack trace',
            'images': images,
          };
        },
      );

      registerServiceExtension(
        name: 'view_details',
        callback: (final parameters) async {
          final details = ApplicationInfo.getViewsInformation();
          final json = details.map((final e) => e.toJson()).toList();
          return {'message': 'Information about each view. ', 'details': json};
        },
      );

      return true;
    }());
    assert(() {
      _debugServiceExtensionsRegistered = true;
      return true;
    }());
  }
}
