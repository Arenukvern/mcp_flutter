// mcp_capability_core/lib/src/tools/wait_tools.dart
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:mcp_shared_core/mcp_shared_core.dart';

import '_internal/handler_helpers.dart';

/// Registers the [wait_for] tool with the host through [context].
///
/// `wait_for` delegates entirely to [WaitForCommand]. All outcome
/// discrimination (matched / timeout / error) happens inside the executor's
/// `_waitFor` + `routeWaitForResponse` pair — the capability layer sees a
/// standard CoreResult and applies the same `runCommand` path as every other
/// tool.
void registerWaitTools(final CapabilityContext context) {
  final runner = context.require<CommandRunner>();

  context.registerTool(
    ToolRegistration(
      name: 'wait_for',
      description:
          'Wait for a UI predicate (text/noText/time/stable) and return a '
          'fresh semantic snapshot. Replaces sleep+snapshot polling. '
          'Default timeout 5000 ms, max 30000 ms.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'required': <String>['predicate'],
        'properties': <String, Object?>{
          'predicate': <String, Object?>{
            'type': 'object',
            'additionalProperties': true,
            'description':
                'Predicate map. Shapes: '
                '{kind:"time", ms:int} | '
                '{kind:"text", text:String} | '
                '{kind:"noText", text:String} | '
                '{kind:"stable", stableWindowMs:int}',
          },
          'timeoutMs': <String, Object?>{
            'type': 'integer',
            'description': 'Timeout in ms (default 5000, max 30000).',
          },
          'connection': connectionOverrideJsonSchema(),
        },
      },
      handler: (final request) async {
        final args = request.arguments ?? const <String, Object?>{};
        final predicateRaw = args['predicate'];
        final predicate = predicateRaw is Map
            ? Map<String, Object?>.from(predicateRaw)
            : const <String, Object?>{};
        final timeoutMsRaw = intArgOrNull(args['timeoutMs']);
        return runCommand(
          runner,
          args,
          WaitForCommand(
            predicate: predicate,
            timeoutMs: timeoutMsRaw ?? 5000,
          ),
        );
      },
    ),
  );
}
