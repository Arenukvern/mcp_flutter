import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/client.dart';
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
  OnGetPubDocEntry(), // Register the new tool
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
    final entry = MCPCallEntry.tool(
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
      definition: MCPToolDefinition(
        name: 'app_errors',
        description:
            'Get application errors and diagnostics information. '
            'Returns recent errors with file paths and line numbers '
            'for debugging.',
        inputSchema: ObjectSchema(
          properties: {
            'count': IntegerSchema(
              description: 'Number of recent errors to retrieve',
              minimum: 1,
              maximum: 10,
            ),
          },
        ),
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
    final entry = MCPCallEntry.tool(
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
      definition: MCPToolDefinition(
        name: 'view_screenshots',
        description:
            'Take screenshots of all Flutter views/screens. '
            'Useful for visual debugging and UI analysis.',
        inputSchema: ObjectSchema(
          properties: {
            'compress': BooleanSchema(
              description: 'Whether to compress the screenshots',
            ),
          },
        ),
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
    final entry = MCPCallEntry.tool(
      handler: (final parameters) {
        final details = ApplicationInfo.getViewsInformation();
        final json = details.map((final e) => e.toJson()).toList();
        return MCPCallResult(
          message: 'Information about each view. ',
          parameters: {'details': json},
        );
      },
      definition: MCPToolDefinition(
        name: 'view_details',
        description:
            'Get detailed information about Flutter views and widgets. '
            'Returns structural information about the current UI state.',
        inputSchema: ObjectSchema(properties: {}),
      ),
    );
    return OnViewDetailsEntry._(entry);
  }
}

/// {@template on_get_pub_doc_entry}
/// MCPCallEntry for retrieving package documentation (README) from pub.dev or local pub cache.
/// {@endtemplate}
extension type OnGetPubDocEntry._(MCPCallEntry entry) implements MCPCallEntry {
  /// {@macro on_get_pub_doc_entry}
  factory OnGetPubDocEntry() {
    final entry = MCPCallEntry.tool(
      handler: (final parameters) async {
        final package = parameters['package']?.toString();
        final fvmSdkPath = parameters['fvm_sdk_path']?.toString();
        if (package == null || package.isEmpty) {
          return MCPCallResult(
            message: 'No package name provided.',
            parameters: {'readme': '', 'source': 'none'},
          );
        }
        // Try pub.dev first
        final pubDevUrl =
            'https://pub.dev/packages/$package/versions/latest/README.md';
        try {
          final uri = Uri.parse(pubDevUrl);
          final client = HttpClient();
          final request = await client.getUrl(uri);
          final response = await request.close();
          if (response.statusCode == 200) {
            final contents =
                await response.transform(const Utf8Decoder()).join();
            return MCPCallResult(
              message: 'README fetched from pub.dev',
              parameters: {'readme': contents, 'source': 'pub.dev'},
            );
          }
        } catch (_) {
          // Ignore and fallback
        }
        // Fallback: try local pub cache
        String pubCache;
        if (fvmSdkPath != null && fvmSdkPath.isNotEmpty) {
          pubCache = '$fvmSdkPath/.pub-cache/hosted/pub.dev/$package';
        } else {
          final home =
              Platform.environment['HOME'] ??
              Platform.environment['USERPROFILE'] ??
              '';
          pubCache = '$home/.pub-cache/hosted/pub.dev/$package';
        }
        String? readmeContent;
        try {
          final dir = Directory(pubCache);
          if (dir.existsSync()) {
            final files = dir.listSync(recursive: true).cast<File>();
            final readmeFiles = files.where(
              (final f) => f.path.toLowerCase().endsWith('readme.md'),
            );
            if (readmeFiles.isNotEmpty) {
              final readmeFile = readmeFiles.first;
              readmeContent = readmeFile.readAsStringSync();
            }
          }
        } catch (_) {
          // Ignore
        }
        if (readmeContent != null && readmeContent.isNotEmpty) {
          return MCPCallResult(
            message: 'README fetched from local pub cache',
            parameters: {'readme': readmeContent, 'source': 'local'},
          );
        }
        return MCPCallResult(
          message: 'README not found for package: $package',
          parameters: {'readme': '', 'source': 'not_found'},
        );
      },
      definition: MCPToolDefinition(
        name: 'get_pub_doc',
        description:
            'Get the README documentation for a Dart/Flutter package from pub.dev or local pub cache. Supports FVM SDK path.',
        inputSchema: ObjectSchema(
          properties: {
            'package': StringSchema(
              description: 'The package name to fetch documentation for',
            ),
            'fvm_sdk_path': StringSchema(
              description:
                  'Optional: The FVM SDK path to use for pub cache lookup',
            ),
          },
        ),
      ),
    );
    return OnGetPubDocEntry._(entry);
  }
}
