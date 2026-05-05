// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:flutter_mcp_toolkit_server/src/shared_core/commands/commands.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/types/results.dart';

typedef CoreExecuteFn = Future<CoreResult> Function(CoreCommand command);

final class DiagnosticsBundler {
  DiagnosticsBundler({required this.execute});

  final CoreExecuteFn execute;

  Future<Map<String, Object?>> run({
    final bool includeViewDetails = false,
  }) async {
    final steps = <Map<String, Object?>>[];

    Future<void> runStep(final String name, final CoreCommand command) async {
      final result = await execute(command);
      steps.add({
        'name': name,
        'ok': result.ok,
        'data': result.data,
        'error': result.error?.toJson(),
        'meta': result.meta,
      });
    }

    await runStep('status', const StatusCommand());
    await runStep('get_vm', const GetVmCommand());
    await runStep('get_extension_rpcs', const GetExtensionRpcsCommand());
    await runStep('dynamicRegistryStats', const DynamicRegistryStatsCommand());
    await runStep('get_app_errors', const GetAppErrorsCommand());

    if (includeViewDetails) {
      await runStep('get_view_details', const GetViewDetailsCommand());
    }

    final failures = steps.where((final e) => e['ok'] != true).length;

    return {
      'steps': steps,
      'summary': {
        'total': steps.length,
        'success': steps.length - failures,
        'failed': failures,
        'includeViewDetails': includeViewDetails,
      },
    };
  }
}
