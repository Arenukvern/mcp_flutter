// Import necessary packages
import 'dart:async';
import 'dart:convert';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/service.dart' as devtools_shared;
import 'package:flutter_mcp_extension/common_imports.dart';
import 'package:vm_service/vm_service.dart';

/// {@template service_extension_bridge}
/// Bridges RPC calls from TypeScript server to Flutter's ServiceManager
/// and ServiceExtensionManager.
///
/// This simplified version focuses only on VM service initialization
/// and handling basic service functions.
/// {@endtemplate}
class ServiceExtensionBridge with ChangeNotifier {
  /// {@macro service_extension_bridge}
  ServiceExtensionBridge({required this.rpcClient}) {
    _registerRpcMethods();
  }

  /// The RPC client that receives calls from TypeScript
  final RpcClient rpcClient;

  /// The service manager instance
  final _serviceManager = ServiceManager();

  /// Stores the VM service URI when connected
  Uri? _vmServiceUri;

  /// Gets the current service manager
  ServiceManager get serviceManager => _serviceManager;

  /// Register RPC methods that can be called from TypeScript
  void _registerRpcMethods() {
    // Only register the two required methods
    rpcClient
      ..registerMethod('getConnectedState', _getConnectedState)
      ..registerMethod('takeScreenshot', _takeScreenshot);
  }

  /// Gets the current connection state
  Map<String, dynamic> _getConnectedState(final Map<String, dynamic> params) {
    final connectedState = _serviceManager.connectedState.value;

    return {
      'connected': connectedState.connected,
      'vmServiceUri': _vmServiceUri?.toString(),
    };
  }

  /// Take a screenshot of the current UI
  Future<Map<String, dynamic>> _takeScreenshot(
    final Map<String, dynamic> params,
  ) async {
    try {
      setGlobal(ServiceManager, _serviceManager);
      print('Take screenshot');
      if (!_serviceManager.connectedState.value.connected) {
        return {'success': false, 'error': 'Not connected to VM service'};
      }
      print('Take screenshot 2');
      final format = params['format'] as String? ?? 'png';
      final isolateId = _serviceManager.isolateManager.mainIsolate.value?.id;
      print('Take screenshot 3');
      if (isolateId == null) {
        return {'success': false, 'error': 'No main isolate available'};
      }
      print('Take screenshot 4');
      // Call the VM service to take a screenshot using the private Flutter API
      final result = await _serviceManager.service!.callServiceExtension(
        '_flutter.screenshot',
      );
      print('Take screenshot 5');
      try {
        // Convert screenshot data to PNG blob
        // final pngBlob = result.json!['screenshot'] as String;
        print('Screenshot PNG blob: ${result.json}');

        final serviceConnectionManager =
            globals[ServiceConnectionManager]! as ServiceConnectionManager;

        final rootWidget = (serviceConnectionManager.inspectorService!
                    .createObjectGroup('[root]')
                as ObjectGroup)
            .getRoot(FlutterTreeType.widget);
        print('Root widget: $rootWidget');

        // final bytes = base64Decode(pngBlob);
        // print('Screenshot PNG blob size: ${bytes.length} bytes');
      } catch (e) {
        print('Screenshot Error: $e');
      }

      if (result.json!.containsKey('screenshot')) {
        final screenshotData = result.json!['screenshot'] as String;
        final decodedData = base64Decode(screenshotData);

        return {'success': true, 'data': decodedData, 'format': format};
      } else {
        return {'success': false, 'error': 'Screenshot data not available'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Error taking screenshot: $e'};
    }
  }

  /// Connect to a VM service
  Future<bool> connectToVmService([final Uri? uri]) async {
    // Store the URI for later use
    _vmServiceUri =
        uri ??
        Uri(
          host: Envs.flutterRpc.host,
          port: Envs.flutterRpc.port,
          path: Envs.flutterRpc.path,
        );

    // Use the [connectedState] notifier to listen for connection updates.
    serviceManager.connectedState.addListener(() {
      if (serviceManager.connectedState.value.connected) {
        print('Manager connected to VM service');
      } else {
        print('Manager not connected to VM service');
      }
    });
    try {
      final finishedCompleter = Completer<void>();

      // Use package:devtools_shared to connect to the VM
      final vmService = await devtools_shared.connect<VmService>(
        uri: _vmServiceUri!,
        finishedCompleter: finishedCompleter,
        serviceFactory: VmService.defaultFactory,
      );

      // Open the VM service connection in the service manager
      await _serviceManager.vmServiceOpened(
        vmService,
        onClosed: finishedCompleter.future,
      );

      await _takeScreenshot({});

      notifyListeners();
      return true;
    } catch (e) {
      // Clear the URI if connection fails
      _vmServiceUri = null;
      print('Error connecting to VM service: $e');
      return false;
    }
  }

  /// Disconnect from the VM service
  Future<void> disconnectFromVmService() async {
    await _serviceManager.vmServiceClosed();
    _vmServiceUri = null;
    notifyListeners();
  }
}
