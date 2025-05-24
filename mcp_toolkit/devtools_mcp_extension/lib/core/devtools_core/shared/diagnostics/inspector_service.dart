// Copyright 2018 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// This code is directly based on src/io/flutter/InspectorService.java.
//
// If you add methods to this class you should also add them to
// InspectorService.java.

/// @docImport '../../screens/performance/panes/rebuild_stats/rebuild_stats_model.dart';
library;

import 'dart:convert';
import 'dart:developer';

import 'package:devtools_app_shared/service_extensions.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_mcp_extension/common_imports.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/diagnostics/diagnostics_node.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/diagnostics/generic_instance_reference.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/diagnostics/object_group_api.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/diagnostics/primitives/instance_ref.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/diagnostics/primitives/source_location.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

// TODO(jacobr): add render, semantics, and layer trees.
enum FlutterTreeType { widget }

const _inspectorLibraryUri =
    'package:flutter/src/widgets/widget_inspector.dart';

abstract class InspectorServiceBase extends DisposableController
    with AutoDisposeControllerMixin {
  InspectorServiceBase({
    required this.clientInspectorName,
    required this.serviceExtensionPrefix,
    required final String inspectorLibraryUri,
    required this.dartVmDevtoolsService,
    final ValueListenable<IsolateRef?>? evalIsolate,
  }) : clients = {},
       inspectorLibrary = EvalOnDartLibrary(
         inspectorLibraryUri,
         dartVmDevtoolsService.serviceManager.service!,
         serviceManager: dartVmDevtoolsService.serviceManager,
         isolate: evalIsolate,
       ) {
    final serviceManager = dartVmDevtoolsService.serviceManager;
    _lastMainIsolate = serviceManager.isolateManager.mainIsolate.value;
    addAutoDisposeListener(serviceManager.isolateManager.mainIsolate, () {
      final mainIsolate = serviceManager.isolateManager.mainIsolate.value;
      if (mainIsolate != _lastMainIsolate) {
        onIsolateStopped();
      }
      _lastMainIsolate = mainIsolate;
    });
  }
  final DartVmDevtoolsService dartVmDevtoolsService;
  ServiceManager get serviceManager => dartVmDevtoolsService.serviceManager;
  static int nextGroupId = 0;

  // The class name of the inspector that [InspectorServiceBase] is connecting
  // to, for use when running evals. For example, this should be set to
  // "WidgetInspectorService" when connecting to the Flutter inspector.
  final String clientInspectorName;

  // The prefix added when invoking all registered inspector service extensions.
  // For example, this should be set to "ext.flutter.inspector" when invoking
  // service extensions registered by the Flutter inspector.
  final String serviceExtensionPrefix;

  final Set<InspectorServiceClient> clients;
  final EvalOnDartLibrary inspectorLibrary;
  IsolateRef? _lastMainIsolate;

  /// Reference to the isolate running the inspector that [InspectorServiceBase]
  /// is connecting to. This isolate should always be the main isolate.
  IsolateRef? get isolateRef => inspectorLibrary.isolateRef;

  /// Called when the main isolate is stopped. Should be overridden in order to
  /// clear data that is obsolete on an isolate restart.
  void onIsolateStopped();

  /// Returns true if the given node's class is declared beneath one of the root
  /// directories of the app's package.
  bool isLocalClass(final RemoteDiagnosticsNode node);

  /// Returns a new [InspectorObjectGroupBase] with the given group name.
  InspectorObjectGroupBase createObjectGroup(final String debugName);

  bool get isDisposed => _isDisposed;
  var _isDisposed = false;

  void addClient(final InspectorServiceClient client) {
    clients.add(client);
  }

  void removeClient(final InspectorServiceClient client) {
    clients.remove(client);
  }

  /// Returns whether to use the Daemon API or the VM Service protocol directly.
  ///
  /// The VM Service protocol must be used when paused at a breakpoint as the
  /// Daemon API calls won't execute until after the current frame is done
  /// rendering.
  bool get useDaemonApi => !serviceManager.isMainIsolatePaused;

  @override
  void dispose() {
    _isDisposed = true;
    inspectorLibrary.dispose();
    super.dispose();
  }

  bool get hoverEvalModeEnabledByDefault;

  Future<bool> invokeBoolServiceMethodNoArgs(final String methodName) async =>
      useDaemonApi
          ? await invokeServiceMethodDaemonNoGroupArgs(methodName) == true
          : (await invokeServiceMethodObservatoryNoGroup(
                methodName,
              ))?.valueAsString ==
              'true';

  Future<Object?> invokeServiceMethodDaemonNoGroupArgs(
    final String methodName, [
    final List<String>? args,
  ]) {
    final params = <String, Object?>{};
    if (args != null) {
      for (int i = 0; i < args.length; ++i) {
        params['arg$i'] = args[i];
      }
    }
    return invokeServiceMethodDaemonNoGroup(methodName, args: params);
  }

  Future<InstanceRef?> invokeServiceMethodObservatoryNoGroup(
    final String methodName,
  ) => inspectorLibrary.eval(
    '$clientInspectorName.instance.$methodName()',
    isAlive: null,
  );

  Future<Object?> invokeServiceMethodDaemonNoGroup(
    final String methodName, {
    final Map<String, Object?>? args,
  }) async {
    final callMethodName = '$serviceExtensionPrefix.$methodName';
    if (!serviceManager.serviceExtensionManager.isServiceExtensionAvailable(
      callMethodName,
    )) {
      final available = await serviceManager.serviceExtensionManager
          .waitForServiceExtensionAvailable(callMethodName);
      if (!available) return {'result': null};
    }

    final r = await serviceManager.service!.callServiceExtension(
      callMethodName,
      isolateId: isolateRef!.id,
      args: args,
    );
    final json = r.json ?? {};
    if (json['errorMessage'] != null) {
      throw Exception('$methodName -- ${json['errorMessage']}');
    }
    return json['result'];
  }
}

