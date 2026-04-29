// mcp_capability_core/lib/src/tools/form_tools.dart
import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:mcp_shared_core/mcp_shared_core.dart';

import '_internal/handler_helpers.dart';

/// Registers the [fill_form] tool with the host through [context].
///
/// `fill_form` delegates entirely to [FillFormCommand]. The per-field looping
/// and stop-on-first-failure semantics live inside the executor's `_fillForm`
/// method — the capability layer sees a single CoreResult and applies the same
/// `runCommand` path as every other tool.
void registerFormTools(final CapabilityContext context) {
  final runner = context.require<CommandRunner>();

  context.registerTool(
    ToolRegistration(
      name: 'fill_form',
      description:
          'Batch text entry: enters text into multiple fields in one call. '
          'Stops on first failure. Each field: {ref, text}. Pass snapshotId '
          'to validate against the most recent semantic_snapshot (checked '
          'on the first field only).',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'required': <String>['fields'],
        'properties': <String, Object?>{
          'fields': <String, Object?>{
            'type': 'array',
            'items': <String, Object?>{
              'type': 'object',
              'additionalProperties': false,
              'required': <String>['ref', 'text'],
              'properties': <String, Object?>{
                'ref': <String, Object?>{'type': 'string'},
                'text': <String, Object?>{'type': 'string'},
              },
            },
          },
          'snapshotId': <String, Object?>{'type': 'integer'},
          'connection': connectionOverrideJsonSchema(),
        },
      },
      handler: (final request) async {
        final args = request.arguments ?? const <String, Object?>{};
        final fieldsRaw = args['fields'];
        final fields = fieldsRaw is List
            ? fieldsRaw
                .map<Map<String, Object?>>((final e) {
                  if (e is Map<String, Object?>) return e;
                  if (e is Map) return e.cast<String, Object?>();
                  return const <String, Object?>{};
                })
                .toList(growable: false)
            : const <Map<String, Object?>>[];
        final snapshotId = intArgOrNull(args['snapshotId']);
        return runCommand(
          runner,
          args,
          FillFormCommand(fields: fields, snapshotId: snapshotId),
        );
      },
    ),
  );
}
