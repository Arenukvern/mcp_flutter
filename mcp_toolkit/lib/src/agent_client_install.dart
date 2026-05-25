import 'package:flutter/foundation.dart';

import 'mcp_models.dart';
import 'mcp_toolkit_binding.dart';

/// Idempotent lazy registration for app-defined MCP entries.
final class AgentClientInstall {
  AgentClientInstall._();

  static var _done = false;

  static Future<void> once({
    required final Future<Set<MCPCallEntry>> Function() buildEntries,
    final Future<void> Function({required Set<MCPCallEntry> entries})? register,
  }) async {
    if (kReleaseMode || _done) {
      return;
    }
    _done = true;
    try {
      final entries = await buildEntries();
      final registerFn = register ?? MCPToolkitBinding.instance.addEntries;
      await registerFn(entries: entries);
    } on Object {
      _done = false;
      rethrow;
    }
  }

  @visibleForTesting
  static void resetForTest() => _done = false;
}