/// Manages communication between inspector code running in the Flutter app and
/// the inspector.
class InspectorService extends InspectorServiceBase {
  InspectorService({required super.dartVmDevtoolsService})
    : super(
        clientInspectorName: 'WidgetInspectorService',
        serviceExtensionPrefix: inspectorExtensionPrefix,
        inspectorLibraryUri: _inspectorLibraryUri,
        evalIsolate:
            dartVmDevtoolsService.serviceManager.isolateManager.mainIsolate,
      ) {
    // Note: We do not need to listen to event history here because the
    // inspector uses a separate API to get the current inspector selection.
    autoDisposeStreamSubscription(
      serviceManager.service!.onExtensionEvent.listen(
        onExtensionVmServiceReceived,
      ),
    );
    autoDisposeStreamSubscription(
      serviceManager.service!.onDebugEvent.listen(onDebugVmServiceReceived),
    );
  }

  final _rootDirectories = ValueNotifier<List<String>>(<String>[]);

  @visibleForTesting
  List<String> get rootPackagePrefixes => _rootPackagePrefixes;
  late List<String> _rootPackagePrefixes;

  @visibleForTesting
  final localClasses = <String, ClassRef>{};

  @override
  void onIsolateStopped() {
    _currentSelection = null;
    _cachedSelectionGroups?.clear(true);
    _expectedSelectionChanges.clear();
  }

  @override
  ObjectGroup createObjectGroup(final String debugName) =>
      ObjectGroup(debugName, this);

  @override
  bool isLocalClass(final RemoteDiagnosticsNode node) {
    // TODO(https://github.com/flutter/devtools/issues/4393): localClasses is
    // not currently being filled.
    if (node.widgetRuntimeType == null) return false;
    // widgetRuntimeType may contain some generic type arguments which we need
    // to strip out. If widgetRuntimeType is "FooWidget<Bar>" then we are only
    // interested in the raw type "FooWidget".
    final rawType = node.widgetRuntimeType!.split('<').first;
    return localClasses.containsKey(rawType);
  }

  @override
  void dispose() {
    _cachedSelectionGroups?.clear(false);
    _cachedSelectionGroups = null;
    super.dispose();
  }

  // When DevTools is embedded, default hover eval mode to off.
  @override
  bool get hoverEvalModeEnabledByDefault => !isEmbedded();

  void onExtensionVmServiceReceived(final Event e) {
    if (e.extensionKind == FlutterEvent.frame) {
      for (final client in clients) {
        try {
          client.onFlutterFrame();
        } catch (e) {
          log('Error handling frame event', error: e);
        }
      }
    }
  }

  void onDebugVmServiceReceived(final Event event) {
    if (event.kind == EventKind.kInspect) {
      // Update the UI in IntelliJ.
      unawaited(notifySelectionChanged());
    }
  }

  /// Map from InspectorInstanceRef to list of timestamps when a selection
  /// change to that ref was triggered by this application.
  ///
  /// This is needed to handle the case where we may send multiple selection
  /// change notifications to the device before we get a notification back that
  /// the selection has actually changed. Without this fix it was rare but
  /// possible to trigger an infinite loop ping-ponging back and forth between
  /// selecting two different nodes in the inspector tree if the selection was
  /// changed more rapidly than the running flutter app could update.
  final _expectedSelectionChanges = <InspectorInstanceRef, List<int>>{};

  /// Maximum time in milliseconds that we ever expect it will take for a
  /// selection change to apply.
  ///
  /// In general this heuristic based time should not matter but we keep it
  /// anyway so that in the unlikely event that package:flutter changes and we
  /// do not received all of the selection notification events we expect, we
  /// will not be impacted if there is at least the following delay between
  /// when selection was set to exactly the same location by both the on device
  /// inspector and DevTools.
  static const _maxTimeDelaySelectionNotification = 5000;

  void _trackClientSelfTriggeredSelection(final InspectorInstanceRef ref) {
    _expectedSelectionChanges
        .putIfAbsent(ref, () => [])
        .add(DateTime.now().millisecondsSinceEpoch);
  }

