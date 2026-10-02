// ignore_for_file: prefer_asserts_with_message, lines_longer_than_80_chars

import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'package:intentcall_core/intentcall_core.dart';
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

  var _agentInvokeSurfaceRegistered = false;

  /// Exposes the agent-call registry to the `invoke` tier (ADR-0017):
  /// `agent_catalog` lists tool entries as descriptors, `agent_invoke`
  /// dispatches one by registry name with JSON-encoded arguments.
  ///
  /// The registry is the single action source — the invoke tier READS it
  /// instead of growing a second one, so one registration reaches every
  /// surface (MCP tools, projections, harness drivers). The verbs are
  /// registered once and read [_allEntries] live: entries added later are
  /// catalogued without re-registration. Debug/profile only — release
  /// apps have no VM service to serve it on.
  void exposeAgentInvokeSurface() {
    if (kReleaseMode) {
      throw UnsupportedError(
        'The agent invoke surface should only be exposed in debug mode',
      );
    }
    if (_agentInvokeSurfaceRegistered) return;
    _agentInvokeSurfaceRegistered = true;
    registerServiceExtension(
      name: ToolkitExtensionNames.agentCatalog,
      callback: (final parameters) async => <String, Object?>{
        'success': true,
        'actions': <Object?>[
          for (final entry in _allEntries.where(
            (final candidate) => candidate.hasTool,
          ))
            <String, Object?>{
              'name': entry.name,
              'namespace': entry.value.namespace,
              'description': entry.value.description,
              'inputSchema': entry.value.inputSchema,
            },
        ],
      },
    );
    registerServiceExtension(
      name: ToolkitExtensionNames.agentInvoke,
      callback: (final parameters) async {
        final name = parameters['name'] ?? '';
        AgentCallEntry? entry;
        for (final candidate in _allEntries) {
          if (candidate.hasTool && candidate.name == name) {
            entry = candidate;
            break;
          }
        }
        if (entry == null) {
          return <String, Object?>{
            'success': false,
            'error': 'unknown registry action: $name',
          };
        }
        final raw = parameters['json'];
        final args = raw == null || raw.isEmpty
            ? const <String, Object?>{}
            : Map<String, Object?>.from(jsonDecode(raw) as Map);
        final registration = entry.toRegistration();
        registration.validate(args);
        final result = await entry.value.handler(args);
        return agentResultToServiceExtensionMap(result);
      },
    );
  }
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

      for (final projection in projections) {
        projection.entriesChanged(_allEntries);
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

      // The invoke tier reads the registry live, so exposing it once
      // here catalogues every entry — current and future (ADR-0017).
      exposeAgentInvokeSurface();

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
        .map((final entry) => entry.resolveResourceUri(protocolScheme))
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
          'uri': entry.resolveResourceUri(protocolScheme),
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
