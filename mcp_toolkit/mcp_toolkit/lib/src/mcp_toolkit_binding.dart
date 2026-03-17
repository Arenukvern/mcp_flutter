// ignore_for_file: prefer_asserts_with_message

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'mcp_models.dart';
import 'mcp_toolkit_binding_base.dart';
import 'mcp_toolkit_extensions.dart';
import 'services/error_monitor.dart';
import 'toolkits/flutter_mcp_toolkit.dart';

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

  MCPCallHandler? _selectAtPointHandler;

  MCPCallHandler? get selectAtPointHandler => _selectAtPointHandler;

  void setSelectAtPointHandler(final MCPCallHandler handler) {
    _selectAtPointHandler = handler;
  }

  /// Canonical app bootstrap for Flutter hosts using MCP toolkit in debug.
  Future<void> bootstrapFlutter({
    required final FutureOr<void> Function() runApp,
    final Iterable<MCPCallEntry> additionalEntries = const <MCPCallEntry>[],
    final FutureOr<void> Function()? ensureInitialized,
    final void Function(Object error, StackTrace stackTrace)? onZoneError,
    final bool initializeFlutterToolkitEntries = true,
    final bool debugOnly = true,
  }) async {
    await runZonedGuarded(
      () async {
        if (debugOnly && kReleaseMode) {
          await runApp();
          return;
        }

        await (ensureInitialized?.call() ??
            Future<void>.sync(WidgetsFlutterBinding.ensureInitialized));

        if (!isInitialized) {
          initialize();
        }

        if (initializeFlutterToolkitEntries) {
          await _addMissingEntries(getFlutterMcpToolkitEntries(binding: this));
        }
        if (additionalEntries.isNotEmpty) {
          await _addMissingEntries(additionalEntries);
        }

        await runApp();
      },
      onZoneError ?? handleZoneError,
    );
  }

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

  Future<void> _addMissingEntries(final Iterable<MCPCallEntry> entries) {
    final existingKeys = allEntries.map((final entry) => entry.key).toSet();
    final missingEntries = entries
        .where((final entry) => !existingKeys.contains(entry.key))
        .toSet();
    if (missingEntries.isEmpty) {
      return Future<void>.value();
    }
    return addEntries(entries: missingEntries);
  }

  /// Get all accumulated entries across all addEntries calls
  @override
  Set<MCPCallEntry> get allEntries => super.allEntries;
}