  /// Returns whether the selection change was originally triggered by this
  /// application.
  ///
  /// This method is needed to avoid a race condition when there is a queue of
  /// inspector selection changes due to extremely rapidly navigating through
  /// the inspector tree such as when using the keyboard to navigate.
  bool _isClientTriggeredSelectionChange(final InspectorInstanceRef? ref) {
    // TODO(jacobr): once https://github.com/flutter/flutter/issues/39366 is
    // fixed in all versions of flutter we support, remove this logic and
    // determine the source of the inspector selection change directly from the
    // inspector selection changed event.
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    if (ref != null) {
      if (_expectedSelectionChanges.containsKey(ref)) {
        final times = _expectedSelectionChanges.remove(ref)!;
        while (times.isNotEmpty) {
          final time = times.removeAt(0);
          if (time + _maxTimeDelaySelectionNotification >= currentTime) {
            // We triggered this selection change ourselves. This logic would
            // work fine without the timestamps for the typical case but we use
            // the timestamps to be safe in case there is a bug and selection
            // change events were somehow lost.
            return true;
          }
        }
      }
    }
    return false;
  }

  void _onRootDirectoriesChanged(final List<String> directories) {
    _rootDirectories.value = directories;
    _rootPackagePrefixes = [];
  }

  Future<void> addPubRootDirectories(final List<String> rootDirectories) async {
    await _addPubRootDirectories(rootDirectories);
    _onRootDirectoriesChanged(rootDirectories);
  }

  Future<void> removePubRootDirectories(
    final List<String> rootDirectories,
  ) async {
    await _removePubRootDirectories(rootDirectories);
    _onRootDirectoriesChanged(rootDirectories);
  }

  Future<void> _addPubRootDirectories(final List<String> pubDirectories) async {
    await serviceManager.waitUntilNotPaused();
    assert(useDaemonApi);
    await invokeServiceMethodDaemonNoGroupArgs(
      WidgetInspectorServiceExtensions.addPubRootDirectories.name,
      pubDirectories,
    );
  }

  Future<void> _removePubRootDirectories(
    final List<String> pubDirectories,
  ) async {
    await serviceManager.waitUntilNotPaused();
    assert(useDaemonApi);
    await invokeServiceMethodDaemonNoGroupArgs(
      WidgetInspectorServiceExtensions.removePubRootDirectories.name,
      pubDirectories,
    );
  }

  Future<List<String>?> getPubRootDirectories() async {
    await serviceManager.waitUntilNotPaused();
    assert(useDaemonApi);
    final response = await invokeServiceMethodDaemonNoGroupArgs(
      WidgetInspectorServiceExtensions.getPubRootDirectories.name,
    );

    if (response is! List<Object?>) {
      return [];
    }

    return response.map<String>((final e) => e.toString()).toList();
  }

  /// Requests the full mapping of widget ids to source locations.
  ///
  /// See [LocationMap] which provides support to parse this JSON.
  Future<Map<String, Object?>> widgetLocationIdMap() async {
    await serviceManager.waitUntilNotPaused();
    assert(useDaemonApi);
    final response = await invokeServiceMethodDaemonNoGroupArgs(
      'widgetLocationIdMap',
    );

    if (response is! Map) {
      return {};
    }

    return response as Map<String, Object?>;
  }

  RemoteDiagnosticsNode? _currentSelection;

  InspectorObjectGroupManager get _selectionGroups =>
      _cachedSelectionGroups ??= InspectorObjectGroupManager(this, 'selection');

  InspectorObjectGroupManager? _cachedSelectionGroups;

  Future<void> notifySelectionChanged() async {
    // The previous selection changed event is obsolete.
    _selectionGroups.cancelNext();
    final group = _selectionGroups.next;
    final pendingSelection = await group.getSelection(
      _currentSelection,
      FlutterTreeType.widget,
    );
    if (!group.disposed &&
        group == _selectionGroups.next &&
        !_isClientTriggeredSelectionChange(pendingSelection?.valueRef)) {
      _currentSelection = pendingSelection;
      assert(group == _selectionGroups.next);
      _selectionGroups.promoteNext();
      for (final client in clients) {
        client.onInspectorSelectionChanged();
      }
    }
  }

  /// If the widget tree is not ready, the application should wait for the next
  /// Flutter.Frame event before attempting to display the widget tree. If the
  /// application is ready, the next Flutter.Frame event may never come as no
  /// new frames will be triggered to draw unless something changes in the UI.
  Future<bool> isWidgetTreeReady() => invokeBoolServiceMethodNoArgs(
    WidgetInspectorServiceExtensions.isWidgetTreeReady.name,
  );

  Future<bool> isWidgetCreationTracked() => invokeBoolServiceMethodNoArgs(
    WidgetInspectorServiceExtensions.isWidgetCreationTracked.name,
  );
}

