import 'dart:async';

import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:is_dart_empty_or_not/is_dart_empty_or_not.dart';

import '../mcp_models.dart';
import '../mcp_toolkit_binding.dart';
import '../services/application_info.dart';
import '../services/error_monitor.dart';
import '../services/screenshot_service.dart';

/// Returns a set of MCPCallEntry objects for the Flutter MCP Toolkit.
///
/// The toolkit provides functionality for handling app errors,
/// view screenshots, and view details.
///
/// [binding] is the MCP toolkit binding instance.
Set<MCPCallEntry> getFlutterMcpToolkitEntries({
  required final MCPToolkitBinding binding,
}) => {
  OnAppErrorsEntry(errorMonitor: binding),
  OnViewScreenshotsEntry(),
  OnViewDetailsEntry(),
};

/// Extension on [MCPToolkitBinding] to initialize the Flutter MCP Toolkit.
extension MCPToolkitBindingExtension on MCPToolkitBinding {
  /// Initializes the Flutter MCP Toolkit.
  void initializeFlutterToolkit() => unawaited(
    addEntries(entries: getFlutterMcpToolkitEntries(binding: this)),
  );
}

/// {@template on_app_errors_entry}
/// MCPCallEntry for handling app errors.
/// {@endtemplate}
extension type OnAppErrorsEntry._(MCPCallEntry entry) implements MCPCallEntry {
  /// {@macro on_app_errors_entry}
  factory OnAppErrorsEntry({required final ErrorMonitor errorMonitor}) {
    final entry = MCPCallEntry(
      methodName: const MCPMethodName('app_errors'),
      handler: (final parameters) {
        final count = jsonDecodeInt(parameters['count'] ?? '').whenZeroUse(10);
        final reversedErrors = errorMonitor.errors.take(count).toList();
        final errors = reversedErrors.map((final e) => e.toJson()).toList();
        final message = () {
          if (errors.isEmpty) {
            return 'No errors found. Here are possible reasons: \n'
                '1) There were really no errors. \n'
                '2) Errors occurred before they were captured by MCP server. \n'
                'What you can do (choose wisely): \n'
                '1) Try to reproduce action, which expected to cause errors. \n'
                '2) If errors still not visible, try to navigate to another '
                'screen and back. \n'
                '3) If even then errors still not visible, try to restart app.';
          }

          return 'Errors found. \n'
              'Take a notice: the error message may have contain '
              'a path to file and line number. \n'
              'Use it to find the error in codebase.';
        }();

        return MCPCallResult(message: message, parameters: {'errors': errors});
      },
      toolDefinition: MCPToolDefinition(
        name: 'app_errors',
        description:
            'Get application errors and diagnostics information. '
            'Returns recent errors with file paths and line numbers '
            'for debugging.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'count': {
              'type': 'integer',
              'description': 'Number of recent errors to retrieve',
              'default': 10,
              'minimum': 1,
              'maximum': 100,
            },
          },
        },
      ),
    );
    return OnAppErrorsEntry._(entry);
  }
}

/// {@template on_view_screenshots_entry}
/// MCPCallEntry for handling view screenshots.
/// {@endtemplate}
extension type OnViewScreenshotsEntry._(MCPCallEntry entry)
    implements MCPCallEntry {
  /// {@macro on_view_screenshots_entry}
  factory OnViewScreenshotsEntry() {
    final entry = MCPCallEntry(
      methodName: const MCPMethodName('view_screenshots'),
      handler: (final parameters) async {
        final compress = jsonDecodeBool(parameters['compress']);
        final images = await ScreenshotService.takeScreenshots(
          compress: compress,
        );
        return MCPCallResult(
          message:
              'Screenshots taken for each view. '
              'If you find visual errors, you can try to request errors '
              'to get more information with stack trace',
          parameters: {'images': images},
        );
      },
      toolDefinition: MCPToolDefinition(
        name: 'view_screenshots',
        description:
            'Take screenshots of all Flutter views/screens. '
            'Useful for visual debugging and UI analysis.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'compress': {
              'type': 'boolean',
              'description': 'Whether to compress the screenshots',
              'default': false,
            },
          },
        },
      ),
    );
    return OnViewScreenshotsEntry._(entry);
  }
}

/// {@template on_view_details_entry}
/// MCPCallEntry for handling view details.
/// {@endtemplate}
extension type const OnViewDetailsEntry._(MCPCallEntry entry)
    implements MCPCallEntry {
  /// {@macro on_view_details_entry}
  factory OnViewDetailsEntry() {
    final entry = MCPCallEntry(
      methodName: const MCPMethodName('view_details'),
      handler: (final parameters) {
        final details = ApplicationInfo.getViewsInformation();
        final json = details.map((final e) => e.toJson()).toList();
        return MCPCallResult(
          message: 'Information about each view. ',
          parameters: {'details': json},
        );
      },
      toolDefinition: MCPToolDefinition(
        name: 'view_details',
        description:
            'Get detailed information about Flutter views and widgets. '
            'Returns structural information about the current UI state.',
        inputSchema: {'type': 'object', 'properties': {}},
      ),
    );
    return OnViewDetailsEntry._(entry);
  }
}
