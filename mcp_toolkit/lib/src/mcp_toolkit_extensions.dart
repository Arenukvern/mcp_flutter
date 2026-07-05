// ignore_for_file: prefer_asserts_with_message, lines_longer_than_80_chars

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_platform/intentcall_platform.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

import 'agent_call_entry_extensions.dart';
import 'agent_entry_helpers.dart';
import 'mcp_toolkit_binding_base.dart';
import 'services/error_monitor.dart';

/// A mixin that adds MCP Toolkit extensions to a binding.
mixin MCPToolkitExtensions on MCPToolkitBindingBase {
  var _debugServiceExtensionsRegistered = false;
  final _registeredEntryKeys = <String>{};

  /// Accumulated entries from all addEntries calls
  final _allEntries = <AgentCallEntry>{};

  /// Get all accumulated entries (read-only)
  Set<AgentCallEntry> get allEntries => Set.unmodifiable(_allEntries);

  /// Called when the binding is initialized, to register service
  /// extensions.
  ///
  /// Bindings that want to expose service extensions should overload
  /// this method to register them using calls to
  /// [registerSignalServiceExtension],
  /// [registerBoolServiceExtension],
  /// [registerNumericServiceExtension], and
  /// [registerServiceExtension] (in increasing order of complexity).
  ///
  /// Implementations of this method must call their superclass
  /// implementation.
  ///
  /// {@macro flutter.foundation.BindingBase.registerServiceExtension}
  ///
  /// See also:
  ///
  ///  * <https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/service.md#rpcs-requests-and-responses>
  @protected
  @mustCallSuper
  void initializeServiceExtensions({
    required final ErrorMonitor errorMonitor,
    required final Set<AgentCallEntry> entries,
  }) {
    if (kReleaseMode) {
      throw UnsupportedError(
        'MCP Toolkit entries should only be added in debug mode',
      );
    }

    // Dynamic registration is a debug/profile VM-service surface; release apps
    // should not depend on these service extensions being present.
    assert(() {
      final allEntries = {..._allEntries, ...entries};
      final uniqueEntries = <AgentCallEntry>{};
      for (final entry in allEntries) {
        if (!uniqueEntries.any((final e) => e.key == entry.key)) {
          uniqueEntries.add(entry);
        }
      }
      _allEntries
        ..clear()
        ..addAll(uniqueEntries);

      if (kIsWeb) {
        registerAgentWebMcpFromEntries(_allEntries);
      }

      for (final entry in entries) {
        final extensionName = entry.serviceExtensionName;
        if (!_registeredEntryKeys.add(extensionName)) {
          continue;
        }
        registerServiceExtension(
          name: extensionName,
          callback: (final parameters) async {
            final wireArgs = mcpToolkitArgumentsFromServiceExtensionParameters(
              parameters,
            );
            final registration = entry.toRegistration();
            final args = coerceArgumentsForSchema(
              registration.descriptor.inputSchema,
              wireArgs,
            );
            registration.validate(args);
            final result = await entry.value.handler(args);
            return agentResultToServiceExtensionMap(result);
          },
        );
      }

      if (!_debugServiceExtensionsRegistered) {
        registerServiceExtension(
          name: 'registerDynamics',
          callback: (final parameters) async => _handleRegisterDynamics(),
        );
      }

      return true;
    }());
    assert(() {
      _debugServiceExtensionsRegistered = true;
      return true;
    }());

    _postToolRegistrationEvent(entries);
  }

  @visibleForTesting
  Map<String, Object?> mcpToolkitArgumentsFromServiceExtensionParameters(
    final Map<String, String> parameters,
  ) => parameters.map(MapEntry<String, Object?>.new)..remove('isolateId');

  /// Posts the debug-only DTD event consumed by Flutter MCP dynamic discovery.
  void _postToolRegistrationEvent(final Set<AgentCallEntry> newEntries) {
    if (newEntries.isEmpty) return;

    final toolNames = newEntries
        .where((final entry) => entry.hasTool)
        .map((final entry) => entry.serviceExtensionName)
        .toList();

    final resourceUris = newEntries
        .where((final entry) => entry.hasResource)
        .map((final entry) => entry.resourceUri)
        .toList();

    developer.postEvent('MCPToolkit.ToolRegistration', {
      'kind': 'ToolRegistration',
      'timestamp': DateTime.now().toIso8601String(),
      'toolCount': toolNames.length,
      'resourceCount': resourceUris.length,
      'toolNames': toolNames,
      'resourceUris': resourceUris,
      'appId': _getAppId(),
      'totalEntries': _allEntries.length,
    });

    for (final toolName in toolNames) {
      developer.postEvent('MCPToolkit.ServiceExtensionStateChanged', {
        'kind': 'ServiceExtensionStateChanged',
        'extension': '$mcpServiceExtensionName.$toolName',
        'value': 'registered',
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    if (kDebugMode) {
      debugPrint(
        '[MCPToolkit] Posted tool registration events: ${toolNames.length} tools, ${resourceUris.length} resources',
      );
    }
  }

  String _getAppId() => 'flutter_app_${DateTime.now().millisecondsSinceEpoch}';

  Map<String, dynamic> _handleRegisterDynamics() {
    final tools = <Map<String, dynamic>>[];
    final resources = <Map<String, dynamic>>[];

    for (final entry in _allEntries) {
      final descriptor = entry.toRegistration().descriptor;
      if (entry.hasTool) {
        tools.add({
          'name': descriptor.effectiveMethodName,
          'description': descriptor.description,
          'inputSchema': descriptor.inputSchema,
        });
        continue;
      }

      if (entry.hasResource) {
        resources.add({
          'name': descriptor.name,
          'description': descriptor.description,
          'mimeType': descriptor.mimeType ?? 'application/json',
          'uri': descriptor.effectiveResourceUri,
          'inputSchema': descriptor.inputSchema,
        });
        continue;
      }

      tools.add({
        'name': descriptor.effectiveMethodName,
        'description': 'Flutter app tool: ${descriptor.name}',
        'inputSchema': descriptor.inputSchema,
      });
    }

    return {
      'tools': tools,
      'resources': resources,
      'appId': _getAppId(),
      'registeredAt': DateTime.now().toIso8601String(),
      'totalEntries': _allEntries.length,
    };
  }
}
