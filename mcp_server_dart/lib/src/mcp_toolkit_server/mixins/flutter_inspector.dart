// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:async';

import 'package:agentkit_mcp/agentkit_mcp.dart';
import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/base_server.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/handlers/resource_handler.dart'
    as inspector_resources;
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/mixins/vm_service_support.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/server.dart';

/// Mix this in to any MCPServer to back the Flutter Inspector resource
/// surface (`visual://localhost/...`). All MCP **tools** are published by
/// `flutter_mcp_toolkit_capability_core` via the capability kernel — this mixin no longer
/// registers any tool. It exists solely to keep the resource registrations
/// alive until the kernel grows resource publication.
base mixin FlutterInspector
    on BaseMCPToolkitServer, ToolsSupport, ResourcesSupport, VMServiceSupport {
  late final _resourceHandler = inspector_resources.ResourceHandler(
    server: this,
    executor: coreCommandExecutor,
  );

  MCPToolkitServer get _toolkitServer => this as MCPToolkitServer;

  @override
  FutureOr<InitializeResult> initialize(final InitializeRequest request) async {
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
      await _registerResources();
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

  /// Register the `visual://localhost/...` resource surface via [AgentRegistry].
  Future<void> _registerResources() async {
    await _registerRegistryResource(
      resource: Resource(
        uri: 'visual://localhost/app/errors/latest',
        name: 'latest_application_error',
        mimeType: 'application/json',
        description: 'Get the most recent application error from Dart VM',
      ),
      read: (final request) =>
          _resourceHandler.handleAppErrorsResource(request, count: 1),
    );

    await _registerRegistryResourceTemplate(
      template: ResourceTemplate(
        uriTemplate: 'visual://localhost/app/errors/{count}',
        name: 'application_errors',
        mimeType: 'application/json',
        description:
            'Get a specified number of latest application errors from Dart VM. '
            'Limit to 4 or fewer for performance.',
      ),
      read: _resourceHandler.handleAppErrorsResource,
    );

    if (configuration.imagesSupported) {
      await _registerRegistryResource(
        resource: Resource(
          uri: 'visual://localhost/view/screenshots',
          name: 'screenshots',
          mimeType: 'image/png',
          description:
              'Get screenshots of all views in the application. '
              'Returns base64 encoded images.',
        ),
        read: _resourceHandler.handleScreenshotsResource,
      );
    }

    await _registerRegistryResource(
      resource: Resource(
        uri: 'visual://localhost/view/details',
        name: 'view_details',
        mimeType: 'application/json',
        description: 'Get details for all views in the application.',
      ),
      read: _resourceHandler.handleViewDetailsResource,
    );
  }

  Future<void> _registerRegistryResource({
    required final Resource resource,
    required final Future<ReadResourceResult> Function(ReadResourceRequest request)
    read,
  }) async {
    await _toolkitServer.capabilityHost.registerPublishedResource(
      capabilityId: 'visual',
      registration: ResourceRegistration(
        uri: resource.uri,
        name: resource.name,
        description: resource.description ?? '',
        mimeType: resource.mimeType ?? 'application/json',
        handler: (final uri) async => readResourceResultToAgentResult(
          await read(ReadResourceRequest(uri: uri)),
        ),
      ),
    );
  }

  Future<void> _registerRegistryResourceTemplate({
    required final ResourceTemplate template,
    required final Future<ReadResourceResult> Function(ReadResourceRequest request)
    read,
  }) async {
    await _toolkitServer.capabilityHost.registerPublishedResourceTemplate(
      capabilityId: 'visual',
      registration: ResourceTemplateRegistration(
        uriTemplate: template.uriTemplate,
        name: template.name,
        description: template.description ?? '',
        mimeType: template.mimeType ?? 'application/json',
        handler: (final uri) async => readResourceResultToAgentResult(
          await read(ReadResourceRequest(uri: uri)),
        ),
      ),
    );
  }

  Future<void> dispose() async {
    await _resourceHandler.dispose();
  }
}
