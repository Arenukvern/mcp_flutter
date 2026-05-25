// packages/server_capability_kernel/lib/src/tool_registration.dart
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:meta/meta.dart';

/// Handler for a capability tool — transport-agnostic [AgentResult].
typedef ToolHandler = Future<AgentResult> Function(AgentArguments arguments);

/// A tool the capability wants the host to expose.
///
/// [name] is the bare name (without prefix). The host applies the
/// `<capabilityId>_` prefix when publishing to MCP clients.
@immutable
final class ToolRegistration {
  const ToolRegistration({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.handler,
  });

  final String name;
  final String description;
  final Map<String, Object?> inputSchema;
  final ToolHandler handler;
}
