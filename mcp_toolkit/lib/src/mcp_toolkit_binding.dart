// ignore_for_file: prefer_asserts_with_message

import 'dart:async';

import 'package:agentkit_core/agentkit_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'agent_call_entry_extensions.dart';
import 'mcp_models.dart';
import 'mcp_toolkit_binding_base.dart';
import 'mcp_toolkit_extensions.dart';
import 'services/error_monitor.dart';
import 'services/log_capture_service.dart';
import 'services/platform_view_hints.dart';
import 'services/semantic_snapshot_service.dart';
import 'toolkits/flutter_mcp_toolkit.dart';

/// Add a single MCP tool to the MCP toolkit.
///
/// This is a shortcut for [MCPToolkitBinding.addEntries] method.
///
/// Should be called only after [MCPToolkitBinding.initialize] is called.
void addMcpTool(final AgentCallEntry entry) =>
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

  /// Optional override for hybrid / GPU apps without platform-view widgets.
  ///
  /// Return hints with [PlatformViewHints.platformViewsDetected] true when
  /// `flutter_layer` screenshots omit pixels (WGPU, Metal, Vulkan, etc.).
  PlatformViewHints Function()? captureHintsContributor;

  /// Custom handler used by select-at-point flows when the app wants to
  /// override the default widget selection behavior.
  MCPCallHandler? get selectAtPointHandler => _selectAtPointHandler;

  /// Registers a custom select-at-point handler.
  set selectAtPointHandler(final MCPCallHandler handler) {
    _selectAtPointHandler = handler;
  }

  /// Root [NavigatorState] key from `MaterialApp.navigatorKey` /
  /// `WidgetsApp.navigatorKey`, or `null` when not registered.
  ///
  /// Tools such as `handle_dialog` and `navigate` read this; when `null` they
  /// return `navigator_not_registered`.
  GlobalKey<NavigatorState>? navigatorKey;

  /// Canonical app bootstrap for Flutter hosts using MCP toolkit in debug.
  Future<void> bootstrapFlutter({
    required final FutureOr<void> Function() runApp,
    final Iterable<AgentCallEntry> additionalEntries = const <AgentCallEntry>[],
    final FutureOr<void> Function()? ensureInitialized,
    final void Function(Object error, StackTrace stackTrace)? onZoneError,
    final bool initializeFlutterToolkitEntries = true,
    final bool debugOnly = true,
  }) async {
    final completer = Completer<void>();
    final zoneErrorHandler = onZoneError ?? handleZoneError;

    unawaited(
      runZonedGuarded(
        () async {
          try {
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
              await _addMissingEntries(
                getFlutterMcpToolkitEntries(binding: this),
              );
            }
            if (additionalEntries.isNotEmpty) {
              await _addMissingEntries(additionalEntries);
            }

            await runApp();
          } finally {
            if (!completer.isCompleted) {
              completer.complete();
            }
          }
        },
        (final error, final stackTrace) {
          if (!completer.isCompleted) {
            completer.complete();
          }
          zoneErrorHandler(error, stackTrace);
        },
      ),
    );

    await completer.future;
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
      LogCaptureService.install();
      SemanticSnapshotService.primeSemanticsTree();
      return true;
    }());

    super.initialize(serviceExtensionName: serviceExtensionName);
  }

  /// Initializes the MCP Toolkit binding.
  ///
  /// Registers service extensions that can be called by the MCP server
  /// through the Dart VM service.
  Future<void> addEntries({required final Set<AgentCallEntry> entries}) async {
    assert(() {
      initializeServiceExtensions(errorMonitor: this, entries: entries);
      return true;
    }());
  }

  Future<void> _addMissingEntries(final Iterable<AgentCallEntry> entries) {
    final existingKeys =
        allEntries.map((final entry) => entry.serviceExtensionName).toSet();
    final missingEntries = entries
        .where((final entry) => !existingKeys.contains(entry.serviceExtensionName))
        .toSet();
    if (missingEntries.isEmpty) {
      return Future<void>.value();
    }
    return addEntries(entries: missingEntries);
  }

  /// Get all accumulated entries across all addEntries calls
  @override
  Set<AgentCallEntry> get allEntries => super.allEntries;
}
