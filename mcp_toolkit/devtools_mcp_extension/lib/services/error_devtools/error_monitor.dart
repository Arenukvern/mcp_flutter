// ignore_for_file: avoid_catches_without_on_clauses

import 'package:devtools_extensions/devtools_extensions.dart'
    as devtools_extensions;
import 'package:devtools_mcp_extension/common_imports.dart';
import 'package:devtools_mcp_extension/core/devtools_core/shared/diagnostics/diagnostics_node.dart';
import 'package:devtools_mcp_extension/services/error_devtools/error_event.dart';
import 'package:vm_service/vm_service.dart';

/// A class that monitors Flutter errors in real-time using the VM Service.
class FlutterErrorMonitor {
  /// Creates a new [FlutterErrorMonitor] instance.
  FlutterErrorMonitor({final ServiceManager? serviceManager})
    : _serviceManager = serviceManager;
  final ServiceManager? _serviceManager;

  ServiceManager get serviceManager =>
      _serviceManager ?? devtools_extensions.serviceManager;

  /// Controller for broadcasting error events.
  final _errorController = StreamController<FlutterErrorEvent>.broadcast();
  final _errors = <FlutterErrorEvent>{};

  VmService? get vmService => serviceManager.service;
  String? get isolateId => serviceManager.isolateManager.mainIsolate.value?.id;

  /// Stream of error events.
  Stream<FlutterErrorEvent> get onError => _errorController.stream;
  List<FlutterErrorEvent> get errors => _errors.toList();

  /// Initialize the error monitor.
  Future<void> initialize() async {
    final vm = vmService;
    final id = isolateId;
    if (vm == null || id == null) {
      throw StateError('VM Service or Isolate ID not available');
    }

    try {
      // Enable structured errors
      await serviceManager.callServiceExtensionOnMainIsolate(
        'ext.flutter.inspector.${WidgetInspectorServiceExtensions.structuredErrors.name}',
        args: {'enabled': 'true'},
      );

      // Setup stream listeners
      await _setupErrorStreams();
    } catch (e, stack) {
      print('Error initializing FlutterErrorMonitor: $e\n$stack');
      rethrow;
    }
  }

  /// Setup the error stream listeners.
  Future<void> _setupErrorStreams() async {
    final vm = vmService;
    if (vm == null) {
      throw StateError('VM Service not available');
    }

    vm.onDebugEvent.listen(
      _handleDebugEvent,
      onError:
          (final e, final stack) =>
              print('Error in debug event handler: $e\n$stack'),
    );

    vm.onStderrEvent.listen(
      _handleExtensionEvent,
      onError:
          (final e, final stack) =>
              print('Error in stderr event handler: $e\n$stack'),
    );

    vm.onStdoutEvent.listen(
      _handleExtensionEvent,
      onError:
          (final e, final stack) =>
              print('Error in stdout event handler: $e\n$stack'),
    );

    // Setup event listeners
    vm.onExtensionEvent.listen(
      _handleExtensionEvent,
      onError:
          (final e, final stack) =>
              print('Error in extension event handler: $e\n$stack'),
    );

    vm.onDebugEvent.listen(
      _handleDebugEvent,
      onError:
          (final e, final stack) =>
              print('Error in debug event handler: $e\n$stack'),
    );
  }

  /// Handle Flutter extension events.
  Future<void> _handleExtensionEvent(final Event event) async {
    if (event.extensionKind != FlutterEvent.error) return;

    final data = event.extensionData?.data;
    if (data is! Map<String, Object?>) return;

    final errorData = RemoteDiagnosticsNode(data, null, false, null);

    final type = errorData.getStringMember('type') ?? 'Flutter Error';
    final message = errorData.getStringMember('description') ?? '';

    final errorEvent = FlutterErrorEvent(
      nodeId: errorData.getStringMember('nodeId') ?? '',
      type: type,
      message: message,
      diagnostics: await _getErrorInstance(data),
      timestamp: DateTime.now(),
      severity: _determineSeverity(errorData),
      json: errorData.json,
    );

    _errorController.add(errorEvent);
    _errors.add(errorEvent);
  }

  /// Get an Instance object from error data.
  Future<Instance?> _getErrorInstance(final Map<String, Object?> data) async {
    final vm = vmService;
    final id = isolateId;
    if (vm == null || id == null) return null;

    try {
      final instanceId = data['objectId'] as String?;
      if (instanceId == null) return null;

      final obj = await vm.getObject(id, instanceId);
      if (obj is! Instance) return null;

      // Ensure we have a valid Instance with a string value
      if (obj.valueAsString == null) return null;

      return obj;
    } catch (e, stackTrace) {
      print('Error getting error instance: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Handle debug events from the VM.
  Future<void> _handleDebugEvent(final Event event) async {
    final vm = vmService;
    final id = isolateId;
    if (vm == null || id == null) return;

    if (event.kind == EventKind.kPauseException) {
      final error = event.exception;
      if (error != null) {
        await _processVmError(error);
      }
    }
  }

  /// Process VM errors.
  Future<void> _processVmError(final InstanceRef error) async {
    final vm = vmService;
    final id = isolateId;
    if (vm == null || id == null) return;

    final errorObj = await vm.getObject(id, error.id!);

    if (errorObj is! Instance) return;

    final errorEvent = FlutterErrorEvent(
      type: 'VM Error',
      nodeId: error.id!,
      message: errorObj.valueAsString ?? '',
      diagnostics: errorObj,
      stackTrace: await _getErrorStackTrace(errorObj),
      timestamp: DateTime.now(),
      json: errorObj.json ?? {},
    );

    _errorController.add(errorEvent);
  }

  /// Get the stack trace from a VM error object.
  Future<StackTrace?> _getErrorStackTrace(final Instance error) async {
    final vm = vmService;
    final id = isolateId;
    if (vm == null || id == null) return null;

    try {
      final fields = error.fields;
      if (fields == null) return null;

      final stackTraceField = fields.firstWhere(
        (final field) => field.name == '_stackTrace',
        orElse:
            () => fields.firstWhere(
              (final field) => field.name == 'stackTrace',
              orElse: () => throw Exception('No stack trace field found'),
            ),
      );

      final value = stackTraceField.value;
      if (value is! InstanceRef) return null;

      final stackObj = await vm.getObject(id, value.id!);
      if (stackObj is! Instance) return null;

      final stackTrace = stackObj.valueAsString;
      if (stackTrace == null) return null;

      return StackTrace.fromString(stackTrace);
    } catch (e, stackTrace) {
      // If we can't get the stack trace, return null
      print('Error getting stack trace: $e');
      print('Stack trace: $stackTrace');
    }
    return null;
  }

  /// Determine the severity of an error based on its diagnostics.
  ErrorSeverity _determineSeverity(final RemoteDiagnosticsNode error) {
    final description =
        error.getStringMember('description')?.toLowerCase() ?? '';
    final level = error.getLevelMember('level', DiagnosticLevel.info);

    if (level == DiagnosticLevel.error ||
        description.contains('error') ||
        description.contains('exception')) {
      return ErrorSeverity.error;
    }

    if (level == DiagnosticLevel.warning || description.contains('warning')) {
      return ErrorSeverity.warning;
    }

    if (description.contains('fatal') ||
        description.contains('crash') ||
        description.contains('assertion')) {
      return ErrorSeverity.fatal;
    }

    return ErrorSeverity.error;
  }

  /// Dispose of the error monitor.
  Future<void> dispose() => _errorController.close();
}
