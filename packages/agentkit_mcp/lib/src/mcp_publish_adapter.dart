import 'dart:async';

import 'package:agentkit_core/agentkit_core.dart';
import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';

import 'agent_bridge.dart';
import 'mcp_result_mapper.dart';

typedef McpToolPublisher =
    void Function(
      Tool tool,
      FutureOr<CallToolResult> Function(CallToolRequest request) impl,
    );

typedef McpToolUnpublisher = void Function(String name);

/// Publishes registry-backed tools to dart_mcp [ToolsSupport].
final class McpPublishAdapter {
  McpPublishAdapter({required this.publish, required this.unpublish});

  final McpToolPublisher publish;
  final McpToolUnpublisher unpublish;
  final Set<String> _published = <String>{};

  void publishCapabilityTool({
    required final AgentRegistry registry,
    required final String capabilityId,
    required final ToolRegistration registration,
    required final String fullName,
  }) {
    registry.register(
      toolRegistrationToRegistration(
        capabilityId: capabilityId,
        registration: registration,
      ),
      qualifiedNameOverride: fullName,
    );
    publish(
      Tool(
        name: fullName,
        description: registration.description,
        inputSchema: ObjectSchema.fromMap(registration.inputSchema),
      ),
      (final request) async => agentResultToMcpResult(
        await registry.invoke(
          fullName,
          request.arguments ?? const <String, Object?>{},
        ),
      ),
    );
    _published.add(fullName);
  }

  void unpublishTool({
    required final AgentRegistry registry,
    required final String fullName,
  }) {
    registry.unregister(fullName);
    if (_published.remove(fullName)) {
      unpublish(fullName);
    }
  }

  void unpublishAll({required final AgentRegistry registry}) {
    for (final name in _published.toList()) {
      unpublishTool(registry: registry, fullName: name);
    }
  }
}
