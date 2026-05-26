import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';

/// Registers `fmt_migrate_agent_entries` (report-only; `apply: true` writes files).
void registerMigrateAgentEntriesTool(final CapabilityContext context) {
  context.registerTool(
    ToolRegistration(
      name: 'migrate_agent_entries',
      description:
          'Scan Dart sources for legacy MCPCallEntry and return a migration report. '
          'Set apply=true to rewrite files in place (host filesystem paths only).',
      inputSchema: const <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'properties': <String, Object?>{
          'projectRoot': <String, Object?>{
            'type': 'string',
            'description': 'Flutter/Dart project root or single .dart file path.',
          },
          'apply': <String, Object?>{
            'type': 'boolean',
            'description': 'When true, apply migrations. Default false (report-only).',
          },
          'namespace': <String, Object?>{
            'type': 'string',
            'description': 'Default AgentCallEntry namespace (default: app).',
          },
        },
        'required': <String>['projectRoot'],
      },
      handler: (final args) async {
        final root = args['projectRoot']?.toString().trim();
        if (root == null || root.isEmpty) {
          return AgentResult.failure(
            code: 'invalid_argument',
            message: 'projectRoot is required',
          );
        }
        final apply = args['apply'] == true;
        final namespace = args['namespace']?.toString() ?? 'app';

        try {
          final report = await migrateAgentEntriesAtPath(
            path: root,
            write: apply,
            checkOnly: false,
            defaultNamespace: namespace,
          );
          return AgentResult.success(
            message: apply
                ? 'Migration applied where needed.'
                : 'Migration report (report-only).',
            data: <String, Object?>{
              'filesScanned': report.filesScanned,
              'filesChanged': report.filesChanged,
              'apply': apply,
              'files': report.results
                  .map(
                    (final r) => <String, Object?>{
                      'path': r.path,
                      'changed': r.changed,
                    },
                  )
                  .toList(),
            },
          );
        } on MigrateAgentEntriesPathNotFound catch (error) {
          return AgentResult.failure(
            code: 'path_not_found',
            message: error.toString(),
          );
        }
      },
    ),
  );
}
