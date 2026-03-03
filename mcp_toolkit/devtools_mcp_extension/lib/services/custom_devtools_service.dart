// ignore_for_file: avoid_catches_without_on_clauses, unused_local_variable

import 'package:devtools_mcp_extension/common_imports.dart';
import 'package:devtools_mcp_extension/services/error_devtools/error_monitor.dart';
import 'package:devtools_mcp_extension/services/object_group_manager.dart';

part 'error_devtools/error_devtools_service.dart';

base class BaseDevtoolsService {
  BaseDevtoolsService({required this.devtoolsService});
  final DartVmDevtoolsService devtoolsService;

  final Map<String, ObjectGroupManager> _objectGroupManagers = {};

  ObjectGroupManager initObjectGroup({required final String debugName}) {
    final existing = _objectGroupManagers[debugName];
    if (existing != null) {
      return existing;
    }

    final vmService = devtoolsService.serviceManager.service;
    if (vmService == null) {
      throw StateError('VM service not available');
    }

    final manager = ObjectGroupManager(
      debugName: debugName,
      vmService: vmService,
      isolate: devtoolsService.serviceManager.isolateManager.mainIsolate,
    );
    _objectGroupManagers[debugName] = manager;
    return manager;
  }

  Future<void> disposeObjectGroups() async {
    for (final manager in _objectGroupManagers.values) {
      await manager.dispose();
    }
    _objectGroupManagers.clear();
  }
}

/// Service for analyzing visual trees in Flutter applications
/// using the VM Service and Widget Inspector.
final class CustomDevtoolsService extends BaseDevtoolsService {
  CustomDevtoolsService({required super.devtoolsService});

  Future<void> init() async {}

  Future<void> dispose() async {
    await disposeObjectGroups();
  }

  String get isolateIdNumber =>
      devtoolsService.serviceManager.isolateManager.mainIsolate.value?.id
          ?.split('/')
          .last ??
      '';

  Future<RPCResponse> hotReload(final Map<String, dynamic> params) async {
    final forceJs = params['force'];
    final force = forceJs is bool ? forceJs : bool.tryParse(forceJs) ?? false;
    final serviceManager = devtoolsService.serviceManager;
    if (!serviceManager.connectedState.value.connected) {
      return RPCResponse.error('Not connected to VM service');
    }

    final response = await devtoolsService.serviceManager.callService(
      'reloadSources',
      isolateId: isolateIdNumber,
      args: {'force': force},
    );

    return RPCResponse.successMap(response.json ?? {});
  }

  /// This function is used as playground for testing.
  ///
  /// Returns a list of visual errors in the Flutter application.
  /// Each error contains:
  /// - nodeId: The ID of the DiagnosticsNode with the error
  /// - description: Description of the error
  /// - errorType: Type of the error (e.g., "Layout Overflow", "Render Issue")
  Future<RPCResponse> callPlaygroundFunction(
    final Map<String, dynamic> params,
  ) => getErrors(params);