/// This class has additional descenders in Google3.
abstract class InspectorObjectGroupBase
    extends InspectorObjectGroupApi<RemoteDiagnosticsNode> {
  InspectorObjectGroupBase(final String debugName)
    : groupName = '${debugName}_${InspectorServiceBase.nextGroupId}' {
    InspectorServiceBase.nextGroupId++;
  }

  /// Object group all objects in this arena are allocated with.
  final String groupName;

  InspectorServiceBase get inspectorService;
  ServiceManager get serviceManager => inspectorService.serviceManager;

  @override
  bool disposed = false;

  EvalOnDartLibrary get inspectorLibrary => inspectorService.inspectorLibrary;

  bool get useDaemonApi => inspectorService.useDaemonApi;

  /// Once an ObjectGroup has been disposed, all methods returning
  /// DiagnosticsNode objects will return a placeholder dummy node and all methods
  /// returning lists or maps will return empty lists and all other methods will
  /// return null. Generally code should never call methods on a disposed object
  /// group but sometimes due to chained futures that can be difficult to avoid
  /// and it is simpler return an empty result that will be ignored anyway than to
  /// attempt carefully cancel futures.
  @override
  Future<void> dispose() {
    // No need to dispose the group if the isolate is already gone.
    final disposeComplete =
        inspectorService.isolateRef != null
            ? invokeVoidServiceMethod(
              WidgetInspectorServiceExtensions.disposeGroup.name,
              groupName,
            )
            : Future<void>.value();
    disposed = true;
    return disposeComplete;
  }

  Future<RemoteDiagnosticsNode?> invokeServiceMethodReturningNodeInspectorRef(
    final String methodName,
    final InspectorInstanceRef? ref,
  ) async {
    if (disposed) return null;
    return useDaemonApi
        ? parseDiagnosticsNodeDaemon(
          invokeServiceMethodDaemonInspectorRef(methodName, ref),
        )
        : parseDiagnosticsNodeObservatory(
          invokeServiceMethodObservatoryInspectorRef(methodName, ref),
        );
  }

  Future<RemoteDiagnosticsNode?> invokeServiceMethodWithArgReturningNode(
    final String methodName,
    final String arg,
  ) async {
    if (disposed) return null;
    return useDaemonApi
        ? parseDiagnosticsNodeDaemon(
          invokeServiceMethodDaemonArg(methodName, arg, groupName),
        )
        : parseDiagnosticsNodeObservatory(
          invokeServiceMethodObservatoryWithGroupName1(methodName, arg),
        );
  }

  Future<Object?> invokeServiceMethodDaemonArg(
    final String methodName,
    final String? arg,
    final String objectGroup,
  ) {
    final args = {'objectGroup': objectGroup};
    if (arg != null) {
      args['arg'] = arg;
    }
    return invokeServiceMethodDaemonParams(methodName, args);
  }

  Future<Object?> invokeServiceMethodDaemonInspectorRef(
    final String methodName,
    final InspectorInstanceRef? arg,
  ) => invokeServiceMethodDaemonArg(methodName, arg?.id, groupName);

  Future<InstanceRef?> invokeServiceMethodObservatoryInspectorRef(
    final String methodName,
    final InspectorInstanceRef? arg,
  ) => inspectorLibrary.eval(
    "${inspectorService.clientInspectorName}.instance.$methodName('${arg?.id}', '$groupName')",
    isAlive: this,
  );

  Future<void> invokeVoidServiceMethod(
    final String methodName,
    final String arg1,
  ) async {
    if (disposed) return;
    if (useDaemonApi) {
      await invokeServiceMethodDaemon(methodName, arg1);
    } else {
      await invokeServiceMethodObservatory1(methodName, arg1);
    }
  }

  Future<Object?> invokeServiceMethodDaemon(
    final String methodName, [
    final String? objectGroup,
  ]) => invokeServiceMethodDaemonParams(methodName, {
    'objectGroup': objectGroup ?? groupName,
  });

  Future<InstanceRef?> invokeServiceMethodObservatory1(
    final String methodName,
    final String arg1,
  ) => inspectorLibrary.eval(
    "${inspectorService.clientInspectorName}.instance.$methodName('$arg1')",
    isAlive: this,
  );

  Future<InstanceRef?> invokeServiceMethodObservatoryWithGroupName1(
    final String methodName,
    final String arg1,
  ) => inspectorLibrary.eval(
    "${inspectorService.clientInspectorName}.instance.$methodName('$arg1', '$groupName')",
    isAlive: this,
  );

  // All calls to invokeServiceMethodDaemon bottom out to this call.
  Future<Object?> invokeServiceMethodDaemonParams(
    final String methodName,
    final Map<String, Object?> params,
  ) async {
    final callMethodName =
        '${inspectorService.serviceExtensionPrefix}.$methodName';
    if (!serviceManager.serviceExtensionManager.isServiceExtensionAvailable(
      callMethodName,
    )) {
      final available = await serviceManager.serviceExtensionManager
          .waitForServiceExtensionAvailable(callMethodName);
      if (!available) return null;
    }

    return _callServiceExtension(callMethodName, params);
  }

  Future<Object?> _callServiceExtension(
    final String extension,
    final Map<String, Object?> args,
  ) {
    if (disposed) {
      return Future.value();
    }

    return inspectorLibrary.addRequest(this, () async {
      final r = await serviceManager.service!.callServiceExtension(
        extension,
        isolateId: inspectorService.isolateRef!.id,
        args: args,
      );
      if (disposed) return null;
      final json = r.json ?? {};
      if (json['errorMessage'] != null) {
        throw Exception('$extension -- ${json['errorMessage']}');
      }
      return json['result'];
    });
  }

  Future<RemoteDiagnosticsNode?> parseDiagnosticsNodeDaemon(
    final Future<Object?> json,
  ) async {
    if (disposed) return null;
    return parseDiagnosticsNodeHelper(await json as Map<String, Object?>?);
  }

  Future<RemoteDiagnosticsNode?> parseDiagnosticsNodeObservatory(
    final FutureOr<InstanceRef?> instanceRefFuture,
  ) async => parseDiagnosticsNodeHelper(
    await instanceRefToJson(await instanceRefFuture) as Map<String, Object?>?,
  );

  RemoteDiagnosticsNode? parseDiagnosticsNodeHelper(
    final Map<String, Object?>? jsonElement,
  ) {
    if (disposed) return null;
    if (jsonElement == null) return null;
    return RemoteDiagnosticsNode(jsonElement, this, false, null);
  }

  Future<List<RemoteDiagnosticsNode>> parseDiagnosticsNodesObservatory(
    final FutureOr<InstanceRef?> instanceRefFuture,
    final RemoteDiagnosticsNode? parent,
    final bool isProperty,
  ) async {
    if (disposed || instanceRefFuture == null) return [];
    final instanceRef = await instanceRefFuture;
    if (disposed || instanceRefFuture == null) return [];
    return parseDiagnosticsNodesHelper(
      await instanceRefToJson(instanceRef) as List<Object?>?,
      parent,
      isProperty,
    );
  }

  List<RemoteDiagnosticsNode> parseDiagnosticsNodesHelper(
    final List<Object?>? jsonObject,
    final RemoteDiagnosticsNode? parent,
    final bool isProperty,
  ) {
    if (disposed || jsonObject == null) return const [];
    final nodes = <RemoteDiagnosticsNode>[];
    for (final element in jsonObject.cast<Map<String, Object?>>()) {
      nodes.add(RemoteDiagnosticsNode(element, this, isProperty, parent));
    }
    return nodes;
  }

  Future<List<RemoteDiagnosticsNode>> parseDiagnosticsNodesDaemon(
    final FutureOr<Object?> jsonFuture,
    final RemoteDiagnosticsNode? parent,
    final bool isProperty,
  ) async {
    if (disposed || jsonFuture == null) return const [];

    return parseDiagnosticsNodesHelper(
      await jsonFuture as List<Object?>?,
      parent,
      isProperty,
    );
  }

  /// Requires that the InstanceRef is really referring to a String that is valid JSON.
  Future<Object?> instanceRefToJson(final InstanceRef? instanceRef) async {
    if (disposed || instanceRef == null) return null;
    final instance = await inspectorLibrary.getInstance(instanceRef, this);

    if (disposed || instance == null) return null;

    final json = instance.valueAsString;
    if (json == null) return null;
    return jsonDecode(json);
  }

  @override
  Future<InstanceRef?> toObservatoryInstanceRef(
    final InspectorInstanceRef inspectorInstanceRef,
  ) async {
    if (inspectorInstanceRef.id == null) {
      return null;
    }
    return invokeServiceMethodObservatoryInspectorRef(
      'toObject',
      inspectorInstanceRef,
    );
  }

  Future<Instance?> getInstance(
    final FutureOr<InstanceRef?> instanceRef,
  ) async {
    if (disposed) {
      return null;
    }
    return inspectorLibrary.getInstance((await instanceRef)!, this);
  }

  /// Returns a Future with a Map of property names to Observatory
  /// InstanceRef objects. This method is shorthand for individually evaluating
  /// each of the getters specified by property names.
  ///
  /// It would be nice if the Observatory protocol provided a built in method
  /// to get InstanceRef objects for a list of properties but this is
  /// sufficient although slightly less efficient. The Observatory protocol
  /// does provide fast access to all fields as part of an Instance object
  /// but that is inadequate as for many Flutter data objects that we want
  /// to display visually we care about properties that are not necessarily
  /// fields.
  ///
  /// The future will immediately complete to null if the inspectorInstanceRef is null.
  @override
  Future<Map<String, InstanceRef>?> getDartObjectProperties(
    final InspectorInstanceRef inspectorInstanceRef,
    final List<String> propertyNames,
  ) async {
    final instanceRef = await toObservatoryInstanceRef(inspectorInstanceRef);
    if (disposed) return null;
    const objectName = 'that';
    final expression =
        '[${propertyNames.map((final propertyName) => '$objectName.$propertyName').join(',')}]';
    final scope = {objectName: instanceRef!.id!};
    final instance = await getInstance(
      inspectorLibrary.eval(expression, isAlive: this, scope: scope),
    );
    if (disposed) return null;

    // We now have an instance object that is a Dart array of all the
    // property values. Convert it back to a map from property name to
    // property values.

    final properties = <String, InstanceRef>{};
    final values = instance!.elements!.toList().cast<InstanceRef>();
    assert(values.length == propertyNames.length);
    for (int i = 0; i < propertyNames.length; ++i) {
      properties[propertyNames[i]] = values[i];
    }
    return properties;
  }

  @override
  Future<Map<String, InstanceRef>?> getEnumPropertyValues(
    final InspectorInstanceRef ref,
  ) async {
    if (disposed) return null;
    if (ref.id == null) return null;

    final instance = await getInstance(await toObservatoryInstanceRef(ref));
    if (disposed || instance == null) return null;

    final clazz = await inspectorLibrary.getClass(instance.classRef!, this);
    if (disposed || clazz == null) return null;

    final properties = <String, InstanceRef>{};
    for (final field in clazz.fields!) {
      final name = field.name!;
      if (isPrivateMember(name)) {
        // Needed to filter out _deleted_enum_sentinel synthetic property.
        // If showing enum values is useful we could special case
        // just the _deleted_enum_sentinel property name.
        continue;
      }
      if (name == 'values') {
        // Need to filter out the synthetic 'values' member.
        // TODO(jacobr): detect that this properties return type is
        // different and filter that way.
        continue;
      }
      if (field.isConst! && field.isStatic!) {
        properties[field.name!] = field.declaredType!;
      }
    }
    return properties;
  }

  Future<SourcePosition?> getPropertyLocationHelper(
    final ClassRef classRef,
    final String name,
  ) async {
    final clazz = (await inspectorLibrary.getClass(classRef, this))!;
    for (final f in clazz.functions!) {
      // TODO(pq): check for properties that match name.
      if (f.name == name) {
        final func = (await inspectorLibrary.getFunc(f, this))!;
        final location = func.location;
        throw UnimplementedError(
          'getSourcePosition not implemented. $location',
        );
      }
    }
    final superClass = clazz.superClass;
    return superClass == null
        ? null
        : getPropertyLocationHelper(superClass, name);
  }

  Future<List<RemoteDiagnosticsNode>> getListHelper(
    final InspectorInstanceRef? instanceRef,
    final String methodName,
    final RemoteDiagnosticsNode? parent,
    final bool isProperty,
  ) async {
    if (disposed) return const [];
    return useDaemonApi
        ? parseDiagnosticsNodesDaemon(
          invokeServiceMethodDaemonInspectorRef(methodName, instanceRef),
          parent,
          isProperty,
        )
        : parseDiagnosticsNodesObservatory(
          invokeServiceMethodObservatoryInspectorRef(methodName, instanceRef),
          parent,
          isProperty,
        );
  }

  /// Evaluate an expression where `object` references the `inspectorRef` or
  /// `instanceRef` passed in.
  Future<InstanceRef?> evalOnRef(
    final String expression,
    final GenericInstanceRef? ref,
  ) async {
    final inspectorRef = ref?.diagnostic?.valueRef;
    if (inspectorRef != null && inspectorRef.id != null) {
      return inspectorLibrary.eval(
        "((object) => $expression)(${inspectorService.clientInspectorName}.instance.toObject('${inspectorRef.id}'))",
        isAlive: this,
      );
    }
    final instanceRef = ref!.instanceRef!;
    return inspectorLibrary.eval(
      expression,
      isAlive: this,
      scope: <String, String>{'object': instanceRef.id!},
    );
  }

  Future<bool> isInspectable(final GenericInstanceRef ref) async {
    if (disposed) {
      return false;
    }
    try {
      final result = await evalOnRef(
        'object is Element || object is RenderObject',
        ref,
      );
      if (disposed) return false;
      return 'true' == result?.valueAsString;
    } catch (e) {
      // If the ref is invalid it is not inspectable.
      return false;
    }
  }

  @override
  Future<List<RemoteDiagnosticsNode>> getProperties(
    final InspectorInstanceRef instanceRef,
  ) => getListHelper(
    instanceRef,
    WidgetInspectorServiceExtensions.getProperties.name,
    null,
    true,
  );

  @override
  Future<List<RemoteDiagnosticsNode>> getChildren(
    final InspectorInstanceRef instanceRef,
    final bool summaryTree,
    final RemoteDiagnosticsNode? parent,
  ) => getListHelper(
    instanceRef,
    summaryTree
        ? WidgetInspectorServiceExtensions.getChildrenSummaryTree.name
        : WidgetInspectorServiceExtensions.getChildrenDetailsSubtree.name,
    parent,
    false,
  );

  @override
  bool isLocalClass(final RemoteDiagnosticsNode node) =>
      inspectorService.isLocalClass(node);
}

