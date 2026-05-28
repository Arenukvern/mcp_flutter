// packages/server_capability_core/lib/src/tools/navigation_tools.dart
// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';

import '_internal/handler_helpers.dart';

/// Registers navigator tools with the host through [context].
/// Registers: handle_dialog, navigate.
void registerNavigationTools(final CapabilityContext context) {
  final runner = context.require<CommandRunner>();

  context.registerTool(
    ToolRegistration(
      name: 'handle_dialog',
      description:
          'Dismiss the topmost popup/dialog route on the registered Navigator. '
          'Currently only action="dismiss" is supported. '
          'Requires MCPToolkitBinding.instance.navigatorKey = key on the app.',
      inputSchema: handleDialogInputSchema(),
      handler: (final args) async {
        final action = stringArgOrNull(args['action']) ?? 'dismiss';
        return runCommand(runner, args, HandleDialogCommand(action: action));
      },
    ),
  );

  context.registerTool(
    ToolRegistration(
      name: 'navigate',
      description:
          'Drive the registered Navigator: action=push|pop|popUntil. '
          'push and popUntil require route. push accepts arguments map. '
          'Requires MCPToolkitBinding.instance.navigatorKey = key on the app.',
      inputSchema: navigateInputSchema(),
      handler: (final args) async {
        final action = stringArgOrNull(args['action']) ?? 'push';
        final route = stringArgOrNull(args['route']);
        final argsMapRaw = args['arguments'];
        final arguments = argsMapRaw is Map
            ? Map<String, Object?>.from(argsMapRaw)
            : null;
        return runCommand(
          runner,
          args,
          NavigateCommand(
            action: action,
            route: route,
            arguments: arguments == null || arguments.isEmpty
                ? null
                : arguments,
          ),
        );
      },
    ),
  );
}