  /// Analyzes the remote diagnostics tree and returns visual / build errors.
  Future<RPCResponse> getErrors(final Map<String, dynamic> params) async {
    final serviceManager = devtoolsService.serviceManager;
    if (!serviceManager.connectedState.value.connected) {
      return RPCResponse.error('Not connected to VM service');
    }

    final vmService = serviceManager.service;
    if (vmService == null) {
      return RPCResponse.error('VM service not available');
    }

    final isolateId = serviceManager.isolateManager.mainIsolate.value?.id;
    if (isolateId == null) {
      return RPCResponse.error('No main isolate available');
    }

    final count = _parseInt(params['count'], fallback: 10);
    final isSummaryTree = _parseBool(params['isSummaryTree'], fallback: true);
    final includeProperties = _parseBool(
      params['includeProperties'],
      fallback: true,
    );
    final fullDetails = _parseBool(params['fullDetails'], fallback: true);

    final objectGroupManager = initObjectGroup(debugName: 'visual-errors');
    final group = objectGroupManager.next;

    try {
      final extensionMethod = isSummaryTree
          ? includeProperties
                ? WidgetInspectorServiceExtensions
                      .getRootWidgetSummaryTreeWithPreviews
                : WidgetInspectorServiceExtensions.getRootWidgetSummaryTree
          : WidgetInspectorServiceExtensions.getRootWidgetTree;

      final response = await vmService.callServiceExtension(
        'ext.flutter.inspector.${extensionMethod.name}',
        isolateId: isolateId,
        args: {
          // Different Flutter versions use either `groupName` or `objectGroup`.
          'groupName': group.groupName,
          'objectGroup': group.groupName,
          if (includeProperties) 'includeProperties': 'true',
          if (fullDetails) 'subtreeDepth': '-1',
        },
      );

      final result = response.json?['result'];
      if (result is! Map) {
        await objectGroupManager.cancelNext();
        return RPCResponse.error('Root widget tree not available');
      }

      final errors = _extractVisualErrors(
        rootNode: result.cast<String, Object?>(),
        groupName: group.groupName,
        limit: count,
      );

      await objectGroupManager.promoteNext();
      return RPCResponse.successMap({
        'groupName': group.groupName,
        'count': errors.length,
        'errors': errors,
      });
    } catch (e, stack) {
      await objectGroupManager.cancelNext();
      return RPCResponse.error('Error getting visual errors: $e', stack);
    }
  }

  List<Map<String, dynamic>> _extractVisualErrors({
    required final Map<String, Object?> rootNode,
    required final String groupName,
    required final int limit,
  }) {
    final maxErrors = limit <= 0 ? 1 : limit;
    final errors = <Map<String, dynamic>>[];
    final seen = <String>{};

    void visitNode(final Object? rawNode) {
      if (errors.length >= maxErrors || rawNode is! Map) {
        return;
      }

      final node = rawNode.cast<String, Object?>();
      final description = _extractDescription(node);
      final errorType = _classifyErrorType(node, description);

      if (errorType != null) {
        final nodeId = _extractNodeId(node);
        final dedupeKey = '$nodeId|$description|$errorType';
        if (seen.add(dedupeKey)) {
          errors.add({
            'nodeId': nodeId,
            'groupName': groupName,
            'description': description,
            'errorType': errorType,
          });
        }
      }

      final children = node['children'];
      if (children is List) {
        for (final child in children) {
          visitNode(child);
          if (errors.length >= maxErrors) {
            return;
          }
        }
      }

      final properties = node['properties'];
      if (properties is List) {
        for (final property in properties) {
          visitNode(property);
          if (errors.length >= maxErrors) {
            return;
          }
        }
      }
    }

    visitNode(rootNode);
    return errors;
  }