/// Class managing a group of inspector objects that can be freed by
/// a single call to dispose().
///
/// After dispose is called, all pending requests made with the ObjectGroup
/// will be skipped. This means that clients should not have to write any
/// special logic to handle orphaned requests.
class ObjectGroup extends InspectorObjectGroupBase {
  ObjectGroup(super.debugName, this.inspectorService);

  @override
  final InspectorService inspectorService;

  @override
  bool canSetSelectionInspector = true;

  Future<RemoteDiagnosticsNode?> getRoot(
    final FlutterTreeType type, {
    final bool isSummaryTree = false,
    final bool includeFullDetails = true,
  }) {
    // There is no excuse to call this method on a disposed group.
    assert(!disposed);
    switch (type) {
      case FlutterTreeType.widget:
        return getRootWidgetTree(
          isSummaryTree: isSummaryTree,
          includeFullDetails: includeFullDetails,
        );
    }
  }

  Future<RemoteDiagnosticsNode?> getRootWidgetTree({
    required final bool isSummaryTree,
    required final bool includeFullDetails,
  }) => parseDiagnosticsNodeDaemon(
    invokeServiceMethodDaemonParams(
      WidgetInspectorServiceExtensions.getRootWidgetTree.name,
      {
        'groupName': groupName,
        'isSummaryTree': '$isSummaryTree',
        'withPreviews': 'true',
        'fullDetails': '$includeFullDetails',
      },
    ),
  );

