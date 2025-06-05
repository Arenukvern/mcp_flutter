// ignore_for_file: prefer_asserts_with_message

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'mcp_models.dart';
import 'mcp_toolkit_binding_base.dart';
import 'mcp_toolkit_extensions.dart';
import 'services/error_monitor.dart';

/// Add a single MCP tool to the MCP toolkit.
///
/// This is a shortcut for [MCPToolkitBinding.addEntries] method.
///
/// Should be called only after [MCPToolkitBinding.initialize] is called.
void addMcpTool(final MCPCallEntry entry) =>
    unawaited(MCPToolkitBinding.instance.addEntries(entries: {entry}));

/// The binding for the MCP Toolkit.
///
/// Run init, before calling [addEntries].
///
/// To add Flutter tools, call [initializeFlutterToolkit] method.
///
/// Usually, you may use the following setup:
///
/// ```dart
/// import 'package:flutter/material.dart';
/// import 'package:mcp_toolkit/mcp_toolkit.dart'; // Import the package
/// import 'dart:async';
///
/// Future<void> main() async {
///   runZonedGuarded(
///     () async {
///       WidgetsFlutterBinding.ensureInitialized();
///       MCPToolkitBinding.instance
///         ..initialize() // Initializes the Toolkit
///         ..initializeFlutterToolkit(); // Adds Flutter related methods to the MCP server
///       runApp(const MyApp());
///     },
///     (error, stack) {
///       // Optionally, you can also use the bridge's error handling for zone errors
///       MCPToolkitBinding.instance.handleZoneError(error, stack);
///     },
///   );
/// }
/// ```
class MCPToolkitBinding extends MCPToolkitBindingBase
    with ErrorMonitor, MCPToolkitExtensions {
  MCPToolkitBinding._();

  /// The singleton instance of the MCP Toolkit binding.
  static final instance = MCPToolkitBinding._();

  @override
  void initialize({
    final String serviceExtensionName = kMCPServiceExtensionName,
    final int maxErrors = kDefaultMaxErrors,
  }) {
    assert(() {
      assert(
        kDebugMode,
        'MCP Toolkit should only be initialized in debug mode',
      );
      attachToFlutterError();
      return true;
    }());

    super.initialize(serviceExtensionName: serviceExtensionName);
  }

  /// Initializes the MCP Toolkit binding.
  ///
  /// Registers service extensions that can be called by the MCP server
  /// through the Dart VM service.
  Future<void> addEntries({required final Set<MCPCallEntry> entries}) async {
    assert(() {
      initializeServiceExtensions(errorMonitor: this, entries: entries);
      return true;
    }());
  }

  /// Get all accumulated entries across all addEntries calls
  @override
  Set<MCPCallEntry> get allEntries => super.allEntries;
}
