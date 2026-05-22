// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/base_server.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/handlers/resource_handler.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/mixins/vm_service_support.dart';

/// Mix this in to any MCPServer to back the Flutter Inspector resource
/// surface (`visual://localhost/...`). All MCP **tools** are published by
/// `flutter_mcp_toolkit_capability_core` via the capability kernel — this mixin no longer
/// registers any tool. It exists solely to keep the resource registrations
/// alive until the kernel grows resource publication.
base mixin FlutterInspector
    on BaseMCPToolkitServer, ToolsSupport, ResourcesSupport, VMServiceSupport {
  late final _resourceHandler = ResourceHandler(
    server: this,
    executor: coreCommandExecutor,
  );

  @override
  FutureOr<InitializeResult> initialize(final InitializeRequest request) {
    log(
      LoggingLevel.info,
      'Initializing Flutter Inspector resources',
      logger: 'FlutterInspector',
    );

    if (configuration.resourcesSupported) {
      log(
        LoggingLevel.debug,
        'Registering Flutter resources',
        logger: 'FlutterInspector',
      );
      _registerResources();
    } else {
      log(
        LoggingLevel.debug,
        'Resources disabled by configuration',
        logger: 'FlutterInspector',
      );
    }

    log(
      LoggingLevel.info,
      'Flutter Inspector initialization completed',
      logger: 'FlutterInspector',
    );
    return super.initialize(request);
  }

  /// Register the `visual://localhost/...` resource surface.
  void _registerResources() {
    final latestAppErrorSrc = Resource(
      uri: 'visual://localhost/app/errors/latest',
      name: 'Latest Application Error',
      mimeType: 'application/json',
      description: 'Get the most recent application error from Dart VM',
    );
    addResource(
      latestAppErrorSrc,
      (final request) =>
          _resourceHandler.handleAppErrorsResource(request, count: 1),
    );

    final appErrorsResource = ResourceTemplate(
      uriTemplate: 'visual://localhost/app/errors/{count}',
      name: 'Application Errors',
      mimeType: 'application/json',
      description:
          'Get a specified number of latest application errors from Dart VM. '
          'Limit to 4 or fewer for performance.',
    );
    addResourceTemplate(
      appErrorsResource,
      _resourceHandler.handleAppErrorsResource,
    );

    if (configuration.imagesSupported) {
      final screenshotsResource = Resource(
        uri: 'visual://localhost/view/screenshots',
        name: 'Screenshots',
        mimeType: 'image/png',
        description:
            'Get screenshots of all views in the application. '
            'Returns base64 encoded images.',
      );
      addResource(
        screenshotsResource,
        _resourceHandler.handleScreenshotsResource,
      );
    }

    final viewDetailsResource = Resource(
      uri: 'visual://localhost/view/details',
      name: 'View Details',
      mimeType: 'application/json',
      description: 'Get details for all views in the application.',
    );
    addResource(
      viewDetailsResource,
      _resourceHandler.handleViewDetailsResource,
    );
  }

  Future<void> dispose() async {
    await _resourceHandler.dispose();
  }
}