  // TODO these ones could be not needed.
  /* TODO(jacobr): this probably isn't needed.
  Future<List<DiagnosticsPathNode>> getParentChain(DiagnosticsNode target) async {
    if (disposed) return null;
    if (useDaemonApi) {
      return parseDiagnosticsPathDaemon(invokeServiceMethodDaemon('getParentChain', target.getValueRef()));
    }
    else {
    return parseDiagnosticsPathObservatory(invokeServiceMethodObservatory('getParentChain', target.getValueRef()));
    }
    });
  }

  Future<List<DiagnosticsPathNode>> parseDiagnosticsPathObservatory(Future<InstanceRef> instanceRefFuture) {
    return nullIfDisposed(() -> instanceRefFuture.thenComposeAsync(this::parseDiagnosticsPathObservatory));
  }

  Future<List<DiagnosticsPathNode>> parseDiagnosticsPathObservatory(InstanceRef pathRef) {
    return nullIfDisposed(() -> instanceRefToJson(pathRef).thenApplyAsync(this::parseDiagnosticsPathHelper));
  }

  Future<List<DiagnosticsPathNode>> parseDiagnosticsPathDaemon(Future<JsonElement> jsonFuture) {
    return nullIfDisposed(() -> jsonFuture.thenApplyAsync(this::parseDiagnosticsPathHelper));
  }

  List<DiagnosticsPathNode> parseDiagnosticsPathHelper(JsonElement jsonElement) {
    return nullValueIfDisposed(() -> {
    final JsonArray jsonArray = jsonElement.getAsJsonArray();
    final List<DiagnosticsPathNode> pathNodes = new List<>();
    for (JsonElement element : jsonArray) {
    pathNodes.add(new DiagnosticsPathNode(element.getAsJsonObject(), this));
    }
    return pathNodes;
    });
  }
*/

