// ignore_for_file: invalid_use_of_protected_member, lines_longer_than_80_chars

import 'package:flutter/foundation.dart' show ServiceExtensionCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

final class _RecordingProjection implements ToolkitProjection {
  final List<Set<AgentCallEntry>> received = <Set<AgentCallEntry>>[];

  @override
  void entriesChanged(final Set<AgentCallEntry> entries) {
    received.add(Set<AgentCallEntry>.of(entries));
  }
}

final class _ProjectionToolkitBinding extends MCPToolkitBindingBase
    with MCPToolkitExtensions {
  @override
  void registerServiceExtension({
    required final String name,
    required final ServiceExtensionCallback callback,
  }) {}
}

final class _TestErrorMonitor with ErrorMonitor {}

void main() {
  test('registered projections receive the full entry set on change', () {
    final binding = _ProjectionToolkitBinding()..initialize();
    final projection = _RecordingProjection();
    binding.addProjection(projection);

    final entry = mcpToolkitTool(
      namespace: 'app',
      definition: MCPToolDefinition(
        name: 'inspect_number',
        description: 'Inspect a number',
        inputSchema: ObjectSchema(
          properties: {'x': IntegerSchema()},
        ),
      ),
      handler: (final request) => Future<MCPCallResult>.value(
        MCPCallResult(message: 'inspected', parameters: {'ok': true}),
      ),
    );
    binding.initializeServiceExtensions(
      errorMonitor: _TestErrorMonitor(),
      entries: {entry},
    );

    expect(projection.received, hasLength(1));
    expect(projection.received.single, contains(entry));
  });

  test('core has no implicit projections', () {
    final binding = _ProjectionToolkitBinding()..initialize();
    expect(binding.projections, isEmpty);
  });
}
