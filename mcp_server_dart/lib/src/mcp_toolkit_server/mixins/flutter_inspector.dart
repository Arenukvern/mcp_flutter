// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: avoid_catches_without_on_clauses, lines_longer_than_80_chars

import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/mcp_toolkit_server/base_server.dart';
import 'package:flutter_inspector_mcp_server/src/mcp_toolkit_server/handlers/debug_tools_handler.dart';
import 'package:flutter_inspector_mcp_server/src/mcp_toolkit_server/handlers/interaction_handler.dart';
import 'package:flutter_inspector_mcp_server/src/mcp_toolkit_server/handlers/live_edit_handler.dart';
import 'package:flutter_inspector_mcp_server/src/mcp_toolkit_server/handlers/resource_handler.dart';
import 'package:flutter_inspector_mcp_server/src/mcp_toolkit_server/handlers/vm_tools_handler.dart';
import 'package:flutter_inspector_mcp_server/src/mcp_toolkit_server/mixins/vm_service_support.dart';

/// Mix this in to any MCPServer to add Flutter Inspector functionality.
base mixin FlutterInspector
    on BaseMCPToolkitServer, ToolsSupport, ResourcesSupport, VMServiceSupport {
  late final _debugTools = DebugToolsHandler(
    server: this,
    executor: coreCommandExecutor,
  );
  late final _vmTools = VMToolsHandler(
    server: this,
    executor: coreCommandExecutor,
  );
  late final _resourceHandler = ResourceHandler(
    server: this,
    executor: coreCommandExecutor,
  );
  late final _liveEditHandler = LiveEditHandler(
    server: this,
    executor: coreCommandExecutor,
  );
  late final _interactionHandler = InteractionHandler(
    server: this,
    executor: coreCommandExecutor,
  );

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
    registerTool(VMToolsHandler.connectDebugAppTool, _vmTools.connectDebugApp);
    registerTool(VMToolsHandler.hotReloadTool, _vmTools.hotReload);
    registerTool(VMToolsHandler.hotRestartTool, _vmTools.hotRestart);
    registerTool(VMToolsHandler.getVmTool, _vmTools.getVm);
    registerTool(
      VMToolsHandler.getExtensionRpcsTool,
      _vmTools.getExtensionRpcs,
    );
    registerTool(
      VMToolsHandler.discoverDebugAppsTool,
      _vmTools.discoverDebugApps,
    );
    registerTool(
      ResourceHandler.inspectWidgetAtPointTool,
      _resourceHandler.inspectWidgetAtPoint,
    );
    registerTool(
      ResourceHandler.captureUiSnapshotTool,
      _resourceHandler.captureUiSnapshot,
    );

    // Register interaction tools
    registerTool(
      InteractionHandler.semanticSnapshotTool,
      _interactionHandler.semanticSnapshot,
    );
    registerTool(
      InteractionHandler.tapWidgetTool,
      _interactionHandler.tapWidget,
    );
    registerTool(
      InteractionHandler.enterTextTool,
      _interactionHandler.enterText,
    );
    registerTool(InteractionHandler.scrollTool, _interactionHandler.scroll);
    registerTool(
      InteractionHandler.longPressTool,
      _interactionHandler.longPress,
    );
    registerTool(InteractionHandler.swipeTool, _interactionHandler.swipe);
    registerTool(InteractionHandler.dragTool, _interactionHandler.drag);
    registerTool(
      InteractionHandler.hotReloadAndCaptureTool,
      _interactionHandler.hotReloadAndCapture,
    );
    registerTool(
      InteractionHandler.evaluateDartExpressionTool,
      _interactionHandler.evaluateDartExpression,
    );
    registerTool(
      InteractionHandler.getRecentLogsTool,
      _interactionHandler.getRecentLogs,
    );

    if (configuration.liveEditSupported) {
      log(
        LoggingLevel.debug,
        'Registering live edit tools',
        logger: 'FlutterInspector',
      );
      registerTool(
        LiveEditHandler.liveEditStartSessionTool,
        _liveEditHandler.liveEditStartSession,
      );
      registerTool(
        LiveEditHandler.liveEditPrepareSessionTool,
        _liveEditHandler.liveEditPrepareSession,
      );
      registerTool(
        LiveEditHandler.liveEditSetOverlayTool,
        _liveEditHandler.liveEditSetOverlay,
      );
      registerTool(
        LiveEditHandler.liveEditGetTreeTool,
        _liveEditHandler.liveEditGetTree,
      );
      registerTool(
        LiveEditHandler.liveEditSelectAtPointTool,
        _liveEditHandler.liveEditSelectAtPoint,
      );
      registerTool(
        LiveEditHandler.liveEditGetSelectionTool,
        _liveEditHandler.liveEditGetSelection,
      );
      registerTool(
        LiveEditHandler.liveEditGetCapabilitiesTool,
        _liveEditHandler.liveEditGetCapabilities,
      );
      registerTool(
        LiveEditHandler.liveEditGetSelectionCandidatesTool,
        _liveEditHandler.liveEditGetSelectionCandidates,
      );
      registerTool(
        LiveEditHandler.liveEditSetActiveSelectionTool,
        _liveEditHandler.liveEditSetActiveSelection,
      );
      registerTool(
        LiveEditHandler.liveEditGetPropertyPanelTool,
        _liveEditHandler.liveEditGetPropertyPanel,
      );
      registerTool(
        LiveEditHandler.liveEditSetEditModeTool,
        _liveEditHandler.liveEditSetEditMode,
      );
      registerTool(
        LiveEditHandler.liveEditGetPreviewStateTool,
        _liveEditHandler.liveEditGetPreviewState,
      );
      registerTool(
        LiveEditHandler.liveEditUpdateDraftTool,
        _liveEditHandler.liveEditUpdateDraft,
      );
      registerTool(
        LiveEditHandler.liveEditGetDraftTool,
        _liveEditHandler.liveEditGetDraft,
      );
      registerTool(
        LiveEditHandler.liveEditDiscardDraftTool,
        _liveEditHandler.liveEditDiscardDraft,
      );
      registerTool(
        LiveEditHandler.liveEditEndSessionTool,
        _liveEditHandler.liveEditEndSession,
      );
      registerTool(
        LiveEditHandler.liveEditListAgentBackendsTool,
        _liveEditHandler.liveEditListAgentBackends,
      );
      registerTool(
        LiveEditHandler.liveEditGetAgentBackendTool,
        _liveEditHandler.liveEditGetAgentBackend,
      );
      registerTool(
        LiveEditHandler.liveEditSetAgentBackendTool,
        _liveEditHandler.liveEditSetAgentBackend,
      );
      registerTool(
        LiveEditHandler.liveEditResolveDraftTool,
        _liveEditHandler.liveEditResolveDraft,
      );
      registerTool(
        LiveEditHandler.liveEditApplyDraftTool,
        _liveEditHandler.liveEditApplyDraft,
      );
      registerTool(
        LiveEditHandler.liveEditAcceptResolutionTool,
        _liveEditHandler.liveEditAcceptResolution,
      );
      registerTool(
        LiveEditHandler.liveEditRejectResolutionTool,
        _liveEditHandler.liveEditRejectResolution,
      );
    }

    // Register debug dump tools
    if (configuration.dumpsSupported) {
      log(
        LoggingLevel.debug,
        'Registering debug dump tools',
        logger: 'FlutterInspector',
      );
      registerTool(
        DebugToolsHandler.debugDumpLayerTreeTool,
        _debugTools.debugDumpLayerTree,
      );
      registerTool(
        DebugToolsHandler.debugDumpSemanticsTreeTool,
        _debugTools.debugDumpSemanticsTree,
      );
      registerTool(
        DebugToolsHandler.debugDumpRenderTreeTool,
        _debugTools.debugDumpRenderTree,
      );
      registerTool(
        DebugToolsHandler.debugDumpFocusTreeTool,
        _debugTools.debugDumpFocusTree,
      );
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
        'Resources disabled, registering as tools',
        logger: 'FlutterInspector',
      );
      // Register as tools (alternative behavior)
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
    addResource(
      latestAppErrorSrc,
      (final request) =>
          _resourceHandler.handleAppErrorsResource(request, count: 1),
    );
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
    addResourceTemplate(
      appErrorsResource,
      _resourceHandler.handleAppErrorsResource,
    );
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
      addResource(
        screenshotsResource,
        _resourceHandler.handleScreenshotsResource,
      );
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
    addResource(
      viewDetailsResource,
      _resourceHandler.handleViewDetailsResource,
    );
    log(
      LoggingLevel.debug,
      'Registered view details resource',
      logger: 'FlutterInspector',
    );
  }

  /// Register resource functionality as tools when resources not supported
  void _registerResourcesAsTools() {
    log(
      LoggingLevel.debug,
      'Setting up Flutter Inspector tools (resource mode disabled)',
      logger: 'FlutterInspector',
    );

    // Always register app errors tool
    registerTool(
      ResourceHandler.getAppErrorsTool,
      _resourceHandler.getAppErrors,
    );
    log(
      LoggingLevel.debug,
      'Registered app errors tool',
      logger: 'FlutterInspector',
    );

    // Register screenshots tool if images supported
    if (configuration.imagesSupported) {
      registerTool(
        ResourceHandler.getScreenshotsTool,
        _resourceHandler.getScreenshots,
      );
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
    registerTool(
      ResourceHandler.getViewDetailsTool,
      _resourceHandler.getViewDetails,
    );
    log(
      LoggingLevel.debug,
      'Registered view details tool',
      logger: 'FlutterInspector',
    );
  }

  Future<void> dispose() async {
    await _resourceHandler.dispose();
  }
}