  Future<RemoteDiagnosticsNode?> getSelection(
    final RemoteDiagnosticsNode? previousSelection,
    final FlutterTreeType treeType, {
    final bool restrictToLocalProject = false,
  }) async {
    // There is no reason to allow calling this method on a disposed group.
    assert(!disposed);
    if (disposed) return null;
    RemoteDiagnosticsNode? newSelection;
    final previousSelectionRef = previousSelection?.valueRef;

    switch (treeType) {
      case FlutterTreeType.widget:
        newSelection = await invokeServiceMethodReturningNodeInspectorRef(
          restrictToLocalProject
              ? WidgetInspectorServiceExtensions.getSelectedSummaryWidget.name
              : WidgetInspectorServiceExtensions.getSelectedWidget.name,
          null,
        );
    }
    if (disposed) return null;

    return newSelection != null && newSelection.valueRef == previousSelectionRef
        ? previousSelection
        : newSelection;
  }

  @override
  Future<bool> setSelectionInspector(
    final InspectorInstanceRef selection,
    final bool uiAlreadyUpdated,
  ) {
    if (disposed) {
      return Future.value(false);
    }
    if (uiAlreadyUpdated) {
      inspectorService._trackClientSelfTriggeredSelection(selection);
    }
    return useDaemonApi
        ? handleSetSelectionDaemon(
          invokeServiceMethodDaemonInspectorRef(
            WidgetInspectorServiceExtensions.setSelectionById.name,
            selection,
          ),
          uiAlreadyUpdated,
        )
        : handleSetSelectionObservatory(
          invokeServiceMethodObservatoryInspectorRef(
            WidgetInspectorServiceExtensions.setSelectionById.name,
            selection,
          ),
          uiAlreadyUpdated,
        );
  }

  Future<bool> setSelection(final GenericInstanceRef selection) async {
    if (disposed) {
      return true;
    }
    return handleSetSelectionObservatory(
      evalOnRef(
        "${inspectorService.clientInspectorName}.instance.setSelection(object, '$groupName')",
        selection,
      ),
      false,
    );
  }

  Future<bool> handleSetSelectionObservatory(
    final Future<InstanceRef?> setSelectionResult,
    final bool uiAlreadyUpdated,
  ) async {
    // TODO(jacobr): we need to cancel if another inspect request comes in while we are trying this one.
    if (disposed) return true;
    final instanceRef = await setSelectionResult;
    if (disposed) return true;
    return handleSetSelectionHelper(
      'true' == instanceRef?.valueAsString,
      uiAlreadyUpdated,
    );
  }

  bool handleSetSelectionHelper(
    final bool selectionChanged,
    final bool uiAlreadyUpdated,
  ) {
    if (selectionChanged && !uiAlreadyUpdated && !disposed) {
      unawaited(inspectorService.notifySelectionChanged());
    }
    return selectionChanged && !disposed;
  }

