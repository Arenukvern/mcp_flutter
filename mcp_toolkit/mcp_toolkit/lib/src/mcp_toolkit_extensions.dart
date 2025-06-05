// ignore_for_file: prefer_asserts_with_message, lines_longer_than_80_chars

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'mcp_models.dart';
import 'mcp_toolkit_binding_base.dart';
import 'services/error_monitor.dart';

/// A mixin that adds MCP Toolkit extensions to a binding.
mixin MCPToolkitExtensions on MCPToolkitBindingBase {
  var _debugServiceExtensionsRegistered = false;

  /// Accumulated entries from all addEntries calls
  final _allEntries = <MCPCallEntry>{};

  /// Get all accumulated entries (read-only)
  Set<MCPCallEntry> get allEntries => Set.unmodifiable(_allEntries);

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
    required final Set<MCPCallEntry> entries,
  }) {
    if (kReleaseMode) {
      throw UnsupportedError(
        'MCP Toolkit entries should only be added in debug mode',
      );
    }

    // Accumulate entries from this call
    _allEntries.addAll(entries);

    assert(() {
      // Register individual service extensions for each entry in this batch
      for (final entry in entries) {
        registerServiceExtension(
          name: entry.key,
          callback: (final parameters) async => entry.value.handler(parameters),
        );
      }

      // Register the registerDynamics service extension only once
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

    // Post event to notify MCP server about new tool registrations
    _postToolRegistrationEvent(entries);
  }

  /// Post an event to the Dart VM when new tools are registered
  /// This allows the MCP server to detect tool changes in real-time via DTD
  void _postToolRegistrationEvent(final Set<MCPCallEntry> newEntries) {
    if (newEntries.isEmpty) return;

    final toolNames =
        newEntries
            .where((final entry) => entry.hasTool)
            .map((final entry) => entry.key.toString())
            .toList();

    final resourceUris =
        newEntries
            .where((final entry) => entry.hasResource)
            .map((final entry) => entry.resourceUri)
            .toList();

    // Post event to Dart VM for DTD/MCP server consumption
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

    // Also post individual events for immediate responsiveness
    for (final toolName in toolNames) {
      developer.postEvent('MCPToolkit.ServiceExtensionStateChanged', {
        'kind': 'ServiceExtensionStateChanged',
        'extension': 'ext.mcp.toolkit.$toolName',
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

  /// Get a unique app identifier for this Flutter app
  // Use a combination of process identifier and timestamp for uniqueness
  String _getAppId() => 'flutter_app_${DateTime.now().millisecondsSinceEpoch}';

  /// Handles the registerDynamics service extension call
  /// Returns all accumulated tools and resources in the format expected by the MCP server
  Map<String, dynamic> _handleRegisterDynamics() {
    final tools = <Map<String, dynamic>>[];
    final resources = <Map<String, dynamic>>[];

    // Use all accumulated entries, not just the latest batch
    for (final entry in _allEntries) {
      // Add tool definitions
      if (entry.hasTool) {
        tools.add(Map<String, dynamic>.from(entry.value.toolDefinition!));
      } else {
        // Create a default tool definition for entries without one
        tools.add({
          'name': entry.key,
          'description': 'Flutter app tool: ${entry.key}',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'parameters': {
                'type': 'object',
                'description': 'Parameters for the tool call',
              },
            },
          },
        });
      }

      // Add resource definitions
      if (entry.hasResource) {
        resources.add({
          ...entry.value.resourceDefinition!,
          'uri': entry.resourceUri,
        });
      }
    }

    return {
      'tools': tools,
      'resources': resources,
      'appId': 'flutter_app_${DateTime.now().millisecondsSinceEpoch}',
      'registeredAt': DateTime.now().toIso8601String(),
      'totalEntries': _allEntries.length,
    };
  }
}
