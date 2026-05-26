import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_schema/agentkit_schema.dart';

/// Compares registry invoke result data to an expected map (subset).
void expectAgentData(
  final AgentResult result,
  final Map<String, Object?> expected,
) {
  if (!result.ok) {
    throw StateError('Expected success, got ${result.code}: ${result.message}');
  }
  for (final entry in expected.entries) {
    if (result.data[entry.key] != entry.value) {
      throw StateError(
        'data[${entry.key}] expected ${entry.value}, got ${result.data[entry.key]}',
      );
    }
  }
}

Future<AgentResult> invokeRegistry(
  final AgentRegistry registry,
  final String qualifiedName,
  final AgentArguments arguments,
) => registry.invoke(qualifiedName, arguments);
