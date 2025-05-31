// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: avoid_catches_without_on_clauses, lines_longer_than_80_chars

import 'dart:async';
import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/base_server.dart';
import 'package:flutter_inspector_mcp_server/src/mixins/port_scanner.dart';
import 'package:flutter_inspector_mcp_server/src/mixins/vm_service_support.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:is_dart_empty_or_not/is_dart_empty_or_not.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

/// Mix this in to any MCPServer to add Flutter Inspector functionality.
base mixin FlutterInspector
    on
        BaseMCPToolkitServer,
        PortScanner,
        ToolsSupport,
        ResourcesSupport,
        VMServiceSupport {
  @override
  FutureOr<InitializeResult> initialize(final InitializeRequest request) {
    log(
      LoggingLevel.info,
      'Initializing Flutter Inspector tools and resources',
      logger: 'FlutterInspector',
    );

    // Register core tools
    log(
      LoggingLevel.debug,
      'Registering core Flutter tools',
      logger: 'FlutterInspector',
    );
    registerTool(hotReloadTool, _hotReload);
    registerTool(getVmTool, _getVm);
    registerTool(getExtensionRpcsTool, _getExtensionRpcs);
    registerTool(getActivePortsTool, _getActivePorts);

    // Register debug dump tools
    if (configuration.dumpsSupported) {
      log(
        LoggingLevel.debug,
        'Registering debug dump tools',
        logger: 'FlutterInspector',
      );
      registerTool(debugDumpLayerTreeTool, _debugDumpLayerTree);
      registerTool(debugDumpSemanticsTreeTool, _debugDumpSemanticsTree);
      registerTool(debugDumpRenderTreeTool, _debugDumpRenderTree);
      registerTool(debugDumpFocusTreeTool, _debugDumpFocusTree);
    } else {
      log(
        LoggingLevel.debug,
        'Debug dump tools disabled by configuration',
        logger: 'FlutterInspector',
      );
    }

    // Smart registration: Resources OR Tools (not both)
    if (configuration.resourcesSupported) {
      log(
        LoggingLevel.debug,
        'Registering Flutter resources',
        logger: 'FlutterInspector',
      );
      // Register as resources (existing behavior)
      _registerResources();
    } else {
      log(
        LoggingLevel.debug,
        'Registering Flutter functionality as tools (resources disabled)',
        logger: 'FlutterInspector',
      );
      // Register as tools instead
      _registerResourcesAsTools();
    }

    log(
      LoggingLevel.info,
      'Flutter Inspector initialization completed',
      logger: 'FlutterInspector',
    );
    return super.initialize(request);
  }

  /// Register resources for widget tree, screenshots, and app errors.
  void _registerResources() {
    log(
      LoggingLevel.debug,
      'Setting up Flutter Inspector resources',
      logger: 'FlutterInspector',
    );

    // App errors resource
    final latestAppErrorSrc = Resource(
      uri: 'visual://localhost/app/errors/latest',
      name: 'Latest Application Error',
      mimeType: 'application/json',
      description: 'Get the most recent application error from Dart VM',
    );
    addResource(latestAppErrorSrc, _handleAppLatestErrorResource);
    log(
      LoggingLevel.debug,
      'Registered latest app error resource',
      logger: 'FlutterInspector',
    );

    // App errors resource
    final appErrorsResource = ResourceTemplate(
      uriTemplate: 'visual://localhost/app/errors/{count}',
      name: 'Application Errors',
      mimeType: 'application/json',
      description:
          'Get a specified number of latest application errors from Dart VM. Limit to 4 or fewer for performance.',
    );
    addResourceTemplate(appErrorsResource, _handleAppErrorsResource);
    log(
      LoggingLevel.debug,
      'Registered app errors resource template',
      logger: 'FlutterInspector',
    );

    // Screenshots resource (if images supported)
    if (configuration.imagesSupported) {
      final screenshotsResource = Resource(
        uri: 'visual://localhost/view/screenshots',
        name: 'Screenshots',
        mimeType: 'image/png',
        description:
            'Get screenshots of all views in the application. Returns base64 encoded images.',
      );
      addResource(screenshotsResource, _handleScreenshotsResource);
      log(
        LoggingLevel.debug,
        'Registered screenshots resource',
        logger: 'FlutterInspector',
      );
    } else {
      log(
        LoggingLevel.debug,
        'Screenshots resource disabled (images not supported)',
        logger: 'FlutterInspector',
      );
    }

    // View details resource
    final viewDetailsResource = Resource(
      uri: 'visual://localhost/view/details',
      name: 'View Details',
      mimeType: 'application/json',
      description: 'Get details for all views in the application.',
    );
    addResource(viewDetailsResource, _handleViewDetailsResource);
    log(
      LoggingLevel.debug,
      'Registered view details resource',
      logger: 'FlutterInspector',
    );
  }

  /// Hot reload the Flutter application.
  Future<CallToolResult> _hotReload(final CallToolRequest request) async {
    log(
      LoggingLevel.info,
      'Executing hot reload tool',
      logger: 'FlutterInspector',
    );

    final connected = await ensureVMServiceConnected();
    if (!connected) {
      log(
        LoggingLevel.error,
        'Hot reload tool failed: VM service not connected',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'VM service not connected')],
      );
    }
    try {
      final force = jsonDecodeBool(request.arguments?['force']);
      log(
        LoggingLevel.debug,
        'Hot reload force parameter: $force',
        logger: 'FlutterInspector',
      );

      final result = await hotReload(force: force);

      log(
        LoggingLevel.info,
        'Hot reload tool completed successfully',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        content: [
          TextContent(text: 'Hot reload completed'),
          TextContent(text: jsonEncode(result)),
        ],
      );
    } on Exception catch (e) {
      log(
        LoggingLevel.error,
        'Hot reload tool failed: $e',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Hot reload failed: $e')],
      );
    }
  }

  /// Get VM information.
  Future<CallToolResult> _getVm(final CallToolRequest request) async {
    log(LoggingLevel.info, 'Executing get VM tool', logger: 'FlutterInspector');

    final connected = await ensureVMServiceConnected();
    if (!connected) {
      log(
        LoggingLevel.error,
        'Get VM tool failed: VM service not connected',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'VM service not connected')],
      );
    }
    try {
      final vm = await vmService!.getVM();

      log(
        LoggingLevel.info,
        'Get VM tool completed successfully',
        logger: 'FlutterInspector',
      );
      log(
        LoggingLevel.debug,
        () => 'VM info: ${vm.name} v${vm.version}',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        content: [TextContent(text: jsonEncode(vm.toJson()))],
      );
    } on Exception catch (e, s) {
      log(
        LoggingLevel.error,
        'Get VM tool failed: $e\nStack trace: $s',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Failed to get VM info: $e')],
      );
    }
  }

  /// Get available extension RPCs.
  Future<CallToolResult> _getExtensionRpcs(
    final CallToolRequest request,
  ) async {
    log(
      LoggingLevel.info,
      'Executing get extension RPCs tool',
      logger: 'FlutterInspector',
    );

    final connected = await ensureVMServiceConnected();
    if (!connected) {
      log(
        LoggingLevel.error,
        'Get extension RPCs tool failed: VM service not connected',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'VM service not connected')],
      );
    }
    try {
      final vm = await vmService!.getVM();
      final allExtensions = <String>[];

      log(
        LoggingLevel.debug,
        'Scanning ${vm.isolates?.length ?? 0} isolates for extensions',
        logger: 'FlutterInspector',
      );
      for (final isolateRef in vm.isolates ?? <IsolateRef>[]) {
        final isolate = await vmService!.getIsolate(isolateRef.id!);
        if (isolate.extensionRPCs != null) {
          allExtensions.addAll(isolate.extensionRPCs!);
          log(
            LoggingLevel.debug,
            'Found ${isolate.extensionRPCs!.length} extensions in isolate ${isolateRef.id}',
            logger: 'FlutterInspector',
          );
        }
      }

      final uniqueExtensions = allExtensions.toSet().toList();
      log(
        LoggingLevel.info,
        'Get extension RPCs tool completed: found ${uniqueExtensions.length} unique extensions',
        logger: 'FlutterInspector',
      );
      log(
        LoggingLevel.debug,
        () => 'Extensions: $uniqueExtensions',
        logger: 'FlutterInspector',
      );

      return CallToolResult(
        content: [TextContent(text: jsonEncode(uniqueExtensions))],
      );
    } on Exception catch (e, s) {
      log(
        LoggingLevel.error,
        'Get extension RPCs tool failed: $e\nStack trace: $s',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Failed to get extension RPCs: $e')],
      );
    }
  }

  Future<ReadResourceResult> _handleAppLatestErrorResource(
    final ReadResourceRequest request,
  ) {
    log(
      LoggingLevel.debug,
      'Handling latest app error resource request',
      logger: 'FlutterInspector',
    );
    return _handleAppErrorsResource(request, count: 1);
  }

  /// Handle app errors resource request.
  Future<ReadResourceResult> _handleAppErrorsResource(
    final ReadResourceRequest request, {
    final int count = 4,
  }) async {
    log(
      LoggingLevel.info,
      'Handling app errors resource request (count: $count)',
      logger: 'FlutterInspector',
    );

    try {
      final parsedCount = Uri.parse(request.uri).pathSegments.last;
      final requestedCount = jsonDecodeInt(parsedCount).whenZeroUse(count);
      log(
        LoggingLevel.debug,
        'Requesting $requestedCount app errors',
        logger: 'FlutterInspector',
      );

      final result = await callFlutterExtension(
        'ext.mcp.toolkit.app_errors',
        args: {'count': requestedCount},
      );
      final json = result.json;
      if (json == null) {
        log(
          LoggingLevel.warning,
          'App errors extension returned null',
          logger: 'FlutterInspector',
        );
        return ReadResourceResult(
          contents: [
            TextResourceContents(uri: request.uri, text: 'No errors found'),
          ],
        );
      }
      final errors = jsonDecodeListAs<Map<String, dynamic>>(json['errors']);
      final message = jsonDecodeString(
        json['message'],
      ).whenEmptyUse('No errors found');

      log(
        LoggingLevel.info,
        'App errors resource completed: found ${errors.length} errors',
        logger: 'FlutterInspector',
      );

      if (errors.isEmpty) {
        return ReadResourceResult(
          contents: [TextResourceContents(uri: request.uri, text: message)],
        );
      }

      return ReadResourceResult(
        contents: [
          TextResourceContents(uri: request.uri, text: message),
          ...errors.map(
            (final error) => TextResourceContents(
              uri: request.uri,
              text: jsonEncode(error),
              mimeType: 'application/json',
            ),
          ),
        ],
      );
    } on Exception catch (e) {
      log(
        LoggingLevel.error,
        'App errors resource failed: $e',
        logger: 'FlutterInspector',
      );
      return ReadResourceResult(
        contents: [
          TextResourceContents(
            uri: request.uri,
            text: 'Failed to get app errors: $e',
          ),
        ],
      );
    }
  }

  /// Handle screenshots resource request.
  Future<ReadResourceResult> _handleScreenshotsResource(
    final ReadResourceRequest request,
  ) async {
    log(
      LoggingLevel.info,
      'Handling screenshots resource request',
      logger: 'FlutterInspector',
    );

    try {
      final result = await callFlutterExtension(
        'ext.mcp.toolkit.view_screenshots',
        args: {'compress': true},
      );

      final images = jsonDecodeListAs<String>(result.json?['images']);
      log(
        LoggingLevel.info,
        'Screenshots resource completed: captured ${images.length} screenshots',
        logger: 'FlutterInspector',
      );

      return ReadResourceResult(
        contents:
            images
                .map(
                  (final image) => BlobResourceContents(
                    uri: request.uri,
                    blob: image,
                    mimeType: 'image/png',
                  ),
                )
                .toList(),
      );
    } on Exception catch (e) {
      log(
        LoggingLevel.error,
        'Screenshots resource failed: $e',
        logger: 'FlutterInspector',
      );
      return ReadResourceResult(
        contents: [
          TextResourceContents(
            uri: request.uri,
            text: 'Failed to get screenshots: $e',
          ),
        ],
      );
    }
  }

  /// Handle view details resource request.
  Future<ReadResourceResult> _handleViewDetailsResource(
    final ReadResourceRequest request,
  ) async {
    log(
      LoggingLevel.info,
      'Handling view details resource request',
      logger: 'FlutterInspector',
    );

    try {
      final result = await callFlutterExtension(
        'ext.mcp.toolkit.view_details',
        args: {},
      );

      final details = jsonDecodeListAs<Map<String, dynamic>>(
        result.json?['details'],
      );
      final message = jsonDecodeString(
        result.json?['message'],
      ).whenEmptyUse('View details');

      log(
        LoggingLevel.info,
        'View details resource completed: found ${details.length} views',
        logger: 'FlutterInspector',
      );

      return ReadResourceResult(
        contents: [
          TextResourceContents(uri: request.uri, text: message),
          ...details.map(
            (final detail) => TextResourceContents(
              uri: request.uri,
              text: jsonEncode(detail),
              mimeType: 'application/json',
            ),
          ),
        ],
      );
    } on Exception catch (e, s) {
      log(
        LoggingLevel.error,
        'View details resource failed: $e\nStack trace: $s',
        logger: 'FlutterInspector',
      );
      return ReadResourceResult(
        contents: [
          TextResourceContents(
            uri: request.uri,
            text: 'Failed to get view details: $e',
          ),
        ],
      );
    }
  }

  // Tool definitions
  @visibleForTesting
  static final hotReloadTool = Tool(
    name: 'hot_reload_flutter',
    description: 'Hot reloads the Flutter app.',
    inputSchema: Schema.object(
      properties: {
        'port': Schema.int(
          description:
              'Optional: Custom port number if not using default Flutter debug port 8181',
        ),
        'force': Schema.bool(
          description:
              'If true, forces a hot reload even if there are no changes to the source code',
        ),
      },
    ),
  );

  @visibleForTesting
  static final getVmTool = Tool(
    name: 'get_vm',
    description:
        'Utility: Get VM information from a Flutter app. This is a VM service method, not a Flutter RPC.',
    inputSchema: Schema.object(
      properties: {
        'port': Schema.int(
          description:
              'Optional: Custom port number if not using default Flutter debug port 8181',
        ),
      },
    ),
  );

  @visibleForTesting
  static final getExtensionRpcsTool = Tool(
    name: 'get_extension_rpcs',
    description:
        'Utility: List all available extension RPCs in the Flutter app.',
    inputSchema: Schema.object(
      properties: {
        'port': Schema.int(
          description:
              'Optional: Custom port number if not using default Flutter debug port 8181',
        ),
        'isolateId': Schema.string(
          description:
              'Optional specific isolate ID to check. If not provided, checks all isolates',
        ),
        'isRawResponse': Schema.bool(
          description:
              'If true, returns the raw response from the VM service without processing',
        ),
      },
    ),
  );

  @visibleForTesting
  static final debugDumpLayerTreeTool = Tool(
    name: 'debug_dump_layer_tree',
    description: 'Dumps the layer tree of the Flutter app.',
    inputSchema: Schema.object(
      properties: {
        'port': Schema.int(
          description:
              'Optional: Custom port number if not using default Flutter debug port 8181',
        ),
      },
    ),
  );

  @visibleForTesting
  static final debugDumpSemanticsTreeTool = Tool(
    name: 'debug_dump_semantics_tree',
    description: 'Dumps the semantics tree of the Flutter app.',
    inputSchema: Schema.object(
      properties: {
        'port': Schema.int(
          description:
              'Optional: Custom port number if not using default Flutter debug port 8181',
        ),
      },
    ),
  );

  @visibleForTesting
  static final debugDumpRenderTreeTool = Tool(
    name: 'debug_dump_render_tree',
    description: 'Dumps the render tree of the Flutter app.',
    inputSchema: Schema.object(
      properties: {
        'port': Schema.int(
          description:
              'Optional: Custom port number if not using default Flutter debug port 8181',
        ),
      },
    ),
  );

  @visibleForTesting
  static final debugDumpFocusTreeTool = Tool(
    name: 'debug_dump_focus_tree',
    description: 'Dumps the focus tree of the Flutter app.',
    inputSchema: Schema.object(
      properties: {
        'port': Schema.int(
          description:
              'Optional: Custom port number if not using default Flutter debug port 8181',
        ),
      },
    ),
  );

  @visibleForTesting
  static final getActivePortsTool = Tool(
    name: 'get_active_ports',
    description: 'Gets the active ports of the Flutter app.',
    inputSchema: Schema.object(
      properties: {
        'port': Schema.int(
          description:
              'Optional: Custom port number if not using default Flutter debug port 8181',
        ),
      },
    ),
  );

  @visibleForTesting
  static final getAppErrorsTool = Tool(
    name: 'get_app_errors',
    description: 'Get the most recent application errors from Dart VM',
    inputSchema: Schema.object(
      properties: {
        'count': Schema.int(
          description: 'Number of recent errors to retrieve (default: 4)',
        ),
      },
    ),
  );

  @visibleForTesting
  static final getScreenshotsTool = Tool(
    name: 'get_screenshots',
    description: 'Get screenshots of all views in the application',
    inputSchema: Schema.object(
      properties: {
        'compress': Schema.bool(
          description: 'Whether to compress the images (default: true)',
        ),
      },
    ),
  );

  @visibleForTesting
  static final getViewDetailsTool = Tool(
    name: 'get_view_details',
    description: 'Get details for all views in the application',
    inputSchema: Schema.object(properties: {}),
  );

  /// Debug dump layer tree.
  Future<CallToolResult> _debugDumpLayerTree(
    final CallToolRequest request,
  ) async {
    log(
      LoggingLevel.info,
      'Executing debug dump layer tree tool',
      logger: 'FlutterInspector',
    );

    final connected = await ensureVMServiceConnected();
    if (!connected) {
      log(
        LoggingLevel.error,
        'Debug dump layer tree failed: VM service not connected',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'VM service not connected')],
      );
    }

    try {
      final result = await callFlutterExtension(
        'ext.flutter.debugDumpLayerTree',
        args: {},
      );
      log(
        LoggingLevel.info,
        'Debug dump layer tree completed successfully',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        content: [TextContent(text: jsonEncode(result.json))],
      );
    } on Exception catch (e) {
      log(
        LoggingLevel.error,
        'Debug dump layer tree failed: $e',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Debug dump layer tree failed: $e')],
      );
    }
  }

  /// Debug dump semantics tree.
  Future<CallToolResult> _debugDumpSemanticsTree(
    final CallToolRequest request,
  ) async {
    log(
      LoggingLevel.info,
      'Executing debug dump semantics tree tool',
      logger: 'FlutterInspector',
    );

    final connected = await ensureVMServiceConnected();
    if (!connected) {
      log(
        LoggingLevel.error,
        'Debug dump semantics tree failed: VM service not connected',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'VM service not connected')],
      );
    }

    try {
      final result = await callFlutterExtension(
        'ext.flutter.debugDumpSemanticsTreeInTraversalOrder',
      );
      log(
        LoggingLevel.info,
        'Debug dump semantics tree completed successfully',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        content: [TextContent(text: jsonEncode(result.json))],
      );
    } on Exception catch (e) {
      log(
        LoggingLevel.error,
        'Debug dump semantics tree failed: $e',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Debug dump semantics tree failed: $e')],
      );
    }
  }

  /// Debug dump render tree.
  Future<CallToolResult> _debugDumpRenderTree(
    final CallToolRequest request,
  ) async {
    log(
      LoggingLevel.info,
      'Executing debug dump render tree tool',
      logger: 'FlutterInspector',
    );

    final connected = await ensureVMServiceConnected();
    if (!connected) {
      log(
        LoggingLevel.error,
        'Debug dump render tree failed: VM service not connected',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'VM service not connected')],
      );
    }

    try {
      final result = await callFlutterExtension(
        'ext.flutter.debugDumpRenderTree',
      );
      log(
        LoggingLevel.info,
        'Debug dump render tree completed successfully',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        content: [TextContent(text: jsonEncode(result.json))],
      );
    } on Exception catch (e, s) {
      log(
        LoggingLevel.error,
        'Debug dump render tree failed: $e\nStack trace: $s',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Debug dump render tree failed: $e')],
      );
    }
  }

  /// Debug dump focus tree.
  Future<CallToolResult> _debugDumpFocusTree(
    final CallToolRequest request,
  ) async {
    log(
      LoggingLevel.info,
      'Executing debug dump focus tree tool',
      logger: 'FlutterInspector',
    );

    final connected = await ensureVMServiceConnected();
    if (!connected) {
      log(
        LoggingLevel.error,
        'Debug dump focus tree failed: VM service not connected',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'VM service not connected')],
      );
    }

    try {
      final result = await callFlutterExtension(
        'ext.flutter.debugDumpFocusTree',
        args: {},
      );
      log(
        LoggingLevel.info,
        'Debug dump focus tree completed successfully',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        content: [TextContent(text: jsonEncode(result.json))],
      );
    } on Exception catch (e) {
      log(
        LoggingLevel.error,
        'Debug dump focus tree failed: $e',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Debug dump focus tree failed: $e')],
      );
    }
  }

  /// Get active ports.
  Future<CallToolResult> _getActivePorts(final CallToolRequest request) async {
    log(
      LoggingLevel.info,
      'Executing get active ports tool',
      logger: 'FlutterInspector',
    );

    try {
      // Use the new PortScanner class
      final ports = await scanForFlutterPorts();
      log(
        LoggingLevel.info,
        'Get active ports completed: found ${ports.length} ports',
        logger: 'FlutterInspector',
      );
      log(
        LoggingLevel.debug,
        () => 'Active ports: $ports',
        logger: 'FlutterInspector',
      );
      return CallToolResult(content: [TextContent(text: jsonEncode(ports))]);
    } on Exception catch (e) {
      log(
        LoggingLevel.error,
        'Get active ports failed: $e',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Failed to get active ports: $e')],
      );
    }
  }

  /// Register resource functionality as tools when resources not supported
  void _registerResourcesAsTools() {
    log(
      LoggingLevel.debug,
      'Setting up Flutter Inspector tools (resource mode disabled)',
      logger: 'FlutterInspector',
    );

    // Always register app errors tool
    registerTool(getAppErrorsTool, _getAppErrors);
    log(
      LoggingLevel.debug,
      'Registered app errors tool',
      logger: 'FlutterInspector',
    );

    // Register screenshots tool if images supported
    if (configuration.imagesSupported) {
      registerTool(getScreenshotsTool, _getScreenshots);
      log(
        LoggingLevel.debug,
        'Registered screenshots tool',
        logger: 'FlutterInspector',
      );
    } else {
      log(
        LoggingLevel.debug,
        'Screenshots tool disabled (images not supported)',
        logger: 'FlutterInspector',
      );
    }

    // Always register view details tool
    registerTool(getViewDetailsTool, _getViewDetails);
    log(
      LoggingLevel.debug,
      'Registered view details tool',
      logger: 'FlutterInspector',
    );
  }

  /// Get app errors as tool.
  Future<CallToolResult> _getAppErrors(final CallToolRequest request) async {
    log(
      LoggingLevel.info,
      'Executing get app errors tool',
      logger: 'FlutterInspector',
    );

    final connected = await ensureVMServiceConnected();
    if (!connected) {
      log(
        LoggingLevel.error,
        'Get app errors tool failed: VM service not connected',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'VM service not connected')],
      );
    }

    try {
      final count = jsonDecodeInt(request.arguments?['count']).whenZeroUse(4);
      log(
        LoggingLevel.debug,
        'Requesting $count app errors',
        logger: 'FlutterInspector',
      );

      final result = await callFlutterExtension(
        'ext.mcp.toolkit.app_errors',
        args: {'count': count},
      );

      final errors = jsonDecodeListAs<Map<String, dynamic>>(
        result.json?['errors'],
      );
      final message = jsonDecodeString(
        result.json?['message'],
      ).whenEmptyUse('No errors found');

      log(
        LoggingLevel.info,
        'Get app errors tool completed: found ${errors.length} errors',
        logger: 'FlutterInspector',
      );

      return CallToolResult(
        content: [
          TextContent(text: message),
          ...errors.map((final error) => TextContent(text: jsonEncode(error))),
        ],
      );
    } on Exception catch (e) {
      log(
        LoggingLevel.error,
        'Get app errors tool failed: $e',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Failed to get app errors: $e')],
      );
    }
  }

  /// Get screenshots as tool.
  Future<CallToolResult> _getScreenshots(final CallToolRequest request) async {
    log(
      LoggingLevel.info,
      'Executing get screenshots tool',
      logger: 'FlutterInspector',
    );

    final connected = await ensureVMServiceConnected();
    if (!connected) {
      log(
        LoggingLevel.error,
        'Get screenshots tool failed: VM service not connected',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'VM service not connected')],
      );
    }

    try {
      final compress =
          bool.tryParse('${request.arguments?['compress']}') ?? true;
      log(
        LoggingLevel.debug,
        'Screenshots compression: $compress',
        logger: 'FlutterInspector',
      );

      final result = await callFlutterExtension(
        'ext.mcp.toolkit.view_screenshots',
        args: {'compress': compress},
      );

      final images = jsonDecodeListAs<String>(result.json?['images']);
      log(
        LoggingLevel.info,
        'Get screenshots tool completed: captured ${images.length} screenshots',
        logger: 'FlutterInspector',
      );

      return CallToolResult(
        content: [
          ...images.map(
            (final image) => ImageContent(data: image, mimeType: 'image/png'),
          ),
        ],
      );
    } on Exception catch (e) {
      log(
        LoggingLevel.error,
        'Get screenshots tool failed: $e',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Failed to get screenshots: $e')],
      );
    }
  }

  /// Get view details as tool.
  Future<CallToolResult> _getViewDetails(final CallToolRequest request) async {
    log(
      LoggingLevel.info,
      'Executing get view details tool',
      logger: 'FlutterInspector',
    );

    final connected = await ensureVMServiceConnected();
    if (!connected) {
      log(
        LoggingLevel.error,
        'Get view details tool failed: VM service not connected',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'VM service not connected')],
      );
    }

    try {
      final result = await callFlutterExtension('ext.mcp.toolkit.view_details');
      final details = jsonDecodeListAs<Map<String, dynamic>>(
        result.json?['details'],
      );
      final message = jsonDecodeString(
        result.json?['message'],
      ).whenEmptyUse('View details');

      log(
        LoggingLevel.info,
        'Get view details tool completed: found ${details.length} views',
        logger: 'FlutterInspector',
      );

      return CallToolResult(
        content: [
          TextContent(text: message),
          ...details.map(
            (final detail) => TextContent(text: jsonEncode(detail)),
          ),
        ],
      );
    } on Exception catch (e) {
      log(
        LoggingLevel.error,
        'Get view details tool failed: $e',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Failed to get view details: $e')],
      );
    }
  }
}