  Future<bool> handleSetSelectionDaemon(
    final Future<Object?> setSelectionResult,
    final bool uiAlreadyUpdated,
  ) async {
    if (disposed) return false;
    // TODO(jacobr): we need to cancel if another inspect request comes in while we are trying this one.
    final isSelectionChanged = await setSelectionResult;
    if (disposed) return false;
    return handleSetSelectionHelper(
      isSelectionChanged! as bool,
      uiAlreadyUpdated,
    );
  }

  Future<RemoteDiagnosticsNode?> getDetailsSubtree(
    final RemoteDiagnosticsNode? node, {
    final int subtreeDepth = 2,
  }) async {
    if (node == null) return null;
    final args = {
      'objectGroup': groupName,
      'arg': node.valueRef.id,
      'subtreeDepth': subtreeDepth.toString(),
    };
    final json = await invokeServiceMethodDaemonParams(
      WidgetInspectorServiceExtensions.getDetailsSubtree.name,
      args,
    );
    return parseDiagnosticsNodeHelper(json as Map<String, Object?>?);
  }

  Future<void> invokeSetFlexProperties(
    final InspectorInstanceRef ref,
    final MainAxisAlignment? mainAxisAlignment,
    final CrossAxisAlignment? crossAxisAlignment,
  ) async {
    await invokeServiceMethodDaemonParams(
      WidgetInspectorServiceExtensions.setFlexProperties.name,
      {
        'id': ref.id,
        'mainAxisAlignment': '$mainAxisAlignment',
        'crossAxisAlignment': '$crossAxisAlignment',
      },
    );
  }

  Future<void> invokeSetFlexFactor(
    final InspectorInstanceRef ref,
    final int? flexFactor,
  ) async {
    await invokeServiceMethodDaemonParams(
      WidgetInspectorServiceExtensions.setFlexFactor.name,
      {'id': ref.id, 'flexFactor': '$flexFactor'},
    );
  }

  Future<void> invokeSetFlexFit(
    final InspectorInstanceRef ref,
    final FlexFit flexFit,
  ) async {
    await invokeServiceMethodDaemonParams(
      WidgetInspectorServiceExtensions.setFlexFit.name,
      {'id': ref.id, 'flexFit': '$flexFit'},
    );
  }

  Future<RemoteDiagnosticsNode?> getLayoutExplorerNode(
    final RemoteDiagnosticsNode? node, {
    final int subtreeDepth = 1,
  }) async {
    if (node == null) return null;
    return parseDiagnosticsNodeDaemon(
      invokeServiceMethodDaemonParams(
        WidgetInspectorServiceExtensions.getLayoutExplorerNode.name,
        {
          'groupName': groupName,
          'id': node.valueRef.id,
          'subtreeDepth': '$subtreeDepth',
        },
      ),
    );
  }

  Future<List<String>> getPubRootDirectories() async {
    final invocationResult = await invokeServiceMethodDaemonParams(
      WidgetInspectorServiceExtensions.getPubRootDirectories.name,
      {},
    );
    final directories = (invocationResult as List?)?.cast<Object>();
    return List.from(directories ?? []);
  }
}

abstract class InspectorServiceClient {
  void onInspectorSelectionChanged();

  void onFlutterFrame();

  Future<void> onForceRefresh();
}

/// Manager that simplifies preventing memory leaks when using the
/// InspectorService.
///
/// This class is designed for the use case where you want to manage
/// object references associated with the current displayed UI and object
/// references associated with the candidate next frame of UI to display. Once
/// the next frame is ready, you determine whether you want to display it and
/// discard the current frame and promote the next frame to the current
/// frame if you want to display the next frame otherwise you discard the next
/// frame.
///
/// To use this class load all data you want for the next frame by using
/// the object group specified by [next] and then if you decide to switch
/// to display that frame, call promoteNext() otherwise call clearNext().
class InspectorObjectGroupManager {
  InspectorObjectGroupManager(this.inspectorService, this.debugName);

  final InspectorService inspectorService;
  final String debugName;
  ObjectGroup? _current;
  ObjectGroup? _next;

  Completer<void>? _pendingNext;

  Future<void> get pendingUpdateDone {
    if (_pendingNext != null) {
      return _pendingNext!.future;
    }
    if (_next == null) {
      // There is no pending update.
      return Future.value();
    }

    _pendingNext = Completer();
    return _pendingNext!.future;
  }

  ObjectGroup get next {
    _next ??= inspectorService.createObjectGroup(debugName);
    return _next!;
  }

  void clear(final bool isolateStopped) {
    if (isolateStopped) {
      // The Dart VM will handle GCing the underlying memory.
      _current = null;
      _setNextNull();
    } else {
      clearCurrent();
      cancelNext();
    }
  }

  void promoteNext() {
    clearCurrent();
    _current = _next;
    _setNextNull();
  }

  void clearCurrent() {
    if (_current != null) {
      unawaited(_current!.dispose());
      _current = null;
    }
  }

  void cancelNext() {
    if (_next != null) {
      unawaited(_next!.dispose());
      _setNextNull();
    }
  }

  void _setNextNull() {
    _next = null;
    if (_pendingNext != null) {
      _pendingNext!.complete(null);
      _pendingNext = null;
    }
  }
}