  static int _parseInt(final Object? value, {required final int fallback}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static bool _parseBool(final Object? value, {required final bool fallback}) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      if (value.toLowerCase() == 'true') {
        return true;
      }
      if (value.toLowerCase() == 'false') {
        return false;
      }
    }
    return fallback;
  }

  static String _extractDescription(final Map<String, Object?> node) {
    final candidates = [
      node['description'],
      node['renderedErrorText'],
      node['name'],
      node['type'],
      node['propertyType'],
    ];

    for (final candidate in candidates) {
      final value = _asNonEmptyString(candidate);
      if (value != null) {
        return value;
      }
    }
    return 'Unknown diagnostics error';
  }

  static String _extractNodeId(final Map<String, Object?> node) {
    final directIds = [
      node['nodeId'],
      node['valueId'],
      node['objectId'],
      node['id'],
      node['creationLocation'],
    ];
    for (final id in directIds) {
      final value = _asNonEmptyString(id);
      if (value != null) {
        return value;
      }
    }

    final valueRef = node['valueRef'];
    if (valueRef is Map) {
      final fromValueRef = _asNonEmptyString(valueRef['id']);
      if (fromValueRef != null) {
        return fromValueRef;
      }
    }

    return '';
  }

  static String? _classifyErrorType(
    final Map<String, Object?> node,
    final String description,
  ) {
    final signalText = [
      description,
      _asNonEmptyString(node['renderedErrorText']) ?? '',
      _asNonEmptyString(node['name']) ?? '',
      _asNonEmptyString(node['type']) ?? '',
      _asNonEmptyString(node['style']) ?? '',
      _asNonEmptyString(node['level']) ?? '',
    ].join(' ').toLowerCase();

    final hasErrorSignal =
        signalText.contains('error') ||
        signalText.contains('exception') ||
        signalText.contains('overflow') ||
        signalText.contains('assert') ||
        signalText.contains('failed');

    if (!hasErrorSignal) {
      return null;
    }
    if (signalText.contains('overflow')) {
      return 'Layout Overflow';
    }
    if (signalText.contains('assert')) {
      return 'Invalid State';
    }
    if (signalText.contains('render')) {
      return 'Render Issue';
    }
    if (signalText.contains('exception') || signalText.contains('thrown')) {
      return 'Usage Error';
    }
    if (signalText.contains('failed')) {
      return 'Operation Failed';
    }
    return 'General Error';
  }

  static String? _asNonEmptyString(final Object? value) {
    if (value == null) {
      return null;
    }
    final stringValue = value.toString().trim();
    if (stringValue.isEmpty || stringValue == 'null') {
      return null;
    }
    return stringValue;
  }

  /// Gets the diagnostic tree for the current Flutter widget tree.
  /// Returns a [RemoteDiagnosticsNode] representing the root of the tree.
  /// Each node contains:
  /// - description: Description of the widget/element
  /// - children: List of child nodes
  /// - properties: List of diagnostic properties
  /// - style: The style to use when displaying the node
  Future<RPCResponse> getDiagnosticTree({
    final bool isSummaryTree = true,
    final bool withPreviews = false,
    final bool fullDetails = false,
  }) async {
    final serviceManager = devtoolsService.serviceManager;
    if (!serviceManager.connectedState.value.connected) {
      return RPCResponse.error('Not connected to VM service');
    }

    final vmService = serviceManager.service;
    if (vmService == null) {
      return RPCResponse.error('VM service not available');
    }

    final isolateId = serviceManager.isolateManager.mainIsolate.value?.id;
    if (isolateId == null) {
      return RPCResponse.error('No main isolate available');
    }
    final objectGroupManager = initObjectGroup(debugName: 'diagnostic-tree');

    try {
      // Get a new object group for this operation
      final group = objectGroupManager.next;

      try {
        // Use the appropriate extension based on parameters
        final extensionMethod = isSummaryTree
            ? withPreviews
                  ? WidgetInspectorServiceExtensions
                        .getRootWidgetSummaryTreeWithPreviews
                  : WidgetInspectorServiceExtensions.getRootWidgetSummaryTree
            : WidgetInspectorServiceExtensions.getRootWidgetTree;

        final response = await vmService.callServiceExtension(
          'ext.flutter.inspector.${extensionMethod.name}',
          isolateId: isolateId,
          args: {
            'objectGroup': group.groupName,
            if (withPreviews) 'includeProperties': 'true',
            if (fullDetails) 'subtreeDepth': '-1',
          },
        );

        if (response.json == null || response.json!['result'] == null) {
          await objectGroupManager.cancelNext();
          return RPCResponse.error('Root widget tree not available');
        }

        await objectGroupManager.promoteNext();
        return RPCResponse.successMap({
          'root': response.json!['result'],
          'groupName': group.groupName,
        });
      } catch (e, stack) {
        // Cancel the group on error
        await objectGroupManager.cancelNext();
        return RPCResponse.error('Error getting diagnostic tree: $e', stack);
      }
    } catch (e, stack) {
      return RPCResponse.error('Error creating object group: $e', stack);
    }
  }

  // final layoutExplorerNode = await vmService.callServiceExtension(
  //   'ext.flutter.inspector.${WidgetInspectorServiceExtensions.
  // getLayoutExplorerNode.name}',
  //   isolateId: isolateId,
  //   args: {
  //     'objectGroup': group.groupName,
  //     'id': rootNode.valueRef.id,
  //     'subtreeDepth': '-1',
  //   },
  // );

  /// Gets detailed information about a specific node in the diagnostic tree.
  /// [nodeId] is the ID of the node to get details for
  /// [groupName] is the name of the object group that contains the node
  /// Returns detailed information about the node including:
  /// - All diagnostic properties
  /// - Widget type information
  /// - Creation location if available
  Future<RPCResponse> getNodeDetails(
    final String nodeId,
    final String groupName,
  ) async {
    final serviceManager = devtoolsService.serviceManager;
    if (!serviceManager.connectedState.value.connected) {
      return RPCResponse.error('Not connected to VM service');
    }

    final vmService = serviceManager.service;
    if (vmService == null) {
      return RPCResponse.error('VM service not available');
    }

    final isolateId = serviceManager.isolateManager.mainIsolate.value?.id;
    if (isolateId == null) {
      return RPCResponse.error('No main isolate available');
    }

    try {
      // First get the properties for the node
      final propertiesResponse = await vmService.callServiceExtension(
        'ext.flutter.inspector.'
        '${WidgetInspectorServiceExtensions.getProperties.name}',
        isolateId: isolateId,
        args: {'arg': nodeId, 'objectGroup': groupName},
      );

      if (propertiesResponse.json == null ||
          propertiesResponse.json!['result'] == null) {
        return RPCResponse.error('Node properties not available');
      }

      final properties = (propertiesResponse.json!['result'] as List<Object?>)
          .whereType<Map<Object?, Object?>>()
          .map((final prop) => prop.cast<String, Object?>())
          .toList();

      // Get the parent chain for context
      final parentChainResponse = await vmService.callServiceExtension(
        'ext.flutter.inspector.'
        '${WidgetInspectorServiceExtensions.getParentChain.name}',
        isolateId: isolateId,
        args: {'arg': nodeId, 'objectGroup': groupName},
      );

      final parentChain = parentChainResponse.json?['result'] is List<Object?>
          ? (parentChainResponse.json!['result'] as List<Object?>)
                .whereType<Map<Object?, Object?>>()
                .map((final node) => node.cast<String, Object?>())
                .toList()
          : <Map<String, Object?>>[];

      return RPCResponse.successMap({
        'properties': properties,
        'parentChain': parentChain,
        'groupName': groupName,
      });
    } catch (e, stack) {
      return RPCResponse.error('Error getting node details: $e', stack);
    }
  }

  /// Gets all children of a specific node in the diagnostic tree.
  /// [nodeId] is the ID of the node to get children for
  /// [groupName] is the name of the object group that contains the node
  /// [isSummaryTree] if true, returns a summarized version of the children
  /// Returns a list of all child nodes with their basic information
  Future<RPCResponse> getNodeChildren(
    final String nodeId,
    final String groupName, {
    final bool isSummaryTree = false,
  }) async {
    final serviceManager = devtoolsService.serviceManager;
    if (!serviceManager.connectedState.value.connected) {
      return RPCResponse.error('Not connected to VM service');
    }

    final vmService = serviceManager.service;
    if (vmService == null) {
      return RPCResponse.error('VM service not available');
    }

    final isolateId = serviceManager.isolateManager.mainIsolate.value?.id;
    if (isolateId == null) {
      return RPCResponse.error('No main isolate available');
    }

    try {
      // Use the appropriate children extension based on isSummaryTree
      final extensionMethod = isSummaryTree
          ? WidgetInspectorServiceExtensions.getChildrenSummaryTree
          : WidgetInspectorServiceExtensions.getChildrenDetailsSubtree;

      final response = await vmService.callServiceExtension(
        'ext.flutter.inspector.${extensionMethod.name}',
        isolateId: isolateId,
        args: {'arg': nodeId, 'objectGroup': groupName},
      );

      if (response.json == null || response.json!['result'] == null) {
        return RPCResponse.error('Node children not available');
      }

      final children = (response.json!['result'] as List<Object?>)
          .whereType<Map<Object?, Object?>>()
          .map((final child) => child.cast<String, Object?>())
          .toList();

      return RPCResponse.successMap({
        'children': children,
        'groupName': groupName,
      });
    } catch (e, stack) {
      return RPCResponse.error('Error getting node children: $e', stack);
    }
  }
}

class CustomInspector with WidgetInspectorService {
  CustomInspector() : super();

  @override
  void inspect(final Object? object) {
    super.inspect(object);
  }
}
