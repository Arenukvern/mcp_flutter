import 'dart:async';

import 'package:intentcall_core/intentcall_core.dart';

import 'package:dart_mcp/client.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:is_dart_empty_or_not/is_dart_empty_or_not.dart';

import '../agent_entry_helpers.dart';
import '../mcp_models.dart';
import '../mcp_toolkit_binding.dart';
import '../services/error_monitor.dart';
import '../services/screenshot_service.dart';
import '../services/view_introspection_service.dart';
import 'interaction_toolkit.dart';

/// Returns [AgentCallEntry] values for the Flutter MCP Toolkit.
///
/// The toolkit provides functionality for handling app errors,
/// view screenshots, and view details.
///
/// [binding] is the MCP toolkit binding instance.

/// Public name of the `select_widget_at_point` MCP tool.
const selectWidgetAtPointToolName = 'select_widget_at_point';

/// MCP tool entries for Flutter screenshots, errors, views, and interactions.
Set<AgentCallEntry> getFlutterMcpToolkitEntries({
  required final MCPToolkitBinding binding,
}) => {
  OnAppErrorsEntry(errorMonitor: binding),
  OnViewScreenshotsEntry(binding: binding),
  OnViewDetailsEntry(binding: binding),
  OnSelectWidgetAtPointEntry(binding: binding),
  OnInspectWidgetAtPointEntry(),
  ...getInteractionToolkitEntries(),
};

/// Extension on [MCPToolkitBinding] to initialize the Flutter MCP Toolkit.
extension MCPToolkitBindingExtension on MCPToolkitBinding {
  /// Initializes the Flutter MCP Toolkit.
  void initializeFlutterToolkit() => unawaited(
    addEntries(entries: getFlutterMcpToolkitEntries(binding: this)),
  );
}

/// {@template on_app_errors_entry}
/// AgentCallEntry wrapper for app errors.
/// {@endtemplate}
extension type OnAppErrorsEntry._(AgentCallEntry entry) implements AgentCallEntry {
  /// {@macro on_app_errors_entry}
  factory OnAppErrorsEntry({required final ErrorMonitor errorMonitor}) {
    final entry = mcpToolkitTool(
      handler: (final parameters) {
        final count = jsonDecodeInt(parameters['count'] ?? '').whenZeroUse(4);
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
        inputSchema: ObjectSchema.fromMap(getAppErrorsInputSchema()),
      ),
    );
    return OnAppErrorsEntry._(entry);
  }
}

/// {@template on_view_screenshots_entry}
/// AgentCallEntry wrapper for view screenshots.
/// {@endtemplate}
extension type OnViewScreenshotsEntry._(AgentCallEntry entry)
    implements AgentCallEntry {
  /// {@macro on_view_screenshots_entry}
  factory OnViewScreenshotsEntry({required final MCPToolkitBinding binding}) {
    final entry = mcpToolkitTool(
      handler: (final parameters) async {
        final compress = jsonDecodeBool(parameters['compress']);
        final images = await ScreenshotService.takeScreenshots(
          compress: compress,
        );
        final captureHints = binding.captureHintsContributor?.call();
        return MCPCallResult(
          message:
              'Screenshots taken for each view. '
              'If you find visual errors, you can try to request errors '
              'to get more information with stack trace',
          parameters: {'images': images, 'captureHints': ?captureHints},
        );
      },
      definition: MCPToolDefinition(
        name: 'view_screenshots',
        description:
            'Take screenshots of all Flutter views/screens. '
            'Useful for visual debugging and UI analysis.',
        inputSchema: ObjectSchema.fromMap(getScreenshotsInputSchema()),
      ),
    );
    return OnViewScreenshotsEntry._(entry);
  }
}

/// {@template on_view_details_entry}
/// AgentCallEntry wrapper for view details.
/// {@endtemplate}
extension type const OnViewDetailsEntry._(AgentCallEntry entry)
    implements AgentCallEntry {
  /// {@macro on_view_details_entry}
  factory OnViewDetailsEntry({required final MCPToolkitBinding binding}) {
    final entry = mcpToolkitTool(
      handler: (final parameters) {
        final payload = ViewIntrospectionService.buildViewDetailsPayload(
          captureHintsContributor: binding.captureHintsContributor,
        );
        return MCPCallResult(
          message: 'Detailed information for Flutter views and widget tree.',
          parameters: payload,
        );
      },
      definition: MCPToolDefinition(
        name: 'view_details',
        description:
            'Get detailed information about Flutter views and widgets. '
            'Returns structural information about the current UI state.',
        inputSchema: ObjectSchema.fromMap(getViewDetailsInputSchema()),
      ),
    );
    return OnViewDetailsEntry._(entry);
  }
}

/// {@template on_inspect_widget_at_point_entry}
/// AgentCallEntry wrapper for inspecting widget details at global coordinates.
/// {@endtemplate}
extension type const OnInspectWidgetAtPointEntry._(AgentCallEntry entry)
    implements AgentCallEntry {
  /// {@macro on_inspect_widget_at_point_entry}
  factory OnInspectWidgetAtPointEntry() {
    final entry = mcpToolkitTool(
      handler: (final parameters) {
        final x = jsonDecodeInt(parameters['x']).whenZeroUse(0);
        final y = jsonDecodeInt(parameters['y']).whenZeroUse(0);
        final viewId = jsonDecodeInt(parameters['viewId']);
        final payload = ViewIntrospectionService.inspectWidgetAtPoint(
          x: x,
          y: y,
          viewId: viewId == 0 ? null : viewId,
        );

        return MCPCallResult(
          message: 'Widget inspection at point completed.',
          parameters: payload,
        );
      },
      definition: MCPToolDefinition(
        name: 'inspect_widget_at_point',
        description:
            'Inspect deepest widget/render node at global logical coordinates.',
        inputSchema: ObjectSchema.fromMap(inspectWidgetAtPointInputSchema()),
      ),
    );
    return OnInspectWidgetAtPointEntry._(entry);
  }
}

/// MCP tool entry that delegates to [MCPToolkitBinding.selectAtPointHandler]
/// when set, otherwise inspects the widget at (x, y).
extension type const OnSelectWidgetAtPointEntry._(AgentCallEntry entry)
    implements AgentCallEntry {
  /// Creates the select-at-point tool backed by [binding].
  factory OnSelectWidgetAtPointEntry({
    required final MCPToolkitBinding binding,
  }) {
    final entry = mcpToolkitTool(
      handler: (final parameters) {
        final customHandler = binding.selectAtPointHandler;
        if (customHandler != null) {
          return customHandler(parameters);
        }
        final x = jsonDecodeInt(parameters['x']).whenZeroUse(0);
        final y = jsonDecodeInt(parameters['y']).whenZeroUse(0);
        final viewId = jsonDecodeInt(parameters['viewId']);
        final payload = ViewIntrospectionService.inspectWidgetAtPoint(
          x: x,
          y: y,
          viewId: viewId == 0 ? null : viewId,
        );

        return MCPCallResult(
          message: 'Widget inspection at point completed.',
          parameters: payload,
        );
      },
      definition: MCPToolDefinition(
        name: selectWidgetAtPointToolName,
        description:
            'Inspect or select a widget at global logical coordinates. '
            'When live-edit is active, this selects a live-edit node; '
            'otherwise it falls back to widget inspection.',
        inputSchema: ObjectSchema.fromMap(selectWidgetAtPointInputSchema()),
      ),
    );
    return OnSelectWidgetAtPointEntry._(entry);
  }
}
